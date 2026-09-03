/**
 * @brief C Runtime Initialization 
 * 
 * This assembly script executes immediately upon processor boot. It prepares the 
 * environment for C code execution by initializing the stack pointer and zeroing 
 * out uninitialized global variables before jumping to the main() function.
 */
.section .text.init
.globl _start

_start:
    # Initialize the stack pointer (sp)
    # The __stack_top symbol is dynamically resolved from the linker script
    # to point to the end of the available RAM
    la sp, __stack_top

    # Clear the BSS section
    # The C standard requires uninitialized global/static variables to be zeroed out
    la t0, __bss_start
    la t1, __bss_end
bss_clear_loop:
    bgeu t0, t1, bss_clear_done # Branch to completion if start address >= end address
    sw zero, 0(t0)              # Store 32 bits of zero into the current memory address
    addi t0, t0, 4              # Increment the pointer by 4 bytes (1 word)
    j bss_clear_loop            # Loop until the entire BSS section is cleared
bss_clear_done:

    # Transfer control to the main application.
    # jal (jump and link) saves the return address in the 'ra' register.
    jal ra, main

    # Fail-safe trap
    # In an embedded environment, main() should never return
    # If it does, an environment break (ebreak) is triggered to halt the CPU/emulator safely
    ebreak