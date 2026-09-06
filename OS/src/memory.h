/**
 * @brief System Memory and Peripherals Interface
 *
 * This class simulates the system bus of the RISC-V environment. It manages 
 * the main RAM, Video RAM (VRAM), and holds state for memory-mapped I/O (MMIO) 
 * components such as the hardware timer and keyboard input
 */
#pragma once
#include <cstdint>
#include <vector>

class Memory {
public:
    // --- Memory Buffers ---
    std::vector<uint8_t> ram;   // Main system RAM array
    std::vector<uint8_t> vram;  // Video RAM for the display buffer
    
    // --- Hardware Timer Registers ---
    // 64-bit registers used by the core to generate timer interrupts
    uint64_t mtime;             // Current machine time (increments per cycle)
    uint64_t mtimecmp;          // Timer compare threshold for interrupts

    // --- Peripheral State ---
    uint8_t current_key;        // Stores the latest keyboard character pressed

    /**
     * @brief Constructor initializes memory sizes and default hardware states
     */
    Memory();
    
    // --- Core Read/Write Operations ---
    // All memory access must route through these methods to allow MMIO interception
    uint32_t read32(uint32_t address);
    void write32(uint32_t address, uint32_t value);
    
    /**
     * @brief Loads a raw executable binary directly into the RAM array
     * @param filename Path to the binary file to be executed.
     */
    void load_binary(const char* filename);

    // --- Sub-word Memory Access ---
    uint8_t read8(uint32_t address);
    uint16_t read16(uint32_t address);
    
    void write8(uint32_t address, uint8_t value);
    void write16(uint32_t address, uint16_t value);
};