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
  if ! which scontrol >/dev/null 2>&1; then
    echo "$0: info: scontrol not found. installing scontrol-mock..."

    TMP_BIN_DIR=$(mktemp -d)
    cat <<EOS >${TMP_BIN_DIR}/scontrol
#!/bin/bash

if [[ "\$1" == "show" ]] && [[ "\$2" == "config" ]]; then
  cat <<EOF
Configuration data as of 2025-09-16T10:59:04
SlurmdSpoolDir          = /tmp/spool/slurmd
TmpFS                   = /tmp
Slurmctld(primary) at zinal-slurmctl is UP
EOF
fi
EOS
    chmod +x ${TMP_BIN_DIR}/scontrol
    export PATH=${TMP_BIN_DIR}:${PATH}
  fi

  # Derive SlurmdSpoolDir and TmpFS paths
  SLURMD_SPOOL_DIR=$(scontrol show config | awk '/^SlurmdSpoolDir/ {print $3}')
  SLURM_TMPFS=$(scontrol show config | awk '/^TmpFS/ {print $3}')
  export SLURM_TMPFS

  # Prepare mock PMIx directory
  SLURM_JOB_UID=0
  SLURM_JOB_ID=1
  SLURM_STEP_ID=2
  
  export PMIX_DIR=${SLURMD_SPOOL_DIR}/pmix.${SLURM_JOB_ID}.${SLURM_STEP_ID}
  sudo mkdir -p ${PMIX_DIR}
  sudo chown $(whoami) ${PMIX_DIR}
  sudo chgrp root ${PMIX_DIR}

  # Export test environment variables
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
  rm -rf "${TMP_HOOKS_DIR}" "${TMP_HOOK_LOG_DIR}" "${PMIX_DIR}"

  if [[ -v TMP_BIN_DIR ]]; then
    rm -rf "${TMP_BIN_DIR}"
  fi
}

@test "pmix_hook binds directory (nofail spmix_appdir)" {
  SPMIX_APPDIR_UID_DIR=${SLURM_TMPFS}/spmix_appdir_${SLURM_JOB_UID}_${SLURM_JOB_ID}.${SLURM_STEP_ID}
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
  SPMIX_APPDIR_UID_DIR=${SLURM_TMPFS}/spmix_appdir_${SLURM_JOB_UID}_${SLURM_JOB_ID}.${SLURM_STEP_ID}
  sudo mkdir -p ${SPMIX_APPDIR_UID_DIR}
  sudo chown $(whoami) ${SPMIX_APPDIR_UID_DIR}
  sudo chgrp root ${SPMIX_APPDIR_UID_DIR}
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
  SPMIX_APPDIR_NO_UID_DIR=${SLURM_TMPFS}/spmix_appdir_${SLURM_JOB_ID}.${SLURM_STEP_ID}
  sudo mkdir -p ${SPMIX_APPDIR_NO_UID_DIR}
  sudo chown $(whoami) ${SPMIX_APPDIR_NO_UID_DIR}
  sudo chgrp root ${SPMIX_APPDIR_NO_UID_DIR}
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
