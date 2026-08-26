#!/bin/bash

# Stop execution if any command fails
set -e

cd test_firmware
echo "Compiling assembly..."
riscv64-elf-gcc -march=rv32im_zicsr -mabi=ilp32 -O0 -ffreestanding -nostdlib -T linker.ld crt0.s trap.s main.c -o firmware.elf

echo "Creating binary..."
riscv64-elf-objcopy -O binary firmware.elf firmware.bin
cd ..

echo "Running CMake..."
cmake -B build && cmake --build build

echo "Build complete!"