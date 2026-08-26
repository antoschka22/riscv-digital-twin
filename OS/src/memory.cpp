#include "memory.h"
#include <fstream>
#include <iostream>

// Define our virtual hardware addresses
#define UART_TX_ADDR 0x10000000 

Memory::Memory() {
    ram.resize(1024 * 1024, 0); 
    vram.resize(320 * 240 * 4, 0);
    mtime = 0;
    mtimecmp = 0xFFFFFFFFFFFFFFFF; // Default alarm is "never"
    current_key = 0;
}

uint32_t Memory::read32(uint32_t address) {
    // --- MMIO: Timer Registers ---
    if (address == 0x0200BFF8) return mtime & 0xFFFFFFFF;         // Lower 32 bits of mtime
    if (address == 0x0200BFFC) return (mtime >> 32) & 0xFFFFFFFF; // Upper 32 bits of mtime
    if (address == 0x02004000) return mtimecmp & 0xFFFFFFFF;
    if (address == 0x02004004) return (mtimecmp >> 32) & 0xFFFFFFFF;

    // Normal RAM read... (keep your existing code here)
    if (address + 3 < ram.size()) {
        return (uint32_t)(ram[address]) | ((uint32_t)(ram[address + 1]) << 8) |
               ((uint32_t)(ram[address + 2]) << 16) | ((uint32_t)(ram[address + 3]) << 24);
    }
    return 0;
}

void Memory::write32(uint32_t address, uint32_t value) {
    // --- MMIO: Timer Registers ---
    if (address == 0x02004000) { 
        mtimecmp = (mtimecmp & 0xFFFFFFFF00000000) | value; 
        return; 
    }
    if (address == 0x02004004) { 
        mtimecmp = (mtimecmp & 0x00000000FFFFFFFF) | ((uint64_t)value << 32); 
        return; 
    }

    // --- MMIO: Video RAM (0x04000000 to 0x0404AFFF) ---
    if (address >= 0x04000000 && address < 0x0404B000) {
        uint32_t offset = address - 0x04000000;
        vram[offset]     = (value & 0x000000FF);
        vram[offset + 1] = (value & 0x0000FF00) >> 8;
        vram[offset + 2] = (value & 0x00FF0000) >> 16;
        vram[offset + 3] = (value & 0xFF000000) >> 24;
        return;
    }
    
    // Normal RAM write
    if (address + 3 < ram.size()) {
        ram[address]     = (value & 0x000000FF);
        ram[address + 1] = (value & 0x0000FF00) >> 8;
        ram[address + 2] = (value & 0x00FF0000) >> 16;
        ram[address + 3] = (value & 0xFF000000) >> 24;
    }
}

uint8_t Memory::read8(uint32_t address) {
    // --- MMIO: Keyboard ---
    if (address == 0x03000000) {
        return current_key;
    }

    if (address < ram.size()) {
        return ram[address];
    }
    std::cerr << "Memory read fault at: 0x" << std::hex << address << std::endl;
    return 0;
}

uint16_t Memory::read16(uint32_t address) {
    // --- MMIO: Keyboard ---
    if (address == 0x03000000) {
        return current_key;
    }
    
    if (address + 1 < ram.size()) {
        return (uint16_t)(ram[address]) | ((uint16_t)(ram[address + 1]) << 8);
    }
    std::cerr << "Memory read fault at: 0x" << std::hex << address << std::endl;
    return 0;
}

void Memory::write8(uint32_t address, uint8_t value) {
    // --- MMIO ROUTING ---
    // Intercept writes to the UART address and route to the host terminal
    if (address == UART_TX_ADDR) {
        std::cout << (char)value << std::flush;
        return;
    }

    // --- NORMAL RAM ROUTING ---
    if (address < ram.size()) {
        ram[address] = value;
    } else {
        std::cerr << "Memory write fault at: 0x" << std::hex << address << std::endl;
    }
}

void Memory::write16(uint32_t address, uint16_t value) {
    if (address + 1 < ram.size()) {
        ram[address]     = (value & 0x00FF);
        ram[address + 1] = (value & 0xFF00) >> 8;
    } else {
        std::cerr << "Memory write fault at: 0x" << std::hex << address << std::endl;
    }
}

void Memory::load_binary(const char* filename) {
    std::ifstream file(filename, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        std::cerr << "Failed to open binary file: " << filename << std::endl;
        return;
    }

    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    if (file.read(reinterpret_cast<char*>(ram.data()), size)) {
        std::cout << "Loaded " << std::dec << size << " bytes into memory." << std::endl;
        std::cout << "--------------------------\n" << std::endl;
    }
}