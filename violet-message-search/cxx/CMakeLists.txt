# Cmake config largely taken from catch2
cmake_minimum_required(VERSION 3.5)

project(binding)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_FLAGS_RELEASE "-O2")
set(CMAKE_BUILD_TYPE Release)

add_subdirectory(RapidFuzz-cpp)

add_library(binding main.cpp)
target_link_libraries(binding rapidfuzz::rapidfuzz)