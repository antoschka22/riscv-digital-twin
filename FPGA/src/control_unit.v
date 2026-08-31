module control_unit(
    input  wire [31:0] instr,
    output reg  [3:0]  alu_ctrl,
    output reg         reg_write,
    output reg         alu_src,
    output reg         branch,
    output reg         mem_write,  
    output reg         result_src 
    output reg         csr_we,
    output reg         is_mret
);

    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    always @(*) begin
        // Default signals
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        branch     = 1'b0;
        mem_write  = 1'b0;
        result_src = 1'b0;
        alu_ctrl   = 4'b0000;
        csr_we = 1'b0
        is_mret = 1'b0;

        case(opcode)
            7'b0110011: begin // R-Type (ADD, SUB)
                reg_write = 1'b1;
                if (funct3 == 3'b000 && funct7 == 7'b0000000) alu_ctrl = 4'b0000; // ADD
                if (funct3 == 3'b000 && funct7 == 7'b0100000) alu_ctrl = 4'b0001; // SUB
            end
            
            7'b0010011: begin // I-Type (ADDI)
                reg_write = 1'b1;
                alu_src   = 1'b1; 
                if (funct3 == 3'b000) alu_ctrl = 4'b0000; // ADD
            end

            7'b1100011: begin // B-Type (Branch)
                branch   = 1'b1;
                alu_ctrl = 4'b0001; // SUB for comparison
            end

            7'b0000011: begin // NEW: I-Type (Load Word)
                reg_write  = 1'b1;
                alu_src    = 1'b1;  // Add Immediate to rs1 to get memory address
                result_src = 1'b1;  // Route RAM data back to Register File
                alu_ctrl   = 4'b0000; // ADD
            end

            7'b0100011: begin // S-Type (Store Word)
                alu_src   = 1'b1;  // Add Immediate to rs1 to get memory address
                mem_write = 1'b1;  // Turn on RAM write
                alu_ctrl  = 4'b0000; // ADD
            end

            7'b1110011: begin // SYSTEM (CSRs and MRET)
                if (funct3 == 3'b000 && instr[31:20] == 12'h302) begin
                    is_mret = 1'b1; // This is the MRET instruction!
                end else begin
                    csr_we    = 1'b1; // This is a CSR write (e.g., CSRRW)
                    reg_write = 1'b1; // Save old CSR value to rd
                end
            end
        endcase
    end
endmodule