#include "cpu.h"
#include <iostream>
#include <iomanip>
#include <cstdint>

int main() {
    Memory mem;
    
    // Load your compiled RISC-V C code
    mem.load_binary("../test_firmware/firmware.bin"); 
    
    CPU cpu(&mem);

    std::cout << "Starting CPU..." << std::endl;
    std::cout << "--------------------------" << std::endl;

    // Run continuously until step() returns false
    while (cpu.step()) {
        // The CPU is running!
    }

    // Print the final state after the CPU halts
    cpu.dump_registers();

    return 0;
}