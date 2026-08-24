#pragma once
#include <cstdint>
#include "memory.h"

class CPU {
private:
    uint32_t regs[32]; // x0 to x31
    uint32_t pc;       // Program Counter
    Memory* mem;       // Pointer to the system bus/memory

public:
    CPU(Memory* memory_instance);
    
    // The main loop function
    void step(); 
    
    // Debugging
    void dump_registers();
};