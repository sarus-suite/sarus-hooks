file(GLOB hooks_mount_srcs "*.cpp" "*.c")
list(REMOVE_ITEM hooks_mount_srcs ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp)
add_library(hooks_mount_library STATIC ${hooks_mount_srcs})
target_link_libraries(hooks_mount_library libsarus_static ${Boost_LIBRARIES})

add_executable(mount_hook "main.cpp")
target_link_libraries(mount_hook hooks_mount_library)
install(TARGETS mount_hook DESTINATION ${CMAKE_INSTALL_PREFIX}/bin PERMISSIONS
    OWNER_READ OWNER_WRITE OWNER_EXECUTE
    GROUP_READ GROUP_EXECUTE
    WORLD_READ WORLD_EXECUTE)

