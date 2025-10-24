file(GLOB hooks_pmix_srcs "*.cpp" "*.c")
list(REMOVE_ITEM hooks_pmix_srcs ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp)
add_library(hooks_pmix_library STATIC ${hooks_pmix_srcs})
target_link_libraries(hooks_pmix_library libsarus ${Boost_LIBRARIES})

add_executable(pmix_hook "main.cpp")
target_link_libraries(pmix_hook hooks_pmix_library)
install(TARGETS pmix_hook DESTINATION ${CMAKE_INSTALL_PREFIX}/bin PERMISSIONS
    OWNER_READ OWNER_WRITE OWNER_EXECUTE
    GROUP_READ GROUP_EXECUTE
    WORLD_READ WORLD_EXECUTE)

