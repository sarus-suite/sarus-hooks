# Sarus Hooks - OCI hooks for HPC use cases

## Building the hooks
1. Ensure the `dep/rapidjson` Git submodule is correctly initialized
2. Enter one of the Dev Containers, either through a supporting tool (e.g. VSCode) or by starting the container manually
3. Install libsarus headers and library in paths visible to build tools (e.g. `/usr/include` and `/usr/lib` respectively)
4. ```
   mkdir build && cd build
   cmake -DENABLE_UNIT_TESTS=0 -DBUILD_DROPBEAR=0 ..
   make -j
   ```


## Usage Tips

Hooks are configured via a configuration json, each hook has its own configuration file and it allows it to control when and how the hook is executed for containers that require the functionality within the lifecycle stage of the container.

Hook configuration are kept in a common directory, the Hook configuration files (ending in .json) are executed in order by json file. Using file names that facilitate ordering is recommended (e.g. 01-mount.json, 02-ldcache.json, ...)

### 1.0.0 Hook Schema (ref: https://github.com/containers/common/blob/main/pkg/hooks/docs/oci-hooks.5.md#100-hook-schema)

- **version** (required string) – Sets the hook-definition version. For this schema version, the value should be `1.0.0`.
- **hook** (required object) – The hook to inject, with the hook-entry schema defined by the 1.0.2 OCI Runtime Specification.
- **when** (required object) – Conditions under which the hook is injected. At least one of the following properties must be specified:
   - **always** (optional boolean) – If set true, this condition matches.
   - **annotations** (optional object) – If all annotations key/value pairs match a key/value pair from the configured annotations, this condition matches. Both keys and values must be POSIX extended regular expressions.
   - **commands** (optional array of strings) – If the configured `process.args[0]` matches an entry, this condition matches. Entries must be POSIX extended regular expressions.
   - **hasBindMounts** (optional boolean) – If `hasBindMounts` is true and the caller requested host-to-container bind mounts, this condition matches.
- **stages** (required array of strings) – Stages when the hook must be injected. Entries must be chosen from the 1.0.2 OCI Runtime Specification hook stages or from extension stages supported by the package consumer.

If all of the conditions set in when match, then the hook must be injected for the stages set in stages.

### Example
~~~
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
~~~

### Debug Hooks in Podman

Hooks can generate log output at different debug levels. Moreover, the crun container runtime has mechanisms that allow to recover the stdout and stderr of hooks via annotations, this can be done with podman as follows, assuming that we keep the hook configuration json under a dir TMP_HOOKS_DIR:

~~~
  podman --runtime="crun" \
    --hooks-dir "${TMP_HOOKS_DIR}" \
    run --rm \
    --annotation com.hooks.logging.level=0 \
    --annotation run.oci.hooks.stdout="/tmp/hook.out" \
    --annotation run.oci.hooks.stderr="/tmp/hook.err" \
    ubuntu:22:04 bash -lc "ls /"
~~~

## TODO
- Fix build of unit tests
- Fix build of Dropbear
- Fix installation directory
- Build with static libsarus
- Integration tests
