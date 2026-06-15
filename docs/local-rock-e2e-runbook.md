# Runbook: Test locally-built Litmus rocks end-to-end (Multipass + MicroK8s + Juju)

Validates rocks you built **from this repo** (not the published Docker Hub images) by
running a real chaos experiment through the full Litmus control + execution plane.

Use this when bumping Go / dependencies / versions: a rock that *builds* and even
*starts* can still fail at runtime — only a full e2e proves it.

- **Tested with:** MicroK8s 1.35/stable, Juju 3.6 (3/stable), rockcraft 1.19, on an
  8 cpu / 16 GB / 60 GB Multipass VM.
- **Charms:** deployed from CharmHub `dev/edge` (auth/backend/chaoscenter/infrastructure).

---

## 1. VM + toolchain

```bash
multipass launch 24.04 --name litmus-e2e --cpus 8 --memory 16G --disk 60G

multipass exec litmus-e2e -- sudo snap install microk8s --classic --channel=1.35/stable
multipass exec litmus-e2e -- sudo snap install juju --channel=3/stable
multipass exec litmus-e2e -- sudo snap install rockcraft --classic     # bundles skopeo
multipass exec litmus-e2e -- sudo snap install kubectl --classic
multipass exec litmus-e2e -- sudo usermod -aG microk8s ubuntu          # classic snap = group "microk8s" (NOT snap_microk8s)
# rockcraft needs LXD; the lxd snap is usually preinstalled — `sudo lxd init --auto` if not

multipass exec litmus-e2e -- sudo microk8s status --wait-ready
multipass exec litmus-e2e -- sudo microk8s enable dns hostpath-storage rbac metallb:10.64.140.43-10.64.140.49
```

Bootstrap Juju (run inside the VM; a fresh `multipass exec` session already has the
`microk8s`/`lxd` groups):

```bash
mkdir -p ~/.kube && sudo microk8s config > ~/.kube/config
sudo microk8s config | juju add-k8s microk8s-cloud --client
juju bootstrap microk8s-cloud litmus-controller
```

---

## 2. Build the rocks

Copy the repo into the VM (Multipass snap can't read `/tmp` or arbitrary host paths —
stage from `$HOME`):

```bash
tar --exclude=.git -czf ~/litmus-rocks-src.tgz -C /path/to/litmus-rocks .
multipass transfer ~/litmus-rocks-src.tgz litmus-e2e:/home/ubuntu/litmus-rocks-src.tgz
multipass exec litmus-e2e -- bash -c 'mkdir -p ~/litmus-rocks && tar -xzf ~/litmus-rocks-src.tgz -C ~/litmus-rocks'
```

Build each rock (~3–8 min each):

```bash
# IN the VM. GOTCHA: do NOT wrap in `sg lxd -c "..."` — it breaks rockcraft project
# detection ("project file not found in /"). Just cd + pack directly.
cd ~/litmus-rocks/litmuschaos-<name>/3.29.0 && rockcraft pack
```

> **Prereq fix — `/VERSION`:** the litmus charms read `/VERSION` from the rock to detect
> the workload version (`get_litmus_version()`); the backend server *fatals* without it.
> Each rockcraft.yaml must write it. In the relevant part's `override-build`:
> ```yaml
> echo "$(craftctl get version)" > ${CRAFT_PART_INSTALL}/VERSION
> ```
> and add `VERSION` to `stage:`. Needed for **server, authserver, frontend**.

---

## 3. Local registry + docker.io mirror

Exec-plane pods are `imagePullPolicy: Always`, so a plain containerd import is ignored —
serve our images from a local registry and mirror `docker.io` to it (other images fall
through to real Docker Hub).

```bash
sudo microk8s enable registry          # localhost:32000
sudo microk8s kubectl -n container-registry rollout status deploy/registry

# push every rock under the exact repo path the charm requests
TAG=3.29-24.04_edge
rockcraft.skopeo --insecure-policy copy \
  oci-archive:litmuschaos-<name>_3.29.0_amd64.rock \
  docker://localhost:32000/ubuntu/litmuschaos-<name>:$TAG --dest-tls-verify=false

# mirror docker.io -> localhost:32000 (tried first, falls back to real docker.io)
sudo mkdir -p /var/snap/microk8s/current/args/certs.d/docker.io
sudo tee /var/snap/microk8s/current/args/certs.d/docker.io/hosts.toml >/dev/null <<'EOF'
server = "https://registry-1.docker.io"

[host."http://localhost:32000"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
EOF
sudo snap restart microk8s.daemon-containerd
```

Verify (kubelet honors the mirror automatically; `ctr` needs `--hosts-dir`):

```bash
sudo microk8s ctr image pull --hosts-dir /var/snap/microk8s/current/args/certs.d \
  docker.io/ubuntu/litmuschaos-operator:$TAG     # should pull from localhost:32000
```

Image → rock → consumer mapping:

| Rock | How it's used | Inject as |
|---|---|---|
| server | backend charm resource `litmus-backend-image` | `ubuntu/litmuschaos-server:$TAG` |
| authserver | auth charm resource `litmus-auth-image` | `ubuntu/litmuschaos-authserver:$TAG` |
| frontend | chaoscenter charm resource `litmus-chaoscenter-image` | `ubuntu/litmuschaos-frontend:$TAG` |
| operator/exporter/event-tracker/subscriber/runner | **backend env vars** (`litmus_backend.py`), tag derived from server's `/VERSION` | `ubuntu/litmuschaos-<name>:$TAG` (via mirror) |

