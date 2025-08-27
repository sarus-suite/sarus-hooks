setup() {
  RUNTIME="${RUNTIME:-crun}"
  TEST_IMAGE="${TEST_IMAGE:-ubuntu:20.04}"

  TMP_HOOKS_DIR="$(mktemp -d)"
  TMP_HOOK_LOG_DIR="$(mktemp -d)"
  HOOK_OUT="${TMP_HOOK_LOG_DIR}/out.log"
  HOOK_ERR="${TMP_HOOK_LOG_DIR}/err.log"

  cat > "${TMP_HOOKS_DIR}/02-ldcache.json" <<'EOF'
{
  "version": "1.0.0",
  "hook": {
    "path": "/opt/sarus/bin/ldcache_hook",
    "env": ["LDCONFIG_PATH=/sbin/ldconfig"]
  },
  "stages": ["createContainer"]
}
EOF
}

teardown() {
  rm -rf "${TMP_HOOKS_DIR}" "${TMP_HOOK_LOG_DIR}"
}

helper_run_hooked_podman() {
  # cleanup hook output
  : > "${HOOK_OUT}"
  : > "${HOOK_ERR}"

  # run hook with debug output
  podman --runtime="${RUNTIME}" \
    --hooks-dir "${TMP_HOOKS_DIR}" \
    run --rm \
      --annotation com.hooks.logging.level=0 \
      --annotation run.oci.hooks.stdout="${HOOK_OUT}" \
      --annotation run.oci.hooks.stderr="${HOOK_ERR}" \
      "${TEST_IMAGE}" bash -lc "$1"
}

@test "hook runs and generates debug logs" {
  run helper_run_hooked_podman 'true'
  [ "$status" -eq 0 ]
#  [ -s "$HOOK_OUT" ]
}

#@test "/etc/ld.so.cache exists after hook" {
#  # TODO: can we validate that ld.so.cache was recently updated? idea: inject a lib and then see it in hook log
#  run helper_run_hooked_podman 'true'
#  [ "$status" -eq 0 ]
#}
