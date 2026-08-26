#pragma once
#include <cstdint>
#include <vector>

class Memory {
public:
    std::vector<uint8_t> ram;
    
    // Hardware Timer Registers (64-bit)
    uint64_t mtime;
    uint64_t mtimecmp;

    Memory();
    
    // Read/Write operations
    uint32_t read32(uint32_t address);
    void write32(uint32_t address, uint32_t value);
    
    // Load a raw binary file into the RAM array
    void load_binary(const char* filename);

    uint8_t read8(uint32_t address);
    uint16_t read16(uint32_t address);
    
    void write8(uint32_t address, uint8_t value);
    void write16(uint32_t address, uint16_t value);
};