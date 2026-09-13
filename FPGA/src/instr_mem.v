/**
 * @brief Instruction Memory (ROM)
 *
 * This module stores the compiled machine code for the RISC-V processor.
 * It asynchronously fetches and outputs the 32-bit instruction located at 
 * the current Program Counter (PC) address
 */
module instr_mem(
    input  wire [31:0] pc,        // The current Program Counter (byte-aligned address)
    output wire [31:0] instr      // The 32-bit instruction fetched from memory
);

    // --- Memory Array Allocation ---
    // Create an array of 256 words, where each word is 32 bits.
    // 256 words * 4 bytes/word = 1024 bytes (1 Kilobyte of Instruction ROM)
    reg [31:0] memory [0:255];

    // --- Firmware Initialization ---
    // Load the compiled machine code (hexadecimal format) into the ROM array
    // automatically when the hardware is synthesized or the simulator boots up
    initial begin
        $readmemh("program.hex", memory);
    end

    // --- Address Translation & Fetch ---
    // RISC-V issues byte-aligned addresses (e.g., 0x00, 0x04, 0x08, 0x0C)
    // Our Verilog array is word-aligned (indices 0, 1, 2, 3)
    // Dropping the lowest 2 bits (pc[31:2]) efficiently divides the address by 4,
    // converting the byte address into the correct word index for the array lookup
    assign instr = memory[pc[31:2]];

endmodule