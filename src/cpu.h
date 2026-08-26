#pragma once
#include <cstdint>
#include <unordered_map>
#include "memory.h"

// Define core Machine-mode CSR addresses
constexpr uint16_t CSR_MSTATUS = 0x300;
constexpr uint16_t CSR_MTVEC   = 0x305;
constexpr uint16_t CSR_MEPC    = 0x341;
constexpr uint16_t CSR_MCAUSE  = 0x342;
constexpr uint16_t CSR_MTVAL   = 0x343;

class CPU {
private:
    uint32_t regs[32]; // x0 to x31
    uint32_t pc;       // Program Counter
    Memory* mem;       // Pointer to the system bus/memory
    uint32_t csrs[4096]; // RISC-V has a 12-bit CSR address space

    // CSR access helpers
    uint32_t read_csr(uint16_t addr);
    void write_csr(uint16_t addr, uint32_t value);
    
    // Trap handler
    void trap(uint32_t cause, uint32_t tval = 0);

public:
    CPU(Memory* memory_instance);
    
    bool step(); 
    void dump_registers();
};