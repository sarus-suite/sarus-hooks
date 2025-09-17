setup() {
  # Create temporary directories
  TMP_HOOKS_DIR=$(mktemp -d)
  TMP_HOOK_LOG_DIR="$(mktemp -d)"

  # Print hook stdout/stderr
  HOOK_OUT="${TMP_HOOK_LOG_DIR}/out.log"
  HOOK_ERR="${TMP_HOOK_LOG_DIR}/err.log"

  touch "${HOOK_OUT}" "${HOOK_ERR}"
  tail -fn +1 "${HOOK_OUT}" &
  HOOK_OUT_PID=$!
  tail -fn +1 "${HOOK_ERR}" &
  HOOK_ERR_PID=$!

  # Prepare mock 'scontrol'
  TMP_BIN_DIR=$(mktemp -d)
  cp ${BATS_TEST_DIRNAME}/assets/scontrol-mock ${TMP_BIN_DIR}/scontrol

  # Prepare mock PMIx directories
  SLURM_JOB_UID=0
  SLURM_JOB_ID=1
  SLURM_STEP_ID=2
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
}

teardown() {
  kill "${HOOK_OUT_PID}" "${HOOK_ERR_PID}"
  rm -rf "${TMP_HOOKS_DIR}" "${TMP_HOOK_LOG_DIR}" "${TMP_BIN_DIR}" "${PMIX_DIR}"
}

@test "pmix_hook binds directory (nofail spmix_appdir)" {
  SPMIX_APPDIR_UID_DIR=/tmp/spmix_appdir_${SLURM_JOB_UID}_${SLURM_JOB_ID}.${SLURM_STEP_ID}
  rm -rf ${SPMIX_APPDIR_UID_DIR} || true
  export SLURM_JOB_UID=${SLURM_JOB_UID}

  podman --runtime=crun \
    --hooks-dir "${TMP_HOOKS_DIR}" \
    run --rm \
      --annotation run.oci.hooks.stdout="${HOOK_OUT}" \
      --annotation run.oci.hooks.stderr="${HOOK_ERR}" \
      alpine sh -c "[ -d ${PMIX_DIR} ] || ! echo \"error: no pmix dir\""
}

@test "pmix_hook binds directory (with SLURM_JOB_UID)" {
  SPMIX_APPDIR_UID_DIR=/tmp/spmix_appdir_${SLURM_JOB_UID}_${SLURM_JOB_ID}.${SLURM_STEP_ID}
  mkdir -p ${SPMIX_APPDIR_UID_DIR}
  export SLURM_JOB_UID=${SLURM_JOB_UID}

  podman --runtime=crun \
    --hooks-dir "${TMP_HOOKS_DIR}" \
    run --rm \
      --annotation run.oci.hooks.stdout="${HOOK_OUT}" \
      --annotation run.oci.hooks.stderr="${HOOK_ERR}" \
      alpine sh -c "([ -d ${SPMIX_APPDIR_UID_DIR} ] || ! echo \"error: no spmix_appdir\") && \
            ([ -d ${PMIX_DIR} ] || ! echo \"error: no pmix dir\")"

  rm -rf ${SPMIX_APPDIR_UID_DIR}
}

@test "pmix_hook binds directory (no SLURM_JOB_UID)" {
  SPMIX_APPDIR_NO_UID_DIR=/tmp/spmix_appdir_${SLURM_JOB_ID}.${SLURM_STEP_ID}
  mkdir -p ${SPMIX_APPDIR_NO_UID_DIR}
  unset SLURM_JOB_UID

  podman --runtime=crun \
    --hooks-dir "${TMP_HOOKS_DIR}" \
    run --rm \
      --annotation run.oci.hooks.stdout="${HOOK_OUT}" \
      --annotation run.oci.hooks.stderr="${HOOK_ERR}" \
      alpine sh -c "([ -d ${SPMIX_APPDIR_NO_UID_DIR} ] || ! echo \"error: no spmix_appdir\") && \
            ([ -d ${PMIX_DIR} ] || ! echo \"error: no pmix dir\")"

  rm -rf ${SPMIX_APPDIR_NO_UID_DIR}
}
