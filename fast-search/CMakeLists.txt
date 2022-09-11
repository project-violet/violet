set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_FLAGS_RELEASE "-O2" ) 
set(CMAKE_BUILD_TYPE Release)

# https://github.com/maxbachmann/rapidfuzz-cpp
add_subdirectory(3rdparty/RapidFuzz)

add_executable(fscm Main.cpp simdjson.cpp)
target_link_libraries(fscm rapidfuzz::rapidfuzz)
add_executable(fscm-eng Main-English.cpp simdjson.cpp)
target_link_libraries(fscm-eng rapidfuzz::rapidfuzz)

find_package(OpenMP)
if (OPENMP_FOUND)
    set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${OpenMP_C_FLAGS}")
    set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS}")
    set (CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${OpenMP_EXE_LINKER_FLAGS}")
endif()
