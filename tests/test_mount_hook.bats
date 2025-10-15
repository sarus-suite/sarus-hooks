setup() {
  # Create temporary directories
  TMP_HOOKS_DIR=$(mktemp -d)

  # Create test file in user home not clean but mount hook of tmp is not allowed
  echo "test-file" > "${HOME}/sarus-hook-test-file.txt"

  # Create hook config
  cat > "${TMP_HOOKS_DIR}/mount-hook.json" <<EOF
{
  "version": "1.0.0",
  "hook": {
    "path": "/scratch/local/podman-hooks/bin/mount_hook",
    "args": ["mount_hook",
      "--mount=type=bind,src=${HOME},dst=/mnt/hostbind,readonly"
    ],
    "env": [
      "LDCONFIG_PATH=/sbin/ldconfig"
    ]
  },
  "when": {
    "always": true
  },
  "stages": ["createContainer"]
}
EOF
}

teardown() {
  rm -rf "${TMP_HOOKS_DIR}"
}

@test "mount_hook binds directory" {
  run podman --hooks-dir "${TMP_HOOKS_DIR}" run --rm alpine sh -c "cat /mnt/hostbind/sarus-hook-test-file.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "test-file" ]
}

