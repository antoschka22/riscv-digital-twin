module alu (
    input  wire [31:0] a,          // 32-bit input A (usually from rs1)
    input  wire [31:0] b,          // 32-bit input B (usually from rs2 or immediate)
    input  wire [3:0]  alu_ctrl,   // 4-bit control signal telling the ALU what to do
    output reg  [31:0] result,     // 32-bit output result
    output wire        zero        // High if result is 0 (useful for branches)
);

    // The zero flag is purely combinational based on the result
    assign zero = (result == 32'b0);

    // It creates physical logic gates (AND, OR, Adders, Multiplexers).
    always @(*) begin
        case (alu_ctrl)
            4'b0000: result = a + b;                                  // ADD
            4'b0001: result = a - b;                                  // SUB
            4'b0010: result = a << b[4:0];                            // SLL (Shift Left Logical)
            4'b0011: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // SLT (Signed Less Than)
            4'b0100: result = (a < b) ? 32'd1 : 32'd0;                // SLTU (Unsigned Less Than)
            4'b0101: result = a ^ b;                                  // XOR
            4'b0110: result = a >> b[4:0];                            // SRL (Shift Right Logical)
            4'b0111: result = $signed(a) >>> b[4:0];                  // SRA (Shift Right Arithmetic)
            4'b1000: result = a | b;                                  // OR
            4'b1001: result = a & b;                                  // AND
            default: result = 32'b0;                                  // Default to 0
        endcase
    end

endmodule