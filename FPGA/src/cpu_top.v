module cpu_top(
    input  wire clk_27m,
    input  wire rst,
    output wire uart_tx_pin    // Physical wire to the USB-Serial bridge (Pin 69)

    // HDMI Physical Pins
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire [2:0] tmds_d_p,
    output wire [2:0] tmds_d_n
);

    // Instantiate the PLL to get our two clocks
    wire clk_135m;
    wire clk_pixel; // 27 MHz

    gowin_rpll pll_inst (
        .clkin(clk_27m),
        .clkout(clk_135m),
        .clkoutp(clk_pixel)
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

    // --- MMIO Address Decoding ---
    wire is_mmio_vram   = (alu_result >= 32'h04000000) && (alu_result < 32'h0404B000);

    // --- THE GRAPHICS PIPELINE ---
    // Calculate the VRAM address for the CPU
    // Address 0x04000000 becomes VRAM index 0. We divide by 4 (shift right 2) because
    // the CPU writes 32-bit words, but our VRAM is a flat byte array in software.
    // In our hardware, we just map 1 word = 1 pixel for simplicity.
    wire [16:0] cpu_vram_addr = alu_result[18:2]; 
    
    wire [9:0] vga_x;
    wire [9:0] vga_y;
    wire       active_video;
    wire [7:0] vga_pixel_color;

    // Scale 640x480 down to 320x240
    wire [8:0] scaled_x = vga_x[9:1];
    wire [8:0] scaled_y = vga_y[9:1];
    
    // Calculate the VRAM read address: (Y * 320) + X
    wire [16:0] vga_vram_addr = (scaled_y * 17'd320) + scaled_x;

    vram video_memory (
        .clk(clk_pixel),
        .cpu_we(mem_write & is_mmio_vram),
        .cpu_addr(cpu_vram_addr),
        .cpu_data(read_data2[7:0]), // Just use the lowest 8 bits for color
        .vga_addr(vga_vram_addr),
        .vga_data(vga_pixel_color)
    );

    wire vga_hsync;
    wire vga_vsync;

    vga_controller display_timing (
        .clk(clk_pixel),
        .rst(rst),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .x_coord(vga_x),
        .y_coord(vga_y),
        .active_vid(active_video)
    );

    // --- Physical Video Output Pins ---
    wire [7:0] final_rgb = active_video ? vga_pixel_color : 8'h00;

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

    // Extract the CSR address from the instruction
    wire [11:0] csr_addr = instruction[31:20];
    
    // Control Unit wires
    wire csr_we;
    wire is_mret;
    
    // CSR File Output Wires
    wire [31:0] csr_read_data;
    wire [31:0] mtvec_out;
    wire [31:0] mepc_out;
    wire        trap_fire;

    csr_file csrs (
        .clk(clk_pixel),
        .rst(rst),
        .csr_addr(csr_addr),
        .csr_write_data(read_data1), // rs1 holds the data we write to the CSR
        .csr_we(csr_we),
        .csr_read_data(csr_read_data),
        .timer_int(timer_interrupt), // Fed directly from the CLINT!
        .current_pc(pc_current),
        .is_mret(is_mret),
        .mtvec_out(mtvec_out),
        .mepc_out(mepc_out),
        .trap_fire(trap_fire)
    );

    // If the control unit says csr_we is high, save the CSR value into the destination register (rd)
    wire [31:0] write_back_data = csr_we ? csr_read_data : (result_src ? peripheral_read_data : alu_result);

    // This determines exactly what address the CPU executes next.
    // Priority 1: Hardware Trap (Jump to OS Trap Handler)
    // Priority 2: MRET (Return to the saved task)
    // Priority 3: Branch (If a condition was met)
    // Default:    PC + 4
    
    wire [31:0] pc_next = trap_fire   ? mtvec_out : 
                          is_mret     ? mepc_out  : 
                          take_branch ? (pc_current + imm) : 
                                        (pc_current + 32'd4);

    // --- BRANCH LOGIC & PC ---
    wire        take_branch = branch & alu_zero; 
    wire [31:0] pc_next = take_branch ? (pc_current + imm) : (pc_current + 32'd4);

    pc_register pc_reg (
        .clk(clk_pixel),
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

    // Masking to check if the address falls in the CLINT range
    wire is_mmio_clint  = (alu_result == 32'h0200BFF8) || 
                          (alu_result == 32'h0200BFFC) || 
                          (alu_result == 32'h02004000) || 
                          (alu_result == 32'h02004004);

    // --- DATA MEMORY (RAM) ---
    // Gate the memory write so MMIO operations don't corrupt standard RAM
    wire real_ram_write = mem_write & ~is_mmio_led & ~is_mmio_uart;
    wire [31:0] read_data_mem;

    data_mem ram (
        .clk(clk_pixel),
        .we(real_ram_write),      
        .addr(alu_result),        
        .write_data(read_data2),  
        .read_data(read_data_mem) 
    );

    // CLINT Instantiation ---
    wire [31:0] clint_read_data;
    wire        timer_interrupt;

    clint timer_block (
        .clk(clk_pixel),
        .rst(rst),
        .we(mem_write & is_mmio_clint), // Only write if addressing the CLINT
        .addr(alu_result),
        .write_data(read_data2),
        .read_data(clint_read_data),
        .timer_int(timer_interrupt)     // The critical interrupt signal!
    );

    // --- MMIO Read Multiplexer ---
    // If the CPU is reading from the CLINT, route the CLINT data.
    // If reading from UART Status, route the UART busy signal.
    // Otherwise, route normal RAM.
    wire [31:0] peripheral_read_data;
    assign peripheral_read_data = is_mmio_clint  ? clint_read_data :
                                  is_uart_status ? {31'b0, uart_busy} : 
                                  read_data_mem;

    wire [31:0] write_back_data = result_src ? peripheral_read_data : alu_result;

    // --- WRITE-BACK MULTIPLEXER ---
    wire uart_busy; // Declared here to be visible to the read multiplexer
    
    // If CPU reads from 0x10000004, intercept and return the UART busy status
    wire [31:0] peripheral_read_data = is_uart_status ? {31'b0, uart_busy} : read_data_mem;
    
    // Select between ALU math result or memory/peripheral data to save to register
    wire [31:0] write_back_data = result_src ? peripheral_read_data : alu_result;

    register_file reg_file (
        .clk(clk_pixel),
        .we(reg_write),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(write_back_data),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    // --- HARDWARE PERIPHERALS ---
    // Physical LED Flip-Flop
    always @(posedge clk_pixel or posedge rst) begin
        if (rst) begin
            led_pin <= 1'b0;
        end else if (mem_write && is_mmio_led) begin
            led_pin <= read_data2[0];
        end
    end

    // Pulse tx_start high for exactly 1 clock cycle when CPU writes to UART address
    wire uart_tx_start = (mem_write && is_mmio_uart);

    uart_tx uart (
        .clk(clk_pixel),
        .rst(rst),
        .tx_start(uart_tx_start),
        .tx_data(read_data2[7:0]), // Send the lowest 8 bits (ASCII char)
        .tx_pin(uart_tx_pin),
        .tx_busy(uart_busy)
    );

    // Expand the 8-bit color palette into 24-bit RGB for HDMI
    // For a simple 8-bit palette (RRRGGGBB), we stretch the bits to fill 24 bits
    wire [23:0] rgb_24bit = {
        vga_pixel_color[7:5], 5'b0, // Red
        vga_pixel_color[4:2], 5'b0, // Green
        vga_pixel_color[1:0], 6'b0  // Blue
    };

    // Instantiate the DVI TX Core
    DVI_TX_Top hdmi_encoder (
        .I_rst_n(~rst),           // Active-low reset
        .I_serial_clk(clk_135m),  // 135 MHz serial clock
        .I_rgb_clk(clk_pixel),    // 27 MHz pixel clock
        .I_rgb_vs(vga_vsync),
        .I_rgb_hs(vga_hsync),
        .I_rgb_de(active_video),  // Data Enable (HIGH when in visible area)
        .I_rgb_r(rgb_24bit[23:16]),
        .I_rgb_g(rgb_24bit[15:8]),
        .I_rgb_b(rgb_24bit[7:0]),
        
        // Physical TMDS Outputs
        .O_tmds_clk_p(tmds_clk_p),
        .O_tmds_clk_n(tmds_clk_n),
        .O_tmds_data_p(tmds_d_p),
        .O_tmds_data_n(tmds_d_n)
    );

endmodule