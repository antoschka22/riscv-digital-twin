/**
 * @brief Arithmetic Logic Unit (ALU)
 *
 * This module performs the core arithmetic (addition, subtraction, comparison) 
 * and logical (AND, OR, XOR, shifts) operations required by the RISC-V ISA.
 * It is purely combinational, meaning the result updates immediately as the 
 * inputs or control signals change
 */
module alu (
    input  wire [31:0] a,          // 32-bit operand A (typically rs1)
    input  wire [31:0] b,          // 32-bit operand B (typically rs2 or sign-extended immediate)
    input  wire [3:0]  alu_ctrl,   // 4-bit operational control signal from the Control Unit
    output reg  [31:0] result,     // 32-bit computation result
    output wire        zero        // High (1) if the result is exactly 0; used by the branch unit
);

    // The zero flag is purely combinational based on the result
    assign zero = (result == 32'b0);

    // Main ALU execution logic. Synthesizes into physical logic gates and multiplexers.
    always @(*) begin
        case (alu_ctrl)
            4'b0000: result = a + b;                                        // ADD: Addition
            4'b0001: result = a - b;                                        // SUB: Subtraction
            4'b0010: result = a << b[4:0];                                  // SLL: Shift Left Logical (bottom 5 bits of b define shift amount)
            4'b0011: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;    // SLT: Set Less Than (Signed comparison)
            4'b0100: result = (a < b) ? 32'd1 : 32'd0;                      // SLTU: Set Less Than Unsigned (Unsigned comparison)
            4'b0101: result = a ^ b;                                        // XOR: Bitwise Exclusive OR
            4'b0110: result = a >> b[4:0];                                  // SRL: Shift Right Logical (fills with 0s)
            4'b0111: result = $signed(a) >>> b[4:0];                        // SRA: Shift Right Arithmetic (preserves sign bit)
            4'b1000: result = a | b;                                        // OR: Bitwise OR
            4'b1001: result = a & b;                                        // AND: Bitwise AND
            default: result = 32'b0;                                        // Default fallback to prevent latches
        endcase
    end

endmodule