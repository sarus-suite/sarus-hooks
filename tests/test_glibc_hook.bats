setup() {
  TMP_HOOKS_DIR="$(mktemp -d)"

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
}

teardown() {
  rm -rf "${TMP_HOOKS_DIR}"
}


