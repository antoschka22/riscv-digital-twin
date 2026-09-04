/**
 * @brief Memory Controller and MMIO Router
 *
 * Simulates a system bus. It manages main RAM and intercepts specific memory 
 * addresses to simulate hardware peripherals like Video RAM (VRAM), a hardware 
 * timer, a keyboard, and a UART serial connection
 */
#include "memory.h"
#include <fstream>
#include <iostream>

// Virtual hardware address for serial transmission
#define UART_TX_ADDR 0x10000000 

Memory::Memory() {
    ram.resize(1024 * 1024, 0);       // Allocate 1 MB of main RAM
    vram.resize(320 * 240 * 4, 0);    // Allocate space for a 320x240 32-bit color display
    
    mtime = 0;                        // Initialize machine timer
    mtimecmp = 0xFFFFFFFFFFFFFFFF;    // Default alarm is set to max to prevent immediate interrupts
    current_key = 0;                  // Initialize keyboard state
}

/**
 * @brief 32-bit Word Read with MMIO Routing
 */
uint32_t Memory::read32(uint32_t address) {
    // --- MMIO: Timer Registers ---
    // The OS scheduler reads these specific addresses to check the hardware timer
    if (address == 0x0200BFF8) return mtime & 0xFFFFFFFF;         // Lower 32 bits of mtime
    if (address == 0x0200BFFC) return (mtime >> 32) & 0xFFFFFFFF; // Upper 32 bits of mtime
    if (address == 0x02004000) return mtimecmp & 0xFFFFFFFF;      // Lower 32 bits of mtimecmp
    if (address == 0x02004004) return (mtimecmp >> 32) & 0xFFFFFFFF; // Upper 32 bits of mtimecmp

    // --- Normal RAM Read ---
    // Reconstructs a 32-bit integer from 4 distinct bytes (Little Endian)
    if (address + 3 < ram.size()) {
        return (uint32_t)(ram[address]) | ((uint32_t)(ram[address + 1]) << 8) |
               ((uint32_t)(ram[address + 2]) << 16) | ((uint32_t)(ram[address + 3]) << 24);
    }
    return 0;
}

/**
 * @brief 32-bit Word Write with MMIO Routing
 */
void Memory::write32(uint32_t address, uint32_t value) {
    // --- MMIO: Timer Registers ---
    if (address == 0x02004000) { 
        mtimecmp = (mtimecmp & 0xFFFFFFFF00000000) | value;  // Update lower 32 bits
        return; 
    }
    if (address == 0x02004004) { 
        mtimecmp = (mtimecmp & 0x00000000FFFFFFFF) | ((uint64_t)value << 32); // Update upper 32 bits
        return; 
    }

    // --- MMIO: Video RAM ---
    // If the address falls within the VRAM block (0x04000000 to 0x0404AFFF), route the write to the video buffer
    if (address >= 0x04000000 && address < 0x0404B000) {
        uint32_t offset = address - 0x04000000;
        vram[offset]     = (value & 0x000000FF);
        vram[offset + 1] = (value & 0x0000FF00) >> 8;
        vram[offset + 2] = (value & 0x00FF0000) >> 16;
        vram[offset + 3] = (value & 0xFF000000) >> 24;
        return;
    }
    
    // --- Normal RAM Write ---
    // Break the 32-bit value into 4 bytes for storage
    if (address + 3 < ram.size()) {
        ram[address]     = (value & 0x000000FF);
        ram[address + 1] = (value & 0x0000FF00) >> 8;
        ram[address + 2] = (value & 0x00FF0000) >> 16;
        ram[address + 3] = (value & 0xFF000000) >> 24;
    }
}

/**
 * @brief 8-bit Byte Read with MMIO Routing
 */
uint8_t Memory::read8(uint32_t address) {
    // --- MMIO: Keyboard ---
    // Memory mapping the current pressed key to address 0x03000000
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
        return current_key;[cite: 10]
    }
    
    if (address + 1 < ram.size()) {
        return (uint16_t)(ram[address]) | ((uint16_t)(ram[address + 1]) << 8);[cite: 10]
    }
    std::cerr << "Memory read fault at: 0x" << std::hex << address << std::endl;
    return 0;
}

/**
 * @brief 8-bit Byte Write with MMIO Routing
 */
void Memory::write8(uint32_t address, uint8_t value) {
    // --- MMIO ROUTING ---
    // Intercept writes to the UART address and print them to the host terminal directly
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
        ram[address + 1] = (value & 0xFF00) >> 8;[cite: 10]
    } else {
        std::cerr << "Memory write fault at: 0x" << std::hex << address << std::endl;
    }
}

/**
 * @brief Loads a compiled binary firmware image into RAM.
 * Opens the provided file, checks its size, and copies the contents directly 
 * into the main RAM vector starting at address 0x0
 */
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