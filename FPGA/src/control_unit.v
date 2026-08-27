module control_unit(
    input  wire [31:0] instr,       // The 32-bit instruction
    output reg  [3:0]  alu_ctrl,    // Tells the ALU which math operation to run
    output reg         reg_write,   // 1 if we should save the result to a register
    output reg         alu_src      // 0 = use rs2 for ALU input B, 1 = use immediate
);

    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    // Evaluate instantly when the instruction wire changes
    always @(*) begin
        // Default signals to prevent unwanted writes
        reg_write = 1'b0;
        alu_src   = 1'b0;
        alu_ctrl  = 4'b0000;

        case(opcode)
            7'b0110011: begin // R-Type (e.g., ADD, SUB)
                reg_write = 1'b1;
                alu_src   = 1'b0; // Use register rs2
                if (funct3 == 3'b000 && funct7 == 7'b0000000) alu_ctrl = 4'b0000; // ADD
                if (funct3 == 3'b000 && funct7 == 7'b0100000) alu_ctrl = 4'b0001; // SUB
            end
            
            7'b0010011: begin // I-Type (e.g., ADDI)
                reg_write = 1'b1;
                alu_src   = 1'b1; // Use the immediate value instead of rs2
                if (funct3 == 3'b000) alu_ctrl = 4'b0000; // ADDI uses the ADD operation
            end
        endcase
    end

endmodule