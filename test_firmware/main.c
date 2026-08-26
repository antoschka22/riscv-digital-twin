#include <stdint.h>

volatile uint8_t* UART_TX = (volatile uint8_t*)0x10000000;
volatile uint32_t* MTIME_LOW = (volatile uint32_t*)0x0200BFF8; // The current hardware clock
volatile uint32_t* MTIMECMP_LOW = (volatile uint32_t*)0x02004000; // The alarm target
volatile uint32_t* MTIMECMP_HIGH = (volatile uint32_t*)0x02004004;

void print_str(const char* str) {
    while (*str) { *UART_TX = *str++; }
}

typedef struct {
    uint32_t sp;
} TCB;

TCB tasks[2];
volatile TCB* current_tcb; // Marked volatile so GCC doesn't optimize it away
volatile int task_idx = 0;

uint32_t stack0[256]; 
uint32_t stack1[256];

void task_a() {
    // Print a single character tightly so it's easily visible in the terminal
    while(1) { *UART_TX = 'A'; } 
}

void task_b() {
    while(1) { *UART_TX = 'B'; }
}

// 4. The OS Scheduler
void os_scheduler() {
    // Schedule the next tick 10,000 cycles from NOW
    *MTIMECMP_LOW = *MTIME_LOW + 10000; 

    // Flip between task 0 and task 1
    task_idx = (task_idx + 1) % 2;
    current_tcb = &tasks[task_idx]; 
}

void create_task(int index, uint32_t* stack_array, int stack_size, void (*task_entry)()) {
    uint32_t* sp = stack_array + stack_size; 
    sp = sp - 32; 
    sp[31] = (uint32_t)task_entry; 
    tasks[index].sp = (uint32_t)sp;
}

int main() {
    extern void os_trap_vector();
    __asm__ volatile ("csrw mtvec, %0" : : "r"(os_trap_vector));

    print_str("Booting Preemptive RTOS...\n");

    create_task(0, stack0, 256, task_a);
    create_task(1, stack1, 256, task_b);

    current_tcb = &tasks[0];

    // Set the initial timer 10,000 cycles into the future!
    *MTIMECMP_LOW = *MTIME_LOW + 10000;
    *MTIMECMP_HIGH = 0;

    // Enable Interrupts
    __asm__ volatile ("csrs mstatus, %0" : : "r"(1 << 3));
    __asm__ volatile ("csrs mie, %0" : : "r"(1 << 7));

    // Manual Jump to Task A
    __asm__ volatile (
        "lw sp, %0 \n"
        "lw t0, 124(sp) \n"
        "csrw mepc, t0 \n"
        "addi sp, sp, 128 \n"
        "mret \n"
        : : "m"(current_tcb->sp)
    );

    return 0;
}