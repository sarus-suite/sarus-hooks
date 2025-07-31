# Sarus Hooks - OCI hooks for HPC use cases

## Build
1. Ensure the `dep/rapidjson` Git submodule is correctly initialized
2. Enter one of the Dev Containers, either through a supporting tool (e.g. VSCode) or by starting the container manually
3. Install libsarus headers and library in paths visible to build tools (e.g. `/usr/include` and `/usr/lib` respectively)
4. ```
   mkdir build && cd build
   cmake -DENABLE_UNIT_TESTS=0 -DBUILD_DROPBEAR=0 ..
   make -j
   ```

## TODO
- Fix build of unit tests
- Fix build of Dropbear
- Fix installation directory
- Build with static libsarus
- Integration tests
