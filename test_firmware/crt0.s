# crt0.s
.section .text.init
.globl _start

_start:
    # 1. Initialize the stack pointer using the symbol from linker.ld
    la sp, __stack_top

    # 2. Clear the BSS section (uninitialized data) to zero
    la t0, __bss_start
    la t1, __bss_end
bss_clear_loop:
    bgeu t0, t1, bss_clear_done # If start >= end, we are done
    sw zero, 0(t0)              # Store 0 at address in t0
    addi t0, t0, 4              # Move to next word (4 bytes)
    j bss_clear_loop            # Repeat
bss_clear_done:

    # 3. Jump to the C main function
    jal ra, main

    # 4. If main() ever returns, hit our ebreak trap to halt the emulator
    ebreak
