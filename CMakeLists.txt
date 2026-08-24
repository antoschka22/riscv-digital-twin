cmake_minimum_required(VERSION 3.10)
project(AnvilEmulator VERSION 1.0)
set(CMAKE_CXX_STANDARD 17)

# Add all your C++ files here
add_executable(anvil_emu src/main.cpp src/cpu.cpp src/memory.cpp)