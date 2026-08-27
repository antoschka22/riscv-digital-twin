module register_file (
    input  wire        clk,        // The main CPU clock signal
    input  wire        we,         // Write Enable flag (1 = write, 0 = read only)
    input  wire [4:0]  rs1,        // 5-bit address for read port 1
    input  wire [4:0]  rs2,        // 5-bit address for read port 2
    input  wire [4:0]  rd,         // 5-bit address for write port
    input  wire [31:0] write_data, // 32-bit data to write into 'rd'
    output wire [31:0] read_data1, // 32-bit data output for 'rs1'
    output wire [31:0] read_data2  // 32-bit data output for 'rs2'
);

    // Create an array of 32 registers, each 32 bits wide.
    reg [31:0] registers [0:31];

    // Read ports are combinational (instantaneous).
    // Note: Register 0 is hardwired to 0 in RISC-V!
    assign read_data1 = (rs1 == 5'b0) ? 32'b0 : registers[rs1];
    assign read_data2 = (rs2 == 5'b0) ? 32'b0 : registers[rs2];

    // Writes only happen on the rising edge of the clock (when voltage goes from 0 to 1).
    always @(posedge clk) begin
        if (we && rd != 5'b0) begin
            registers[rd] <= write_data;
        end
    end

endmodule