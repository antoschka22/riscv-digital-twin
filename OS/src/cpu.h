/**
 * @brief RISC-V CPU Core Definitions
 *
 * Defines the state and interface for a 32-bit RISC-V CPU emulator. It includes 
 * standard general-purpose registers, the program counter, and the Control and 
 * Status Register (CSR) space required for machine-mode operations
 */
#pragma once
#include <cstdint>
#include <unordered_map>
#include "memory.h"

// --- Core Machine-Mode CSR Addresses ---
// These addresses correspond to the RISC-V privileged specification
constexpr uint16_t CSR_MSTATUS = 0x300; // Machine status register
constexpr uint16_t CSR_MTVEC   = 0x305; // Machine trap-handler base address
constexpr uint16_t CSR_MEPC    = 0x341; // Machine exception program counter
constexpr uint16_t CSR_MCAUSE  = 0x342; // Machine trap cause
constexpr uint16_t CSR_MTVAL   = 0x343; // Machine bad address or instruction

class CPU {
private:
    uint32_t regs[32];   // General purpose registers x0 to x31
    uint32_t pc;         // Program Counter
    Memory* mem;         // Pointer to the system memory/bus
    
    // RISC-V architecture reserves a 12-bit address space for CSRs,
    // allowing up to 4096 unique control registers
    uint32_t csrs[4096]; 

    // --- Internal Helpers ---
    uint32_t read_csr(uint16_t addr);
    void write_csr(uint16_t addr, uint32_t value);
    
    /**
     * @brief Triggers a machine-level trap (exception or interrupt)
     * @param cause The exception code to be written to mcause
     * @param tval Optional trap value (e.g., faulting address) to be written to mtval
     */
    void trap(uint32_t cause, uint32_t tval = 0);

public:
    CPU(Memory* memory_instance);
    
    /**
     * @brief Executes a single instruction cycle
     * @return true if execution should continue, false if a halt (e.g., EBREAK) is encountered
     */
    bool step(); 
    
    /**
     * @brief Dumps the current state of all CPU registers to the console
     */
    void dump_registers();
};