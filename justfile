[private]
@default:
  just --list
  echo ""
  echo "For help with a specific recipe, run: just --usage <recipe>"

# Pack a rock of a specific component and version
pack component version:
  cd "{{component}}"; just pack "{{version}}"

# `rockcraft clean` for a specific component and version
clean component version:
  cd "{{component}}"; just clean "{{version}}"

# Run a rock and open a shell into it with `docker`
run component version:
  cd "{{component}}"; just run "{{version}}"

# Test a rock with `rockcraft test`
test component version:
  cd "{{component}}"; just test "{{version}}"
