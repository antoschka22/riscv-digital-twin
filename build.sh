#!/bin/bash

# Stop execution if any command fails
set -e

cd test_firmware
echo "Compiling assembly..."
riscv64-elf-gcc -march=rv32i -mabi=ilp32 -c test.s -o test.o

echo "Creating binary..."
riscv64-elf-objcopy -O binary test.o firmware.bin
cd ..

echo "Running CMake..."
cmake -B build && cmake --build build

echo "Build complete!"