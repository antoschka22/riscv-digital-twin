#include "cpu.h"
#include <iostream>
#include <SDL2/SDL.h>

const int SCREEN_WIDTH = 320;
const int SCREEN_HEIGHT = 240;

int main() {
    Memory mem;
    mem.load_binary("../test_firmware/firmware.bin"); 
    CPU cpu(&mem);

    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        std::cerr << "SDL could not initialize! Error: " << SDL_GetError() << std::endl;
        return 1;
    }

    SDL_Window* window = SDL_CreateWindow("Anvil-V Emulator", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, SCREEN_WIDTH, SCREEN_HEIGHT, SDL_WINDOW_SHOWN);
    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    
    SDL_Texture* texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ABGR8888, SDL_TEXTUREACCESS_STREAMING, SCREEN_WIDTH, SCREEN_HEIGHT);

    std::cout << "Starting CPU..." << std::endl;

    bool quit = false;
    SDL_Event e;
    
    int cycles_per_frame = 100000; // How many instructions to run before updating the screen

    while (!quit) {
        while (SDL_PollEvent(&e) != 0) {
            if (e.type == SDL_QUIT) {
                quit = true;
            }
            // Capture key presses
            else if (e.type == SDL_KEYDOWN) {
                switch(e.key.keysym.sym) {
                    case SDLK_w: mem.current_key = 'W'; break;
                    case SDLK_a: mem.current_key = 'A'; break;
                    case SDLK_s: mem.current_key = 'S'; break;
                    case SDLK_d: mem.current_key = 'D'; break;
                }
            }
            // Clear the key when released
            else if (e.type == SDL_KEYUP) {
                mem.current_key = 0;
            }
        }
        
        // Run the CPU for a batch of cycles
        for(int i = 0; i < cycles_per_frame; i++) {
            if (!cpu.step()) {
                quit = true; // Halt if ebreak is hit
                break;
            }
        }

        SDL_UpdateTexture(texture, NULL, mem.vram.data(), SCREEN_WIDTH * 4);
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);
    }

    cpu.dump_registers();
    
    // Cleanup SDL
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}