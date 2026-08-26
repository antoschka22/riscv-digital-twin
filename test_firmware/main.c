#include <stdint.h>

// --- Hardware Memory Maps ---
volatile uint32_t* VRAM = (volatile uint32_t*)0x04000000;
volatile uint8_t* KEYBOARD = (volatile uint8_t*)0x03000000;
volatile uint8_t* UART_TX = (volatile uint8_t*)0x10000000;
volatile uint32_t* MTIME_LOW = (volatile uint32_t*)0x0200BFF8;
volatile uint32_t* MTIMECMP_LOW = (volatile uint32_t*)0x02004000;

const int SCREEN_WIDTH = 320;
const int SCREEN_HEIGHT = 240;

#define COLOR_BLACK 0xFF000000 
#define COLOR_RED   0xFF0000FF 

void print_str(const char* str) {
    while (*str) { *UART_TX = *str++; }
}

// --- RTOS Structures ---
typedef struct {
    uint32_t sp;
} TCB;

TCB tasks[2];
volatile TCB* current_tcb;
volatile int task_idx = 0;

uint32_t stack_game[256]; 
uint32_t stack_monitor[256];

// --- Task 1: The Game ---
void draw_rect(int x, int y, int w, int h, uint32_t color) {
    for (int i = 0; i < h; i++) {
        for (int j = 0; j < w; j++) {
            if (x + j >= 0 && x + j < SCREEN_WIDTH && y + i >= 0 && y + i < SCREEN_HEIGHT) {
                VRAM[((y + i) * SCREEN_WIDTH) + (x + j)] = color;
            }
        }
    }
}

void task_game() {
    int box_x = 160, box_y = 120;
    int speed = 3, box_size = 20;

    for (int i = 0; i < SCREEN_WIDTH * SCREEN_HEIGHT; i++) VRAM[i] = COLOR_BLACK; 

    while (1) {
        draw_rect(box_x, box_y, box_size, box_size, COLOR_BLACK);

        uint8_t key = *KEYBOARD;
        if (key == 'W' && box_y > 0) box_y -= speed;
        if (key == 'S' && box_y < SCREEN_HEIGHT - box_size) box_y += speed;
        if (key == 'A' && box_x > 0) box_x -= speed;
        if (key == 'D' && box_x < SCREEN_WIDTH - box_size) box_x += speed;

        draw_rect(box_x, box_y, box_size, box_size, COLOR_RED);
        
        for(volatile int d = 0; d < 5000; d++); 
    }
}

// --- Task 2: Background System Monitor ---
void task_monitor() {
    int heartbeat = 0;
    while (1) {
        print_str("[OS] Background Task Heartbeat: ");
        // Print a simple ASCII ticker
        *UART_TX = '0' + (heartbeat % 10);
        print_str("\n");
        
        heartbeat++;
        
        // Delay so it doesn't flood the terminal instantly
        for(volatile int d = 0; d < 50000; d++); 
    }
}

// --- OS Kernel ---
void os_scheduler() {
    // Give each task 10,000 cycles to run before swapping
    *MTIMECMP_LOW = *MTIME_LOW + 10000; 

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

    print_str("Booting Project Anvil-V RTOS...\n");

    create_task(0, stack_game, 256, task_game);
    create_task(1, stack_monitor, 256, task_monitor);

    current_tcb = &tasks[0];

    *MTIMECMP_LOW = *MTIME_LOW + 10000;
    // Enable timer interrupts
    __asm__ volatile ("csrs mstatus, %0" : : "r"(1 << 3));
    __asm__ volatile ("csrs mie, %0" : : "r"(1 << 7));

    // Jump to Task 0 (Game)
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