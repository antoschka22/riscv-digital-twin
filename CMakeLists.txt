cmake_minimum_required(VERSION 3.10)
project(AnvilEmulator VERSION 1.0)
set(CMAKE_CXX_STANDARD 17)

find_package(SDL2 REQUIRED)

add_executable(anvil_emu src/main.cpp src/cpu.cpp src/memory.cpp)

target_include_directories(anvil_emu PRIVATE ${SDL2_INCLUDE_DIRS})

target_link_libraries(anvil_emu PRIVATE ${SDL2_LIBRARIES})