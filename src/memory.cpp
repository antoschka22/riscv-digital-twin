
#include "memory.h"
#include <fstream>
#include <iostream>

Memory::Memory() {
    // Allocate 1 Megabyte of RAM, initialized to 0
    ram.resize(1024 * 1024, 0); 
}

uint32_t Memory::read32(uint32_t address) {
    // Check for out-of-bounds memory access
    if (address + 3 >= ram.size()) {
        std::cerr << "Memory read fault at: 0x" << std::hex << address << std::endl;
        return 0;
    }
    
    // Stitch 4 bytes together (Little-Endian)
    return (uint32_t)(ram[address]) |
           ((uint32_t)(ram[address + 1]) << 8) |
           ((uint32_t)(ram[address + 2]) << 16) |
           ((uint32_t)(ram[address + 3]) << 24);
}

void Memory::write32(uint32_t address, uint32_t value) {
    if (address + 3 >= ram.size()) {
        std::cerr << "Memory write fault at: 0x" << std::hex << address << std::endl;
        return;
    }
    
    // Break the 32-bit value into 4 bytes (Little-Endian)
    ram[address]     = (value & 0x000000FF);
    ram[address + 1] = (value & 0x0000FF00) >> 8;
    ram[address + 2] = (value & 0x00FF0000) >> 16;
    ram[address + 3] = (value & 0xFF000000) >> 24;
}

void Memory::load_binary(const char* filename) {
    // Open the binary file at the end to get its size
    std::ifstream file(filename, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        std::cerr << "Failed to open binary file: " << filename << std::endl;
        return;
    }

    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    // Read the file directly into our RAM array starting at address 0
    if (file.read(reinterpret_cast<char*>(ram.data()), size)) {
        std::cout << "Loaded " << size << " bytes into memory." << std::endl;
    }
}