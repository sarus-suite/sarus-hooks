file(GLOB hooks_ldcache_srcs "*.cpp" "*.c")
list(REMOVE_ITEM hooks_ldcache_srcs ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp)
add_library(hooks_ldcache_library STATIC ${hooks_ldcache_srcs})
target_link_libraries(hooks_ldcache_library libsarus_static ${Boost_LIBRARIES})

add_executable(ldcache_hook "main.cpp")
target_link_libraries(ldcache_hook hooks_ldcache_library)
install(TARGETS ldcache_hook DESTINATION ${CMAKE_INSTALL_PREFIX}/bin PERMISSIONS
    OWNER_READ OWNER_WRITE OWNER_EXECUTE
    GROUP_READ GROUP_EXECUTE
    WORLD_READ WORLD_EXECUTE)

