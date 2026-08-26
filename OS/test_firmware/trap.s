# trap.s
.section .text
.globl os_trap_vector
.align 4

os_trap_vector:
    # 1. Allocate space on the CURRENT task's stack
    addi sp, sp, -128

    # 2. Save registers
    sw ra, 0(sp)
    sw gp, 4(sp)
    sw tp, 8(sp)
    sw t0, 12(sp)
    sw t1, 16(sp)
    sw t2, 20(sp)
    sw s0, 24(sp)
    sw s1, 28(sp)
    sw a0, 32(sp)
    sw a1, 36(sp)
    sw a2, 40(sp)
    sw a3, 44(sp)
    sw a4, 48(sp)
    sw a5, 52(sp)
    sw a6, 56(sp)
    sw a7, 60(sp)
    sw s2, 64(sp)
    sw s3, 68(sp)
    sw s4, 72(sp)
    sw s5, 76(sp)
    sw s6, 80(sp)
    sw s7, 84(sp)
    sw s8, 88(sp)
    sw s9, 92(sp)
    sw s10, 96(sp)
    sw s11, 100(sp)
    sw t3, 104(sp)
    sw t4, 108(sp)
    sw t5, 112(sp)
    sw t6, 116(sp)

    # 3. Save the Program Counter (MEPC) into the stack frame (offset 124)
    csrr t0, mepc
    sw t0, 124(sp)

    # 4. Save the current Stack Pointer (sp) into the current_tcb
    la t0, current_tcb      # Load the memory address of the C pointer
    lw t1, 0(t0)            # Dereference to get the actual TCB address
    sw sp, 0(t1)            # Store SP into current_tcb->sp

    # 5. Call the C Scheduler (This will change the current_tcb pointer!)
    jal ra, os_scheduler

    # 6. Load the NEW Stack Pointer from the updated current_tcb
    la t0, current_tcb
    lw t1, 0(t0)
    lw sp, 0(t1)            # Load SP from current_tcb->sp

    # 7. Restore the Program Counter (MEPC)
    lw t0, 124(sp)
    csrw mepc, t0

    # 8. Restore registers from the NEW stack
    lw ra, 0(sp)
    lw gp, 4(sp)
    lw tp, 8(sp)
    lw t0, 12(sp)
    lw t1, 16(sp)
    lw t2, 20(sp)
    lw s0, 24(sp)
    lw s1, 28(sp)
    lw a0, 32(sp)
    lw a1, 36(sp)
    lw a2, 40(sp)
    lw a3, 44(sp)
    lw a4, 48(sp)
    lw a5, 52(sp)
    lw a6, 56(sp)
    lw a7, 60(sp)
    lw s2, 64(sp)
    lw s3, 68(sp)
    lw s4, 72(sp)
    lw s5, 76(sp)
    lw s6, 80(sp)
    lw s7, 84(sp)
    lw s8, 88(sp)
    lw s9, 92(sp)
    lw s10, 96(sp)
    lw s11, 100(sp)
    lw t3, 104(sp)
    lw t4, 108(sp)
    lw t5, 112(sp)
    lw t6, 116(sp)

    # 9. Free the stack space and jump back to the task!
    addi sp, sp, 128
    mret
