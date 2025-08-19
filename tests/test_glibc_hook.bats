setup() {
  TMP_HOOKS_DIR="$(mktemp -d)"
  TMP_HOOK_LOG_DIR="$(mktemp -d)"
  OLD_IMAGE="ubuntu:16.04"
  RUNTIME="crun"

  HOOK_OUT="${TMP_HOOK_LOG_DIR}/glibc-hook.out"
  HOOK_ERR="${TMP_HOOK_LOG_DIR}/glibc-hook.err"

  cat > "${TMP_HOOKS_DIR}/glibc-hook.json" <<EOF
{
  "version": "1.0.0",
  "hook": {
    "path": "/scratch/local/podman-hooks/bin/glibc_hook",
    "env": [
      "LDD_PATH=/usr/bin/ldd",
      "LDCONFIG_PATH=/sbin/ldconfig",
      "READELF_PATH=/usr/bin/readelf",
      "GLIBC_LIBS=/lib64/libSegFault.so:/lib64/librt-2.31.so:/lib64/libnss_dns-2.31.so:/lib64/libanl-2.31.so:/lib64/libresolv-2.31.so:/usr/lib64/libnsl.so.2.0.0:/lib64/libBrokenLocale-2.31.so:/lib64/ld-2.31.so:/lib64/libnss_hesiod-2.31.so:/lib64/libutil-2.31.so:/lib64/libnss_files-2.31.so:/lib64/libnss_compat-2.31.so:/lib64/libnss_db-2.31.so:/lib64/libm-2.31.so:/usr/lib64/libcrypt.so.1.1.0:/lib64/libc-2.31.so:/lib64/libpthread-2.31.so:/lib64/libdl-2.31.so:/lib64/libthread_db-1.0.so"
    ]
  },
  "when": {
    "annotations": {
      "^com.hooks.glibc.enabled$": "^true$"
    }
  },
  "stages": ["createContainer"]
}
EOF

  # search for the following in hook output
  expected_entries=(
    "libSegFault.so"
    "librt-2.31.so"
    "libnss_dns-2.31.so"
    "libanl-2.31.so"
    "libresolv-2.31.so"
    "libnsl.so.2.0.0"
    "libBrokenLocale-2.31.so"
    "ld-2.31.so"
    "libnss_hesiod-2.31.so"
    "libutil-2.31.so"
    "libnss_files-2.31.so"
    "libnss_compat-2.31.so"
    "libnss_db-2.31.so"
    "libm-2.31.so"
    "libcrypt.so.1.1.0"
    "libc-2.31.so"
    "libpthread-2.31.so"
    "libdl-2.31.so"
    "libthread_db-1.0.so"
  )
}

teardown() {
  rm -rf "${TMP_HOOKS_DIR}" "${TMP_HOOK_LOG_DIR}"
}

helper_run_hooked_podman(){
  # clean out and err dirs
  > "${HOOK_OUT}"
  > "${HOOK_ERR}"

  podman --runtime="${RUNTIME}" \
    --hooks-dir "${TMP_HOOKS_DIR}" \
    run --rm \
    --annotation com.hooks.glibc.enabled=true \
    --annotation com.hooks.logging.level=0 \
    --annotation run.oci.hooks.stdout="${HOOK_OUT}" \
    --annotation run.oci.hooks.stderr="${HOOK_ERR}" \
    "$OLD_IMAGE" bash -lc "$1"
}

@test "validate old Ubuntu container" {
  run podman run --rm "$OLD_IMAGE" bash -lc 'ldd --version | head -n1'
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ 2\.31 ]]
}

@test "validate hook runs" {
  run helper_run_hooked_podman 'ldd --version'
  [ "$status" -eq 0 ]

  # hook output exist and is non-empty means hook runs
  [ -f "$HOOK_OUT" ]
  [ -s "$HOOK_OUT" ]
}

@test "validate hook injects as expected" {
  run helper_run_hooked_podman 'ldd --version'
  [ "$status" -eq 0 ]

  [ -f "$HOOK_OUT" ]
  [ -s "$HOOK_OUT" ]

  hooklog="$(cat "$HOOK_OUT")"
  count_injections=0
  missing=()
  for t in "${expected_entries[@]}"; do
    if [[ "$hooklog" == *"$t"* ]]; then
      count_injections=$((count_injections+1))
    else
      missing+=("$t")
    fi
  done

  [[ $count_injections -ge 10 ]] || {
    echo "Missing too many references in hook log ($count_injections/${#expected_entries[@]})"
    printf 'Missing tokens: %s\n' "${missing[@]}"
    echo "Log path: $HOOK_OUT"
    false
  }
}


