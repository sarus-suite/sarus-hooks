setup_file() {
  # [Common] Make sure Podman doesn't use /run/users 
  unset XDG_RUNTIME_DIR

  # [Common] Define 'sarus-hooks' source root
  export SARUS_HOOKS_SRC_ROOT=$(realpath $BATS_TEST_DIRNAME/../src)
  echo ${BASH_SOURCE[0]}
  echo ${SARUS_HOOKS_SRC_ROOT}

  # [Common] Create hook config
  export TMP_HOOKS_DIR=$(mktemp -d --tmpdir=/scratch/shared/scratch/sarus-suite)
  export HOOK_BIN_PATH="/scratch/shared/podman-hooks/bin/pmix_hook"
  cat > "${TMP_HOOKS_DIR}/pmix-hook.json" <<EOF
{
  "version": "1.0.0",
  "hook": {
    "path": "$HOOK_BIN_PATH"
  },
  "when": { "always": true },
  "stages": ["createContainer"]
}
EOF

  # [Common] Create podman module
  export TMP_MODULE=$(mktemp --tmpdir=/scratch/shared/scratch/sarus-suite)
  cat > "${TMP_MODULE}" <<EOF
[containers]
ipcns = "host"
netns = "host"
pidns = "host"
utsns = "host"
userns = "keep-id"
cgroupns = "host"
cgroups = "no-conmon"

[engine]
runtime = "crun"
conmon_path = ["/usr/local/vs-ce-podman/conmon-2.1.13"]

[engine.runtimes]
crun = ["/usr/local/vs-ce-podman/crun-1.24"]
EOF

  # [Common] Create and print hook stdout/stderr
  export LOCAL_TMP_HOOK_LOG_DIR="$(mktemp -d)"
  export LOCAL_HOOK_OUT="${LOCAL_TMP_HOOK_LOG_DIR}/out.log"
  export LOCAL_HOOK_ERR="${LOCAL_TMP_HOOK_LOG_DIR}/err.log"

  # [PMIx hook specific] Prepare mock 'scontrol'
  if ! which scontrol >/dev/null 2>&1; then
    echo "$0: info: scontrol not found. installing scontrol-mock..."

    export TMP_BIN_DIR=$(mktemp -d)
    export SCONTROL_MOCK=${TMP_BIN_DIR}/scontrol
    cat <<EOS >${SCONTROL_MOCK}
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
    chmod +x ${SCONTROL_MOCK}
    export PATH=${TMP_BIN_DIR}:${PATH}
  fi

  # [PMIx hook specific] Derive SlurmdSpoolDir and TmpFS paths
  export SLURMD_SPOOL_DIR=$(scontrol show config | awk '/^SlurmdSpoolDir/ {print $3}')
  export SLURM_TMPFS=$(scontrol show config | awk '/^TmpFS/ {print $3}')
}

teardown_file() {
  # [Common] Remove hook config and log
  rm -rf "${TMP_HOOKS_DIR}" "${TMP_MODULE}" "${LOCAL_TMP_HOOK_LOG_DIR}"

  # [PMIx hook specific] Remove the temporary binary
  if [[ -v TMP_BIN_DIR ]]; then
    rm -rf "${TMP_BIN_DIR}"
  fi
}


setup() {
  # [Common] Create log
  touch "${LOCAL_HOOK_OUT}" "${LOCAL_HOOK_ERR}"

  # [Common] Start log printers
  tail -fn +1 "${LOCAL_HOOK_OUT}" &
  export LOCAL_HOOK_OUT_PID=$!
  tail -fn +1 "${LOCAL_HOOK_ERR}" &
  export LOCAL_HOOK_ERR_PID=$!
}

teardown() {
  # [Common] Stop log printers 
  kill "${LOCAL_HOOK_OUT_PID}" "${LOCAL_HOOK_ERR_PID}"
  wait "${LOCAL_HOOK_OUT_PID}" "${LOCAL_HOOK_ERR_PID}" 2>/dev/null || true

  # [Common] Clear log
  rm "${LOCAL_HOOK_OUT}" "${LOCAL_HOOK_ERR}"
}

