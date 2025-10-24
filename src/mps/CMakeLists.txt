cmake_minimum_required(VERSION 3.10)
project(mps_hook CXX)

add_executable(mps_hook "MpsHook.cpp")
target_compile_features(mps_hook PRIVATE cxx_std_14)

target_link_libraries(mps_hook PRIVATE libsarus ${Boost_LIBRARIES})

install(TARGETS mps_hook
  DESTINATION ${CMAKE_INSTALL_PREFIX}/bin
)
