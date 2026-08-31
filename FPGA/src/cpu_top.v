// cpu_top.v
module cpu_top(
    input  wire clk,
    input  wire rst,
    output reg  led_pin,       // Physical wire to the onboard LED
    output wire uart_tx_pin    // Physical wire to the USB-Serial bridge (Pin 69)
);

    // --- INTERNAL WIRES ---
    wire [31:0] pc_current;
    wire [31:0] instruction;
    
    // --- IMMEDIATE EXTRACTION LOGIC ---
    // I-Type (Load, ADDI)
    wire [31:0] imm_i = {{20{instruction[31]}}, instruction[31:20]};
    // S-Type (Store)
    wire [31:0] imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
    // B-Type (Branch)
    wire [31:0] imm_b = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};

    wire [6:0] opcode = instruction[6:0];
    reg  [31:0] imm;
    
    // Multiplexer to select the correct immediate format based on the instruction opcode
    always @(*) begin
        case(opcode)
            7'b0100011: imm = imm_s; // Store uses S-Type
            7'b1100011: imm = imm_b; // Branch uses B-Type
            default:    imm = imm_i; // Loads and ADDI use I-Type
        endcase
    end

    // --- CONTROL UNIT ---
    wire [3:0]  alu_ctrl;
    wire        reg_write;
    wire        alu_src;
    wire        mem_write;
    wire        result_src;
    wire        branch;

    control_unit ctrl (
        .instr(instruction),
        .alu_ctrl(alu_ctrl),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .branch(branch),
        .mem_write(mem_write),
        .result_src(result_src)
    );

    // --- ALU & REGISTERS ---
    wire [4:0]  rs1 = instruction[19:15];
    wire [4:0]  rs2 = instruction[24:20];
    wire [4:0]  rd  = instruction[11:7];
    
    wire [31:0] read_data1;
    wire [31:0] read_data2;
    wire [31:0] alu_result;
    wire        alu_zero;
    
    // Select between register data or immediate value for ALU input B
    wire [31:0] alu_input_b = alu_src ? imm : read_data2; 

    alu alu_inst (
        .a(read_data1),
        .b(alu_input_b),
        .alu_ctrl(alu_ctrl),
        .result(alu_result),
        .zero(alu_zero)
    );

    // --- BRANCH LOGIC & PC ---
    wire        take_branch = branch & alu_zero; 
    wire [31:0] pc_next = take_branch ? (pc_current + imm) : (pc_current + 32'd4);

    pc_register pc_reg (
        .clk(clk),
        .rst(rst),
        .pc_next(pc_next),
        .pc(pc_current)
    );

    instr_mem rom (
        .pc(pc_current),
        .instr(instruction)
    );

    // --- MMIO ADDRESS DECODING ---
    wire is_mmio_led    = (alu_result == 32'd100);
    wire is_mmio_uart   = (alu_result == 32'h10000000); 
    wire is_uart_status = (alu_result == 32'h10000004); // Status Register

    // --- DATA MEMORY (RAM) ---
    // Gate the memory write so MMIO operations don't corrupt standard RAM
    wire real_ram_write = mem_write & ~is_mmio_led & ~is_mmio_uart;
    wire [31:0] read_data_mem;

    data_mem ram (
        .clk(clk),
        .we(real_ram_write),      
        .addr(alu_result),        
        .write_data(read_data2),  
        .read_data(read_data_mem) 
    );

    // --- WRITE-BACK MULTIPLEXER ---
    wire uart_busy; // Declared here to be visible to the read multiplexer
    
    // 1. If CPU reads from 0x10000004, intercept and return the UART busy status
    wire [31:0] peripheral_read_data = is_uart_status ? {31'b0, uart_busy} : read_data_mem;
    
    // 2. Select between ALU math result or memory/peripheral data to save to register
    wire [31:0] write_back_data = result_src ? peripheral_read_data : alu_result;

    register_file reg_file (
        .clk(clk),
        .we(reg_write),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(write_back_data),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    // --- HARDWARE PERIPHERALS ---
    
    // 1. Physical LED Flip-Flop
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            led_pin <= 1'b0;
        end else if (mem_write && is_mmio_led) begin
            led_pin <= read_data2[0];
        end
    end

    // 2. Hardware UART Transmitter
    // Pulse tx_start high for exactly 1 clock cycle when CPU writes to UART address
    wire uart_tx_start = (mem_write && is_mmio_uart);

    uart_tx uart (
        .clk(clk),
        .rst(rst),
        .tx_start(uart_tx_start),
        .tx_data(read_data2[7:0]), // Send the lowest 8 bits (ASCII char)
        .tx_pin(uart_tx_pin),
        .tx_busy(uart_busy)
    );

endmodule