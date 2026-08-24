#include "cpu.h"
#include <iostream>

CPU::CPU(Memory* memory_instance) {
    mem = memory_instance;
    pc = 0x00000000; // Start booting at address 0
    
    // Initialize all registers to 0
    for(int i = 0; i < 32; i++) {
        regs[i] = 0;
    }
}

void CPU::step() {
    // 1. FETCH: Get the 32-bit instruction at the current PC
    uint32_t instruction = mem->read32(pc);

    // 2. DECODE: Extract the lowest 7 bits to find the opcode
    uint32_t opcode = instruction & 0x7F;
    
    // Extract register indices (shifted down, masked to 5 bits)
    uint32_t rd  = (instruction >> 7) & 0x1F;
    uint32_t rs1 = (instruction >> 15) & 0x1F;
    uint32_t rs2 = (instruction >> 20) & 0x1F;

    // 3. EXECUTE
    switch(opcode) {
        case 0x13: // ADDI (Add Immediate)
            {
                // Sign-extend the top 12 bits
                int32_t imm = ((int32_t)instruction) >> 20; 
                
                // Add rs1 and immediate, store in rd
                if (rd != 0) { // Never write to register 0
                    regs[rd] = regs[rs1] + imm; 
                }
                pc += 4; // Move to next instruction
            }
            break;
            
        // TODO: Add cases for LOAD, STORE, BRANCH, JAL, etc.
        
        default:
            std::cout << "Unknown opcode: " << std::hex << opcode << std::endl;
            exit(1);
    }
}