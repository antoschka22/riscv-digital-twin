/**
 * @brief Emulator Entry Point and Host UI
 *
 * Initializes the CPU and Memory subsystems, loads the compiled firmware binary
 * and establishes a graphical window using SDL2 to serve as the emulator's display 
 * and input terminal
 */
#include "cpu.h"
#include <iostream>
#include <SDL2/SDL.h>

// Define the display resolution for the simulated VRAM
const int SCREEN_WIDTH = 320;
const int SCREEN_HEIGHT = 240;

int main() {
    // Initialize the system bus and load the compiled firmware
    Memory mem;
    mem.load_binary("../test_firmware/firmware.bin"); 
    
    // Initialize the CPU, hooking it up to our memory instance
    CPU cpu(&mem);

    // --- SDL2 UI Setup ---
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        std::cerr << "SDL could not initialize! Error: " << SDL_GetError() << std::endl;
        return 1;
    }

    // Create a 320x240 window and an accelerated renderer
    SDL_Window* window = SDL_CreateWindow("Anvil-V Emulator", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, SCREEN_WIDTH, SCREEN_HEIGHT, SDL_WINDOW_SHOWN);
    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    
    // Create a streaming texture mapped to the ABGR8888 pixel format to render VRAM directly
    SDL_Texture* texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ABGR8888, SDL_TEXTUREACCESS_STREAMING, SCREEN_WIDTH, SCREEN_HEIGHT);

    std::cout << "Starting CPU..." << std::endl;

    bool quit = false;
    SDL_Event e;
    
    // Batch execution: Run 100,000 CPU instructions per graphical frame
    // This allows the emulator to run at a realistic speed relative to the display refresh rate
    int cycles_per_frame = 100000; 

    while (!quit) {
        // --- Event Polling ---
        while (SDL_PollEvent(&e) != 0) {
            if (e.type == SDL_QUIT) {
                quit = true;
            }
            // Route WASD key presses directly into the simulated keyboard memory address
            else if (e.type == SDL_KEYDOWN) {
                switch(e.key.keysym.sym) {
                    case SDLK_w: mem.current_key = 'W'; break;
                    case SDLK_a: mem.current_key = 'A'; break;
                    case SDLK_s: mem.current_key = 'S'; break;
                    case SDLK_d: mem.current_key = 'D'; break;
                }
            }
            // Clear the memory address when the key is released
            else if (e.type == SDL_KEYUP) {
                mem.current_key = 0;
            }
        }
        
        // --- CPU Execution ---
        for(int i = 0; i < cycles_per_frame; i++) {
            if (!cpu.step()) {
                quit = true; // Halt execution if the CPU hits an ebreak instruction
                break;
            }
        }

        // --- Video Rendering ---
        // Copy the raw VRAM buffer from our simulated memory directly to the SDL texture
        SDL_UpdateTexture(texture, NULL, mem.vram.data(), SCREEN_WIDTH * 4);
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);
    }

    // Dump register state to the console for debugging upon exit
    cpu.dump_registers();
    
    // Cleanup SDL resources
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}