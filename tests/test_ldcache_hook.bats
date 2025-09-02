setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
  
  RUNTIME="${RUNTIME:-crun}"
  TEST_IMAGE="${TEST_IMAGE:-ubuntu:20.04}"

  TMP_HOOKS_DIR="$(mktemp -d)"
  TMP_HOOK_LOG_DIR="$(mktemp -d)"
  HOOK_OUT="${TMP_HOOK_LOG_DIR}/out.log"
  HOOK_ERR="${TMP_HOOK_LOG_DIR}/err.log"

  echo "HOOK LOG DIR: $TMP_HOOK_LOG_DIR"

  cat > "${TMP_HOOKS_DIR}/02-ldcache.json" <<'EOF'
{
  "version": "1.0.0",
  "hook": {
    "path": "/opt/sarus/bin/ldcache_hook",
    "env": ["LDCONFIG_PATH=/sbin/ldconfig"]
  },
  "when": { "always": true },
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
  echo " OUTPUT $output"
 
  assert_success
 
  # run test -e "$HOOK_OUT"
  run bash -c '[ -e "$0" ] && cat "$0"' "$HOOK_OUT"
  assert_success
#  echo " OUTPUT $output"
#  assert_output --partial "yeah"
}


@test "ldcache summary values are sane" {
  run helper_run_hooked_podman 'true'
  assert_success

  # Collect the hook summary
  local summary
  summary="$(grep -m1 'summary rootfs=' "$HOOK_OUT" || true)"

  # Extract data fields
  local size mtime
  size=$(sed -E 's/.*cache_size=([0-9]+).*/\1/' <<<"$summary")
  mtime=$(sed -E 's/.*cache_mtime=([0-9]+).*/\1/' <<<"$summary")

  # sanity check in case of empty values
  assert [ -n "$size" ]
  assert [ -n "$mtime" ]

  # Check time is a number > 0 and so is size
  assert_regex "$size" '^[0-9]+$'
  assert_regex "$mtime" '^[0-9]+$'

  # A greater-than check needs to pass by bash and then asserted
  run bash -c "[[ $mtime -gt 0 ]]"
  assert_success
}

#@test "/etc/ld.so.cache exists after hook" {
#  # TODO: can we validate that ld.so.cache was recently updated? idea: inject a lib and then see it in hook log
#  run helper_run_hooked_podman 'true'
#  [ "$status" -eq 0 ]
#}
