setup() {
  # Create temporary directories
  TMP_HOOKS_DIR=$(mktemp -d)

  # Create test file in bind mount source
  echo "test-file" > "${HOME}/sarus-hook-test-file.txt"

  # Create hook config
  cat > "${TMP_HOOKS_DIR}/mount-hook.json" <<EOF
{
  "version": "1.0.0",
  "hook": {
    "path": "/local/scratch/podman-hooks/bin/mount_hook",
    "args": ["mount_hook",
      "--mount=type=bind,src=${HOME},dst=/mnt/hostbind,readonly",
      "--device=/dev/null:/dev/specialnull:rw",
      "--device=/dev/null:/dev/null:r"
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

@test "mount_hook binds directory and devices correctly" {
  run podman --hooks-dir "${TMP_HOOKS_DIR}" run --rm alpine sh -c "cat /mnt/hostbind/sarus-hook-test-file.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "test-file" ]
}

@test "remapped /dev/null behaves like /dev/null" {
  run podman --hooks-dir "${TMP_HOOKS_DIR}" run --rm alpine sh -c 'echo test >/dev/specialnull && echo OK'
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

@test "remapped /dev/zero behaves like /dev/zero" {
  run podman --hooks-dir "${TMP_HOOKS_DIR}" run --rm alpine sh -c 'head -c 4 /dev/newzero | hexdump -C'
  [[ "$output" =~ "00 00 00 00" ]]
}

