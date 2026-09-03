/**
 * @brief RTOS Kernel and Application Tasks
 *
 * Implements a minimal cooperative and preemptive multitasking kernel. Includes 
 * memory-mapped I/O definitions, a graphical game task, a serial monitoring task, 
 * and the primary timer-interrupt-driven scheduler
 */
#include <stdint.h>

// --- Hardware Memory Maps ---
// Pointers mapped to specific memory addresses to interface with hardware peripherals
volatile uint32_t* VRAM = (volatile uint32_t*)0x04000000;          // Video RAM base address
volatile uint8_t* KEYBOARD = (volatile uint8_t*)0x03000000;        // Keyboard input register
volatile uint8_t* UART_TX = (volatile uint8_t*)0x10000000;         // Serial transmit register
volatile uint32_t* MTIME_LOW = (volatile uint32_t*)0x0200BFF8;     // Machine timer (lower 32-bits)
volatile uint32_t* MTIMECMP_LOW = (volatile uint32_t*)0x02004000;  // Timer compare (lower 32-bits)
volatile uint32_t* MTIMECMP_HIGH = (volatile uint32_t*)0x02004004; // Timer compare (upper 32-bits)

const int SCREEN_WIDTH = 320;
const int SCREEN_HEIGHT = 240;

// ARGB Color codes for the display
#define COLOR_BLACK 0xFF000000 
#define COLOR_RED   0xFF0000FF 

/**
 * @brief Transmits a null-terminated string over UART
 */
void print_str(const char* str) {
    while (*str) { *UART_TX = *str++; }
}

// --- RTOS Structures ---

/**
 * @struct TCB
 * @brief Task Control Block
 * Tracks the current state of a task. Currently only stores the Stack Pointer (sp)
 */
typedef struct {
    uint32_t sp;
} TCB;

TCB tasks[2];                  // Array holding state for 2 separate tasks
volatile TCB* current_tcb;     // Pointer to the currently executing task
volatile int task_idx = 0;     // Index of the currently executing task

// Allocate 1KB (256 * 4 bytes) stacks for each task
uint32_t stack_game[256]; 
uint32_t stack_monitor[256];

// --- Task 1: The Game ---

/**
 * @brief Draws a filled rectangle to the VRAM
 */
void draw_rect(int x, int y, int w, int h, uint32_t color) {
    for (int i = 0; i < h; i++) {
        for (int j = 0; j < w; j++) {
            // Check bounds to prevent writing outside VRAM memory space
            if (x + j >= 0 && x + j < SCREEN_WIDTH && y + i >= 0 && y + i < SCREEN_HEIGHT) {
                VRAM[((y + i) * SCREEN_WIDTH) + (x + j)] = color;
            }
        }
    }
}

/**
 * @brief Task 1 Entry Point: A simple playable game loop
 * Renders a red box that moves across a black screen based on WASD keyboard inputs
 */
void task_game() {
    int box_x = 160, box_y = 120;
    int speed = 3, box_size = 20;

    // Clear screen to black initially
    for (int i = 0; i < SCREEN_WIDTH * SCREEN_HEIGHT; i++) VRAM[i] = COLOR_BLACK; 

    while (1) {
        // Erase old box position
        draw_rect(box_x, box_y, box_size, box_size, COLOR_BLACK);

        // Read keyboard and update position with boundary checks
        uint8_t key = *KEYBOARD;
        if (key == 'W' && box_y > 0) box_y -= speed;
        if (key == 'S' && box_y < SCREEN_HEIGHT - box_size) box_y += speed;
        if (key == 'A' && box_x > 0) box_x -= speed;
        if (key == 'D' && box_x < SCREEN_WIDTH - box_size) box_x += speed;

        // Draw new box position
        draw_rect(box_x, box_y, box_size, box_size, COLOR_RED);
        
        // Artificial delay loop to control framerate
        for(volatile int d = 0; d < 5000; d++); 
    }
}

// --- Task 2: Background System Monitor ---

/**
 * @brief Task 2 Entry Point: UART heartbeat monitor
 * Continuously prints a heartbeat digit to the serial output to prove 
 * background multitasking is working
 */
void task_monitor() {
    int heartbeat = 0;
    while (1) {
        print_str("[OS] Background Task Heartbeat: ");
        *UART_TX = '0' + (heartbeat % 10);
        print_str("\n");
        
        heartbeat++;
        
        // Longer artificial delay for background process
        for(volatile int d = 0; d < 50000; d++); 
    }
}

// --- OS Kernel ---

/**
 * @brief Core scheduler invoked by the hardware timer interrupt
 * Resets the timer interval, clears the interrupt pending flag, and 
 * switches the active task index
 */
void os_scheduler() {
    // Schedule the next interrupt 10,000 cycles from now
    *MTIMECMP_LOW = *MTIME_LOW + 10000; 
    *MTIMECMP_HIGH = 0;

    // Clear the Machine Timer Interrupt Pending bit (MTIP) in the mip register
    __asm__ volatile ("csrc 0x344, %0" : : "r"(1 << 7));

    // Simple Round-Robin: Toggle between task 0 and task 1
    task_idx = (task_idx + 1) % 2;
    current_tcb = &tasks[task_idx]; 
}

/**
 * @brief Initializes a task's stack with a fake context so it can be "restored" on first boot
 * @param index Task ID (0 or 1)
 * @param stack_array Pointer to the bottom of the allocated stack array
 * @param stack_size Number of elements in the stack array
 * @param task_entry Function pointer to the task's starting logic
 */
void create_task(int index, uint32_t* stack_array, int stack_size, void (*task_entry)()) {
    uint32_t* sp = stack_array + stack_size; // Move to the top of the stack (descending)
    sp = sp - 32;                            // Make room for 32 general-purpose registers
    sp[31] = (uint32_t)task_entry;           // Store entry point at the PC (mepc) offset
    tasks[index].sp = (uint32_t)sp;          // Save the stack pointer to the TCB
}

/**
 * @brief Bootloader and Kernel Initialization.
 */
int main() {
    // Setup the trap vector for handling interrupts
    extern void os_trap_vector();
    __asm__ volatile ("csrw mtvec, %0" : : "r"(os_trap_vector));

    print_str("Booting Project Anvil-V RTOS...\n");

    // Initialize process stacks and TCBs
    create_task(0, stack_game, 256, task_game);
    create_task(1, stack_monitor, 256, task_monitor);

    // Set the initial active task
    current_tcb = &tasks[0];

    // Arm the hardware timer for the first context switch
    *MTIMECMP_LOW = *MTIME_LOW + 10000;
    *MTIMECMP_HIGH = 0; 
    
    // Enable global interrupts (MIE) and timer interrupts (MTIE)
    __asm__ volatile ("csrs mstatus, %0" : : "r"(1 << 3)); // Machine Interrupt Enable
    __asm__ volatile ("csrs mie, %0" : : "r"(1 << 7));     // Machine Timer Interrupt Enable

    // Context Restore: Load the first task and jump into it
    // load the SP, read the program counter from the stack, and use mret to start.
    __asm__ volatile (
        "lw sp, %0 \n"
        "lw t0, 124(sp) \n"          // Load the entry point function pointer
        "csrw mepc, t0 \n"           // Set Machine Exception Program Counter
        "addi sp, sp, 128 \n"        // Pop the "fake" trap frame
        "mret \n"                    // Return from exception into the task!
        : : "m"(current_tcb->sp)
    );

    return 0;
}