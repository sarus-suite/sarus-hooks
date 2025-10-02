setup() {
  export CDI_SPEC_DIRS="$BATS_TEST_TMPDIR/cdi"
  mkdir -p "$CDI_SPEC_DIRS"
  cp "${BATS_TEST_DIRNAME}/../templates/cdi/cdi-mps.json" "$CDI_SPEC_DIRS/cdi-mps.json"

  mkdir -p /tmp/nvidia-mps

  command -v podman >/dev/null || skip "podman not found"
}


teardown() {
  rm -f /tmp/nvidia-mps 2>/dev/null || true
}

@test "MPS CDI spec applies env+mount" {
  run podman run --rm \
    --cdi-spec-dir=$CDI_SPEC_DIRS \
    --device cscs.ch/service=mps \
    alpine:3.20 \
    sh -euxc '
      # Env var from CDI spec should be present
      [ "${CUDA_MPS_PIPE_DIRECTORY:-}" = "/tmp/nvidia-mps" ]
      echo OK_ENV

      # Mount should exist and be writable; write a file into it
      grep -q " /tmp/nvidia-mps " /proc/mounts
      [ -w /tmp/nvidia-mps ]
      echo "hello" > /tmp/nvidia-mps/hello-from-container
      echo OK_MOUNT_RW
    '

  # Valdiate env and mount pass
  [[ "$output" == *OK_ENV* ]]
  [[ "$output" == *OK_MOUNT_RW* ]]

  # File writen by container should appear on host too (bc of rw bind)
  [ -f /tmp/nvidia-mps/hello-from-container ]
}
