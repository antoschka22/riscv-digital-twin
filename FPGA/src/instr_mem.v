module instr_mem(
    input  wire [31:0] pc,        // The current Program Counter
    output wire [31:0] instr      // The 32-bit instruction fetched
);

    // Create an array of 256 32-bit words (1 Kilobyte of ROM)
    reg [31:0] memory [0:255];

    // Load the compiled machine code when the hardware boots up
    initial begin
        $readmemh("program.hex", memory);
    end

    // RISC-V addresses are byte-addressed (0, 4, 8, 12).
    // Our array is word-addressed (0, 1, 2, 3).
    // We drop the lowest 2 bits of the PC (which is equivalent to dividing by 4)
    // to find the correct array index.
    assign instr = memory[pc[31:2]];

endmodule