setup() {
  # Create temporary directories
  TMP_HOOKS_DIR=$(mktemp -d)
  TMP_HOOK_LOG_DIR="$(mktemp -d)"
  HOOK_OUT="${TMP_HOOK_LOG_DIR}/out.log"
  HOOK_ERR="${TMP_HOOK_LOG_DIR}/err.log"

  # Prepare mock 'scontrol'
  TMP_BIN_DIR=$(mktemp -d)
  cp ${BATS_TEST_DIRNAME}/test_helper/scontrol-mock ${TMP_BIN_DIR}/scontrol

  # Prepare mock PMIx directories.
  SLURM_JOB_UID=0
  SLURM_JOB_ID=1
  SLURM_STEP_ID=2
  SPMIX_APPDIR_UID_DIR=/tmp/spmix_appdir_${SLURM_JOB_UID}_${SLURM_JOB_ID}.${SLURM_STEP_ID}
  SPMIX_APPDIR_NO_UID_DIR=/tmp/spmix_appdir_${SLURM_JOB_ID}.${SLURM_STEP_ID}
  PMIX_DIR=/tmp/spool/slurmd/pmix.${SLURM_JOB_ID}.${SLURM_STEP_ID}
  mkdir -p ${PMIX_DIR}

  # Export test environment variables
  export PATH=${TMP_BIN_DIR}:${PATH}
  export SLURM_MPI_TYPE=pmix 
  export PMIX_WHATEVER=yes 
  export SLURM_JOB_ID=${SLURM_JOB_ID}
  export SLURM_STEP_ID=${SLURM_STEP_ID}

  # Create hook config
  cat > "${TMP_HOOKS_DIR}/pmix-hook.json" <<EOF
{
  "version": "1.0.0",
  "hook": {
    "path": "/scratch/local/podman-hooks/bin/pmix_hook"
  },
  "when": { "always": true },
  "stages": ["createContainer"]
}
EOF

  # For local tests,
  #"path": "/home/gwangmu/Projects/sarus/sarus-hooks/build/src/pmix/pmix_hook"
}

teardown() {
  rm -rf "${TMP_HOOKS_DIR}" "${TMP_HOOK_LOG_DIR}" "${TMP_BIN_DIR}" "${PMIX_DIR}"
}

@test "pmix_hook binds directory (with SLURM_JOB_UID)" {
  mkdir -p ${SPMIX_APPDIR_UID_DIR}
  export SLURM_JOB_UID=${SLURM_JOB_UID}

  podman --hooks-dir "${TMP_HOOKS_DIR}" run --rm \
    alpine sh -c "[ -d ${SPMIX_APPDIR_DIR} ] && [ -d ${PMIX_DIR} ]"

  # For hook logs
  # podman --runtime=crun \
  #   --hooks-dir "${TMP_HOOKS_DIR}" \
  #   run --rm \
  #     --annotation com.hooks.logging.level=0 \
  #     --annotation run.oci.hooks.stdout="${HOOK_OUT}" \
  #     --annotation run.oci.hooks.stderr="${HOOK_ERR}" \
  #     alpine sh -c "[ -d ${SPMIX_APPDIR_DIR} ] && [ -d ${PMIX_DIR} ]" || true
  # cat ${HOOK_OUT}
  # cat ${HOOK_ERR}

  rm -rf ${SPMIX_APPDIR_UID_DIR}
}

@test "pmix_hook binds directory (no SLURM_JOB_UID)" {
  mkdir -p ${SPMIX_APPDIR_NO_UID_DIR}
  unset SLURM_JOB_UID

  podman --hooks-dir "${TMP_HOOKS_DIR}" run --rm \
    alpine sh -c "[ -d ${SPMIX_APPDIR_DIR} ] && [ -d ${PMIX_DIR} ]"

  # For hook logs
  # podman --runtime=crun \
  #   --hooks-dir "${TMP_HOOKS_DIR}" \
  #   run --rm \
  #     --annotation com.hooks.logging.level=0 \
  #     --annotation run.oci.hooks.stdout="${HOOK_OUT}" \
  #     --annotation run.oci.hooks.stderr="${HOOK_ERR}" \
  #     alpine sh -c "[ -d ${SPMIX_APPDIR_DIR} ] && [ -d ${PMIX_DIR} ]" || true
  # cat ${HOOK_OUT}
  # cat ${HOOK_ERR}

  rm -rf ${SPMIX_APPDIR_NO_UID_DIR}
}