> The backend derives the exec-plane tag (`{major}.{minor}-24.04_edge`) from the **server
> rock's `/VERSION`**. So the server rock's version controls all five exec-plane images.

---

## 4. Deploy the control plane

```bash
juju add-model litmus microk8s-cloud
juju deploy litmus-auth-k8s auth               --channel dev/edge --trust
juju deploy litmus-backend-k8s backend         --channel dev/edge --trust
juju deploy litmus-chaoscenter-k8s chaoscenter --channel dev/edge --trust
juju deploy mongodb-k8s mongodb                --channel 6/stable --trust
juju deploy traefik-k8s traefik                --channel latest/stable --trust

juju integrate auth:database mongodb
juju integrate backend:database mongodb
juju integrate auth:litmus-auth backend:litmus-auth
juju integrate auth:http-api chaoscenter:auth-http-api
juju integrate backend:http-api chaoscenter:backend-http-api
juju integrate chaoscenter:ingress traefik:traefik-route

# user creds (config needs the full secret: URI)
SECRET=$(juju add-secret cc-users "admin-password=Litmus123!" "charm-password=Charm123!")
juju grant-secret cc-users chaoscenter
juju config chaoscenter user_secrets="$SECRET"
```

**Point the control plane at your local rocks** (overrides the published images):

```bash
juju attach-resource backend     litmus-backend-image=ubuntu/litmuschaos-server:$TAG
juju attach-resource auth         litmus-auth-image=ubuntu/litmuschaos-authserver:$TAG
juju attach-resource chaoscenter  litmus-chaoscenter-image=ubuntu/litmuschaos-frontend:$TAG
```

Wait for active; confirm `juju status` shows **Version 3.29.0** and chaoscenter
`Ready at http://10.64.140.43:8185`.

> If you change a rock and re-push under the same tag, kubelet won't re-pull
> (`IfNotPresent`). Force it: `sudo microk8s ctr image rm docker.io/ubuntu/litmuschaos-<name>:$TAG`
> then `kubectl delete pod` the affected unit.

---

## 5. Deploy the execution plane

```bash
juju add-model target-app microk8s-cloud
juju deploy self-signed-certificates -m litmus-controller:target-app --trust       # chaos target
juju deploy litmus-infrastructure-k8s infrastructure -m litmus-controller:target-app --channel dev/edge --trust

juju switch litmus-controller:target-app
juju offer infrastructure:litmus-infrastructure
juju integrate -m litmus-controller:litmus chaoscenter:litmus-infrastructure admin/target-app.infrastructure
```

Verify the exec-plane runs **your** images:

```bash
sudo microk8s kubectl get pods -n target-app \
  -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.spec.containers[0].image}{"\n"}{end}'
# expect operator/exporter/event-tracker/subscriber on ubuntu/litmuschaos-*:3.29-24.04_edge
```

> Exec-plane Deployments are **not** garbage-collected by removing the relation and don't
> auto-refresh on a backend image change. To re-provision cleanly:
> `juju destroy-model litmus-controller:target-app --destroy-storage --force`, then redeploy.

---

## 6. Run a chaos experiment + verify

Save + run a `pod-delete` experiment via the ChaosCenter GraphQL API (see
`save_experiment.py` / `execution-plane-e2e-scenario.md` Phase 5 for the manifest).
Use a **fresh experiment id** each run — MongoDB persists them across model rebuilds.

```bash
CC=10.64.140.43
TOKEN=$(curl -sS -X POST -H 'Content-Type: application/json' \
  -d '{"username":"charm","password":"Charm123!"}' http://$CC:8185/auth/login \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["accessToken"])')
# ... saveChaosExperiment + runChaosExperiment (see e2e scenario doc) ...
```

Pass criteria:

```bash
sudo microk8s kubectl get workflow -n target-app <wf> -o jsonpath='{.status.phase}'        # Succeeded
sudo microk8s kubectl get chaosresult -n target-app \
  -o jsonpath='{.items[*].status.experimentStatus.verdict}'                                # Pass
# runner image (operator env = ground truth; runner pod is ephemeral):
sudo microk8s kubectl get deploy chaos-operator-ce -n target-app \
  -o jsonpath='{..env[?(@.name=="CHAOS_RUNNER_IMAGE")].value}'                             # ubuntu/litmuschaos-runner:3.29-24.04_edge
sudo microk8s kubectl get pod -n target-app self-signed-certificates-0                     # recovered/Running
```

---

## 7. Teardown

```bash
juju destroy-model litmus-controller:target-app --destroy-storage --no-prompt --force
juju destroy-model litmus-controller:litmus     --destroy-storage --no-prompt --force
multipass delete --purge litmus-e2e
```

---

## Gotchas (summary)

- Classic MicroK8s snap → group `microk8s` (not `snap_microk8s`).
- Multipass snap can't read `/tmp`/host paths → `multipass transfer` from `$HOME`.
- `rockcraft pack` directly (`cd dir && rockcraft pack`); **not** via `sg lxd -c "..."`.
- Rocks must ship `/VERSION` or the backend fatals (`required key VERSION missing value`).
- Exec-plane pods are `imagePullPolicy: Always` → need the registry **mirror**, not an import.
- Same-tag re-push → clear the containerd image + delete the pod to force re-pull.
- Exec-plane Deployments persist across relation removal → destroy the target-app model to re-provision.
- ChaosCenter UI may show `Error` on a passing run (subscriber Argo-v2 pod-name bug) — trust the `ChaosResult` verdict and Argo phase.
- The Go bump (1.24→1.26) builds **and** runs cleanly; it was not the failure source.
