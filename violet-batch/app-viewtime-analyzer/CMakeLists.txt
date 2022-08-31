set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_FLAGS_RELEASE "-O2" ) 
set(CMAKE_BUILD_TYPE Release)

add_executable(vz Main.cpp simdjson.cpp)
add_executable(zz Main2.cpp simdjson.cpp)