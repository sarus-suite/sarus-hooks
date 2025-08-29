cmake_minimum_required(VERSION 3.10 FATAL_ERROR)

project("Sarus Hooks")

enable_testing()
set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CMAKE_SOURCE_DIR}/cmake/modules)
set(CMAKE_CXX_OUTPUT_EXTENSION_REPLACE 1) # required for gcov (e.g. will generate example.gcno instead of example.cpp.gcno)

# build statically-linked executables
if(${BUILD_STATIC})
    set(CMAKE_FIND_LIBRARY_SUFFIXES ".a")
    set(CMAKE_EXE_LINKER_FLAGS "-static")
    set(CMAKE_LINK_SEARCH_START_STATIC TRUE)
    set(CMAKE_LINK_SEARCH_END_STATIC TRUE)
    set(Boost_USE_STATIC_LIBS ON)
endif(${BUILD_STATIC})

set(LIBEXECDIR ${CMAKE_INSTALL_PREFIX}/libexec CACHE PATH "libexec directory [$CMAKE_INSTALL_PREFIX/libexec]")
set(BUILD_DROPBEAR TRUE CACHE BOOL "Build the statically-linked Dropbear SSH software to be executed inside the container [TRUE]")

set(ENABLE_UNIT_TESTS TRUE CACHE BOOL "Build unit tests. Also downloads and builds the CppUTest framework [TRUE]")
#set(ENABLE_TESTS_WITH_VALGRIND FALSE CACHE BOOL "Run each unit test through valgrind [FALSE]")

set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

message(STATUS "Installation directory: " ${CMAKE_INSTALL_PREFIX})
message(STATUS "Build Dropbear: " ${BUILD_DROPBEAR})

include_directories(${CMAKE_SOURCE_DIR}/dep/rapidjson/include)
include_directories(${CMAKE_SOURCE_DIR}/dep/libsarus/include)

find_package(Boost REQUIRED NO_MODULE COMPONENTS program_options filesystem regex)
include_directories(${Boost_INCLUDE_DIRS})

find_program(GIT_PATH git)

execute_process(COMMAND ${GIT_PATH} describe --tags --dirty --always
                WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
                OUTPUT_VARIABLE LATEST_GIT_TAG
                OUTPUT_STRIP_TRAILING_WHITESPACE)
if(NOT LATEST_GIT_TAG)
    set(LATEST_GIT_TAG VERSION-NOT-AVAILABLE)
endif(NOT LATEST_GIT_TAG)
message(STATUS "Sarus Hooks version: " ${LATEST_GIT_TAG})

add_subdirectory(dep)
add_subdirectory(src)
