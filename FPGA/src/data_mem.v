/**
 * @brief Data Memory (RAM)
 *
 * Implements a simple 1 Kilobyte block of RAM. It features synchronous writes 
 * (updates on the clock edge) and asynchronous/combinational reads (data is 
 * immediately available). It translates standard RISC-V byte addresses into 
 * internal word addresses
 */
module data_mem(
    input  wire        clk,
    input  wire        we,          // Write Enable: 1 = Write to memory, 0 = Read only
    input  wire [31:0] addr,        // 32-bit byte-aligned memory address
    input  wire [31:0] write_data,  // 32-bit data word to store
    output wire [31:0] read_data    // 32-bit data word loaded from memory
);

    // --- Memory Array Allocation ---
    // Create an array of 256 words, where each word is 32 bits.
    // 256 words * 4 bytes/word = 1024 bytes (1 Kilobyte of RAM)
    reg [31:0] memory [0:255];

    // --- Address Translation ---
    // RISC-V issues byte-aligned addresses (e.g., 0x00, 0x04, 0x08, 0x0C)
    // Our Verilog array is word-aligned (indices 0, 1, 2, 3)
    // Shifting the address right by 2 bits divides it by 4, converting the 
    // byte address to the correct array index
    wire [29:0] word_addr = addr[31:2];

    // --- Combinational Read Logic ---
    // Memory reads are instant and do not wait for the clock cycle
    // This allows the CPU to fetch data within the same execution cycl
    assign read_data = memory[word_addr];

    // --- Synchronous Write Logic ---
    // Memory writes only commit on the rising edge of the clock when 'we' is HIGH
    always @(posedge clk) begin
        if (we) begin
            memory[word_addr] <= write_data;
        end
    end

endmodule