@test "pmix_hook mock pmix directories" {
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

  # Test: spmix_appdir with SLURM_JOB_UID
  SPMIX_APPDIR_UID_DIR=${SLURM_TMPFS}/spmix_appdir_${SLURM_JOB_UID}_${SLURM_JOB_ID}.${SLURM_STEP_ID}
  sudo mkdir -p ${SPMIX_APPDIR_UID_DIR}
  sudo chown $(whoami) ${SPMIX_APPDIR_UID_DIR}
  sudo chgrp root ${SPMIX_APPDIR_UID_DIR}

  export SLURM_JOB_UID
  export SLURM_JOB_ID
  export SLURM_STEP_ID

  podman --runtime=crun \
    --hooks-dir "${TMP_HOOKS_DIR}" \
    run --rm \
      --annotation run.oci.hooks.stdout="${LOCAL_HOOK_OUT}" \
      --annotation run.oci.hooks.stderr="${LOCAL_HOOK_ERR}" \
      alpine sh -c "([ -d ${SPMIX_APPDIR_UID_DIR} ] || ! echo \"error: no spmix_appdir\") && \
            ([ -d ${PMIX_DIR} ] || ! echo \"error: no pmix dir\")"

  # Test: spmix_appdir without SLURM_JOB_UID
  SPMIX_APPDIR_NO_UID_DIR=${SLURM_TMPFS}/spmix_appdir_${SLURM_JOB_ID}.${SLURM_STEP_ID}
  sudo mkdir -p ${SPMIX_APPDIR_NO_UID_DIR}
  sudo chown $(whoami) ${SPMIX_APPDIR_NO_UID_DIR}
  sudo chgrp root ${SPMIX_APPDIR_NO_UID_DIR}

  unset SLURM_JOB_UID
  export SLURM_JOB_ID
  export SLURM_STEP_ID

  podman --runtime=crun \
    --hooks-dir "${TMP_HOOKS_DIR}" \
    run --rm \
      --annotation run.oci.hooks.stdout="${LOCAL_HOOK_OUT}" \
      --annotation run.oci.hooks.stderr="${LOCAL_HOOK_ERR}" \
      alpine sh -c "([ -d ${SPMIX_APPDIR_NO_UID_DIR} ] || ! echo \"error: no spmix_appdir\") && \
            ([ -d ${PMIX_DIR} ] || ! echo \"error: no pmix dir\")"

  # Cleanup
  sudo rm -rf "${SPMIX_APPDIR_NO_UID_DIR}" "${SPMIX_APPDIR_UID_DIR}" "${PMIX_DIR}"
}

@test "pmix_hook srun pmix directories" {
  # Check if srun-created PMIx directories are mounted well
  srun --mpi pmix bash -c 'podman --module '"${TMP_MODULE}"' \
    --hooks-dir '"${TMP_HOOKS_DIR}"' \
    run --rm ubuntu bash -c "find '"${SLURM_TMPFS}"' -maxdepth 1 -name spmix_appdir* && \
      find '"${SLURMD_SPOOL_DIR}"' -maxdepth 1 -name pmix*"'
}

@test "pmix_hook srun OSU pt2pt" {
  # Check if OSU pt2pt is running well
  # Note: OSU pt2pt doesn't run unless there are two distinct MPI ranks
  # TODO: create a precreate hook for Lines 179~182.
  # TODO: (PMIX_MCA_* should be created only when they're not pre-defined.)
  srun -n2 --mpi pmix bash -c '\
    podman --module='"${TMP_MODULE}"' \
      --hooks-dir='"${TMP_HOOKS_DIR}"' \
      run --rm \
        --env PMIX_MCA_gds=$PMIX_GDS_MODULE \
        --env PMIX_MCA_psec=$PMIX_SECURITY_MODE \
        --env PMIX_MCA_ptl=$PMIX_PTL_MODULE \
        --env PMIX_* \
        quay.io/madeeks/osu-mb:7.3-ompi5.0.5-ofi1.15.0-x86_64 \
          bash -c '"'"'env | grep ^PMIX_ && ./pt2pt/osu_bw -m 8'"'"' '
}

@test "pmix_hook skip if TmpFS=(null)" {
  # Prepare mock 'scontrol' with (null) TmpFS
  SCONTROL_NULL_DIR=$(mktemp -d)
  SCONTROL_NULL=${SCONTROL_NULL_DIR}/scontrol

  cat <<EOS >${SCONTROL_NULL}
#!/bin/bash

if [[ "\$1" == "show" ]] && [[ "\$2" == "config" ]]; then
  cat <<EOF
EOS
  scontrol show config >>${SCONTROL_NULL}
  sed 's/^TmpFS.*/TmpFS = (null)/g' -i ${SCONTROL_NULL}
  cat <<EOS >>${SCONTROL_NULL}
EOF
fi
EOS

  chmod +x ${SCONTROL_NULL}
  export PATH=${SCONTROL_NULL_DIR}:${PATH}

  # See if the PMIx hook was skipped.
  podman --runtime=crun \
    --hooks-dir "${TMP_HOOKS_DIR}" \
    run --rm \
      --annotation run.oci.hooks.stdout="${LOCAL_HOOK_OUT}" \
      --annotation run.oci.hooks.stderr="${LOCAL_HOOK_ERR}" \
      alpine echo

  cat ${LOCAL_HOOK_OUT} | grep "No PMIx support." >/dev/null 2>&1

  # Cleanup
  rm -rf "${SCONTROL_NULL_DIR}"
}
