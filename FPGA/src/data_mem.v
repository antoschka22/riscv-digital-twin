module data_mem(
    input  wire        clk,
    input  wire        we,          // 1 = Write, 0 = Read
    input  wire [31:0] addr,        // Memory address to read/write
    input  wire [31:0] write_data,  // Data to store
    output wire [31:0] read_data    // Data loaded from memory
);

    // Create 256 32-bit words (1 Kilobyte of RAM)
    reg [31:0] memory [0:255];

    // RISC-V addresses are byte-addressed (0, 4, 8, 12).
    // Our array is word-addressed (0, 1, 2, 3).
    // We drop the lowest 2 bits of the address.
    wire [29:0] word_addr = addr[31:2];

    // Read is combinational (instant)
    assign read_data = memory[word_addr];

    // Write is synchronous (happens on clock tick)
    always @(posedge clk) begin
        if (we) begin
            memory[word_addr] <= write_data;
        end
    end

endmodule