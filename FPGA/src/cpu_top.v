module cpu_top(
    input wire clk,
    input wire [31:0] instruction // Temporarily fed from the outside for testing
);
    // 1. Slice the instruction to find the register addresses
    wire [4:0] rs1 = instruction[19:15];
    wire [4:0] rs2 = instruction[24:20];
    wire [4:0] rd  = instruction[11:7];

    // 2. Extract and Sign-Extend the 12-bit Immediate (for ADDI)
    // This replicates the 31st bit 20 times to fill the upper 32 bits
    wire [31:0] imm_i = {{20{instruction[31]}}, instruction[31:20]};

    // 3. Internal Wires (The cables connecting the modules)
    wire [3:0]  alu_ctrl;
    wire        reg_write;
    wire        alu_src;
    wire [31:0] read_data1;
    wire [31:0] read_data2;
    wire [31:0] alu_result;
    wire        alu_zero;

    // 4. The Multiplexer (MUX) for ALU Input B
    // If alu_src is 1, use imm_i. If 0, use read_data2.
    wire [31:0] alu_input_b = alu_src ? imm_i : read_data2; 

    // --- INSTANTIATE AND WIRE THE MODULES ---

    control_unit ctrl (
        .instr(instruction),
        .alu_ctrl(alu_ctrl),
        .reg_write(reg_write),
        .alu_src(alu_src)
    );

    register_file reg_file (
        .clk(clk),
        .we(reg_write),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(alu_result), // The ALU result loops back to the write port!
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    alu alu_inst (
        .a(read_data1),
        .b(alu_input_b), // Fed by our MUX
        .alu_ctrl(alu_ctrl),
        .result(alu_result),
        .zero(alu_zero)
    );

endmodule