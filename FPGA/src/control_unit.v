/**
 * @brief Main CPU Control Unit
 *
 * Decodes the 32-bit RISC-V instruction and generates the appropriate control 
 * signals for the ALU, Register File, Data Memory, and CSR subsystems. It 
 * determines instruction types (R-type, I-type, B-type, S-type) and sets up 
 * the datapath multiplexers accordingly
 */
module control_unit(
    input  wire [31:0] instr,      // Raw 32-bit instruction fetched from memory
    output reg  [3:0]  alu_ctrl,   // Determines the specific ALU operation
    output reg         reg_write,  // Write enable for the General Purpose Register file
    output reg         alu_src,    // Selects ALU operand B (0: Register, 1: Immediate)
    output reg         branch,     // Indicates a branch instruction
    output reg         mem_write,  // Write enable for Data Memory
    output reg         result_src, // Selects Register writeback source (0: ALU, 1: Memory)
    output reg         csr_we,     // Write enable for Control and Status Registers
    output reg         is_mret     // Signals a return from a machine-mode trap (MRET)
);

    // Extract standard RISC-V instruction fields
    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    // Combinational decoding logic
    always @(*) begin
        // Default signals to prevent latch generation and unintended side effects
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        branch     = 1'b0;
        mem_write  = 1'b0;
        result_src = 1'b0;
        alu_ctrl   = 4'b0000;
        csr_we     = 1'b0;
        is_mret    = 1'b0;

        // Decode based on the 7-bit primary opcode
        case(opcode)
            7'b0110011: begin // R-Type (Register-Register Operations like ADD, SUB)
                reg_write = 1'b1;
                if (funct3 == 3'b000 && funct7 == 7'b0000000) alu_ctrl = 4'b0000; // ADD
                if (funct3 == 3'b000 && funct7 == 7'b0100000) alu_ctrl = 4'b0001; // SUB
            end
            
            7'b0010011: begin // I-Type (Immediate ALU Operations like ADDI)
                reg_write = 1'b1;
                alu_src   = 1'b1; // Route the immediate value to the ALU instead of rs2
                if (funct3 == 3'b000) alu_ctrl = 4'b0000; // ADD
            end

            7'b1100011: begin // B-Type (Branch Operations)
                branch   = 1'b1;
                alu_ctrl = 4'b0001; // SUB for comparison (ALU checks if rs1 - rs2 == 0)
            end

            7'b0000011: begin // I-Type (Load Word Operations)
                reg_write  = 1'b1;
                alu_src    = 1'b1;  // Add Immediate to rs1 to calculate the memory address
                result_src = 1'b1;  // Route RAM output data back to the Register File
                alu_ctrl   = 4'b0000; // ADD (Base address + offset)
            end

            7'b0100011: begin // S-Type (Store Word Operations)
                alu_src   = 1'b1;  // Add Immediate to rs1 to calculate the memory address
                mem_write = 1'b1;  // Turn on RAM write enable
                alu_ctrl  = 4'b0000; // ADD (Base address + offset)
            end

            7'b1110011: begin // SYSTEM (CSR Operations and Environment Returns)
                // Check if this is an MRET instruction (Return from trap)
                if (funct3 == 3'b000 && instr[31:20] == 12'h302) begin
                    is_mret = 1'b1; 
                end else begin
                    // Otherwise, it's a standard CSR Read/Write instruction
                    csr_we    = 1'b1; // Enable CSR write (e.g., CSRRW)
                    reg_write = 1'b1; // Save the old CSR value back into destination register (rd)
                end
            end
        endcase
    end
endmodule