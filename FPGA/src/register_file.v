/**
 * @brief General Purpose Register File
 *
 * Implements the 32x32-bit register file required by the base RV32I architecture
 * Features dual asynchronous (combinational) read ports for immediate operand fetching
 * and a single synchronous write port. Ensures register x0 is always hardwired to zero
 */
module register_file (
    input  wire        clk,        // System clock
    input  wire        we,         // Write Enable flag (1 = Write to rd, 0 = Read only)
    input  wire [4:0]  rs1,        // 5-bit address for read port 1 (Source 1)
    input  wire [4:0]  rs2,        // 5-bit address for read port 2 (Source 2)
    input  wire [4:0]  rd,         // 5-bit address for write port (Destination)
    input  wire [31:0] write_data, // 32-bit data payload to write into register 'rd'
    output wire [31:0] read_data1, // 32-bit data output for 'rs1'
    output wire [31:0] read_data2  // 32-bit data output for 'rs2'
);

    // --- Register Array Allocation ---
    // Create an array of 32 registers, where each register is 32 bits wide
    reg [31:0] registers [0:31];

    // --- Combinational Read Logic ---
    // Read ports evaluate instantly.
    // RISC-V ISA specifies that register 0 (x0) must always evaluate to 0
    // The ternary operator forces a 0 output if rs1/rs2 requests address 0
    assign read_data1 = (rs1 == 5'b0) ? 32'b0 : registers[rs1];
    assign read_data2 = (rs2 == 5'b0) ? 32'b0 : registers[rs2];

    // --- Synchronous Write Logic ---
    // Writes are committed only on the rising edge of the system clock
    always @(posedge clk) begin
        // Only write if Write Enable is HIGH and the destination is NOT register 0
        // This prevents hardware from accidentally overwriting the hardwired zero register
        if (we && rd != 5'b0) begin
            registers[rd] <= write_data;
        end
    end

endmodule