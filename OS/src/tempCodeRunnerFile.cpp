/**
 * @brief Minimal Memory Implementation
 *
 * A simplified version of the memory controller. It handles 1MB of RAM allocation, 
 * Little-Endian memory translation, and basic out-of-bounds fault checking, but 
 * lacks the MMIO routing present in the full memory.cpp file.
 */
#include "memory.h"
#include <fstream>
#include <iostream>

/**
 * @brief Initializes the memory subsystem.
 */
Memory::Memory() {
    // Allocate 1 Megabyte (1024 * 1024 bytes) of RAM, initialized to 0
    ram.resize(1024 * 1024, 0); 
}

/**
 * @brief Reads a 32-bit word from memory.
 * Combines 4 consecutive bytes into a single 32-bit integer using Little-Endian byte order
 */
uint32_t Memory::read32(uint32_t address) {
    // Check for out-of-bounds memory access before reading
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

/**
 * @brief Writes a 32-bit word to memory.
 * Splits a 32-bit integer into 4 consecutive bytes using Little-Endian byte order
 */
void Memory::write32(uint32_t address, uint32_t value) {
    // Check for out-of-bounds memory access before writing
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

/**
 * @brief Injects a compiled binary payload into the RAM space
 */
void Memory::load_binary(const char* filename) {
    // Open the binary file at the end (std::ios::ate) to easily calculate its size
    std::ifstream file(filename, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        std::cerr << "Failed to open binary file: " << filename << std::endl;
        return;
    }

    // Capture the size, then rewind the file pointer to the beginning
    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    // Read the file directly into our RAM array starting at address 0
    if (file.read(reinterpret_cast<char*>(ram.data()), size)) {
        std::cout << "Loaded " << size << " bytes into memory." << std::endl;
    }
}