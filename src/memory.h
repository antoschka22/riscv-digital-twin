#pragma once
#include <cstdint>
#include <vector>

class Memory {
public:
    // 1MB of RAM
    std::vector<uint8_t> ram;

    Memory();
    
    // Read/Write operations
    uint32_t read32(uint32_t address);
    void write32(uint32_t address, uint32_t value);
    
    // Load a raw binary file into the RAM array
    void load_binary(const char* filename);
};