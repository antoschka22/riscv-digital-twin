#include "memory.h"
#include "cpu.h"
#include <iostream>
#include <iomanip>

int main() {
    Memory mem;
    // Load your compiled RISC-V code here
    mem.load_binary("../test_firmware/firmware.bin"); 
    
    CPU cpu(&mem);

    // Run up to 100 instructions, but stop early if step() returns false
    for(int i = 0; i < 100; i++) {
        if (cpu.step() == false) {
            break; // Exit the loop safely
        }
    }

    cpu.dump_registers();

    return 0;
}

void CPU::dump_registers() {
    // Standard RISC-V ABI register names
    const char* abi_names[] = {
        "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
        "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
        "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
        "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
    };

    std::cout << "\n--- CPU Register State ---" << std::endl;
    for (int i = 0; i < 32; i++) {
        // Print format: x00 (zero) : 0x00000000
        std::cout << "x" << std::setfill('0') << std::setw(2) << std::dec << i 
                  << " (" << std::setfill(' ') << std::setw(4) << abi_names[i] << ") : "
                  << "0x" << std::setfill('0') << std::setw(8) << std::hex << regs[i];
                  
        // Print 4 registers per row
        if ((i + 1) % 4 == 0) {
            std::cout << std::endl;
        } else {
            std::cout << "   |   ";
        }
    }
    // Print the Program Counter
    std::cout << "PC         : 0x" << std::setfill('0') << std::setw(8) << std::hex << pc << std::endl;
    std::cout << "--------------------------\n" << std::endl;
}