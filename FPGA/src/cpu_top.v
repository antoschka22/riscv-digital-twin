/**
 * @brief RISC-V System-on-Chip (SoC) Top-Level Module
 *
 * This is the master integration file that wires together the CPU core, 
 * memory subsystems, and hardware peripherals (UART, HDMI/VGA, Timer)
 * It manages the primary datapath, instruction routing, and Memory-Mapped 
 * I/O (MMIO) address decoding
 */
module cpu_top(
    input  wire clk_27m,       // 27 MHz external oscillator input
    input  wire rst,           // System reset signal]
    output wire uart_tx_pin,   // Physical wire to the USB-Serial bridge

    // HDMI/TMDS Physical Differential Pins
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire [2:0] tmds_d_p,
    output wire [2:0] tmds_d_n
);

    // --- CLOCK GENERATION ---
    // Instantiate the Phase-Locked Loop (PLL) to generate our system clocks
    wire clk_135m;  // High-speed clock for HDMI serialization
    wire clk_pixel; // 27 MHz base clock for the CPU and pixel timing

    gowin_rpll pll_inst (
        .clkin(clk_27m),
        .clkout(clk_135m),
        .clkoutp(clk_pixel)
    );

    // --- INSTRUCTION FETCH ---
    wire [31:0] pc_current;
    wire [31:0] instruction;
    
    // --- IMMEDIATE EXTRACTION LOGIC ---
    // Slices and sign-extends the raw 32-bit instruction into specific formats
    wire [31:0] imm_i = {{20{instruction[31]}}, instruction[31:20]}; // I-Type (Load, ADDI)
    wire [31:0] imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]}; // S-Type (Store)
    wire [31:0] imm_b = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0}; // B-Type (Branch)

    wire [6:0] opcode = instruction[6:0];
    reg  [31:0] imm;
    
    // Multiplexer to select the correct immediate format based on the instruction opcode
    always @(*) begin
        case(opcode)
            7'b0100011: imm = imm_s; // Store operations use S-Type
            7'b1100011: imm = imm_b; // Branch operations use B-Type
            default:    imm = imm_i; // Default to I-Type for Loads and ALU immediates
        endcase
    end

    // --- CONTROL UNIT ---
    // Translates the instruction into hardware control signals
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

    // --- MMIO ADDRESS DECODING ---
    // Detect if the CPU is accessing specific hardware peripheral memory spaces
    wire is_mmio_vram   = (alu_result >= 32'h04000000) && (alu_result < 32'h0404B000);
    wire is_mmio_led    = (alu_result == 32'd100);
    wire is_mmio_uart   = (alu_result == 32'h10000000); 
    wire is_uart_status = (alu_result == 32'h10000004); // UART Status Register
    wire is_mmio_clint  = (alu_result == 32'h0200BFF8) || (alu_result == 32'h0200BFFC) || 
                          (alu_result == 32'h02004000) || (alu_result == 32'h02004004);

    // --- THE GRAPHICS PIPELINE ---
    // Map the 32-bit CPU memory address to the internal VRAM buffer structure
    // Shift right 2 divides the address by 4 since the hardware maps 1 word = 1 pixel
    wire [16:0] cpu_vram_addr = alu_result[18:2]; 
    
    wire [9:0] vga_x;
    wire [9:0] vga_y;
    wire       active_video;
    wire [7:0] vga_pixel_color;

    // Scale 640x480 hardware output down to a 320x240 internal resolution
    wire [8:0] scaled_x = vga_x[9:1];
    wire [8:0] scaled_y = vga_y[9:1];
    wire [16:0] vga_vram_addr = (scaled_y * 17'd320) + scaled_x;

    vram video_memory (
        .clk(clk_pixel),
        .cpu_we(mem_write & is_mmio_vram),
        .cpu_addr(cpu_vram_addr),
        .cpu_data(read_data2[7:0]), // Use the lowest 8 bits for mapped color
        .vga_addr(vga_vram_addr),
        .vga_data(vga_pixel_color)
    );

    wire vga_hsync;
    wire vga_vsync;

    // Generates the strict timing signals required for the display
    vga_controller display_timing (
        .clk(clk_pixel),
        .rst(rst),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .x_coord(vga_x),
        .y_coord(vga_y),
        .active_vid(active_video)
    );

    // Expand the internal 8-bit color palette into standard 24-bit RGB for the HDMI encoder
    wire [23:0] rgb_24bit = {
        vga_pixel_color[7:5], 5'b0, // Red
        vga_pixel_color[4:2], 5'b0, // Green
        vga_pixel_color[1:0], 6'b0  // Blue
    };

    // Instantiate the DVI TX Core (HDMI Encoder)
    DVI_TX_Top hdmi_encoder (
        .I_rst_n(~rst),           
        .I_serial_clk(clk_135m),  
        .I_rgb_clk(clk_pixel),    
        .I_rgb_vs(vga_vsync),
        .I_rgb_hs(vga_hsync),
        .I_rgb_de(active_video),  // HIGH when in visible display area
        .I_rgb_r(rgb_24bit[23:16]),
        .I_rgb_g(rgb_24bit[15:8]),
        .I_rgb_b(rgb_24bit[7:0]),
        .O_tmds_clk_p(tmds_clk_p),
        .O_tmds_clk_n(tmds_clk_n),
        .O_tmds_data_p(tmds_d_p),
        .O_tmds_data_n(tmds_d_n)
    );

    // --- ALU & REGISTERS ---
    wire [4:0]  rs1 = instruction[19:15];
    wire [4:0]  rs2 = instruction[24:20];
    wire [4:0]  rd  = instruction[11:7];
    
    wire [31:0] read_data1;
    wire [31:0] read_data2;
    wire [31:0] alu_result;
    wire        alu_zero;
    
    // Select between register data or immediate value for ALU input B based on control signal
    wire [31:0] alu_input_b = alu_src ? imm : read_data2; 

    alu alu_inst (
        .a(read_data1),
        .b(alu_input_b),
        .alu_ctrl(alu_ctrl),
        .result(alu_result),
        .zero(alu_zero)
    );

    // --- CONTROL & STATUS REGISTERS (CSRs) ---
    wire [11:0] csr_addr = instruction[31:20];
    wire csr_we;
    wire is_mret;
    wire [31:0] csr_read_data;
    wire [31:0] mtvec_out;
    wire [31:0] mepc_out;
    wire        trap_fire;

    // The CSR file handles privileged architecture state and interrupts
    csr_file csrs (
        .clk(clk_pixel),
        .rst(rst),
        .csr_addr(csr_addr),
        .csr_write_data(read_data1),
        .csr_we(csr_we),
        .csr_read_data(csr_read_data),
        .timer_int(timer_interrupt), // Timer interrupt fed directly from the CLINT
        .current_pc(pc_current),
        .is_mret(is_mret),
        .mtvec_out(mtvec_out),
        .mepc_out(mepc_out),
        .trap_fire(trap_fire)
    );

    // --- PC, BRANCHING & ROM ---
    wire        take_branch = branch & alu_zero; 

    // Determine the next Program Counter execution address based on system priority:
    // 1: Hardware Trap -> Jump to OS Trap Handler (mtvec)
    // 2: MRET -> Return to the saved task (mepc)
    // 3: Branch -> Jump to calculated offset if condition met
    // 4: Default -> PC + 4 (next instruction)
    wire [31:0] pc_next = trap_fire   ? mtvec_out : 
                          is_mret     ? mepc_out  : 
                          take_branch ? (pc_current + imm) : 
                                        (pc_current + 32'd4);

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

    // --- DATA MEMORY (RAM) & PERIPHERALS ---
    
    // Gate memory writes so MMIO peripheral operations don't corrupt standard RAM
    wire real_ram_write = mem_write & ~is_mmio_led & ~is_mmio_uart;
    wire [31:0] read_data_mem;

    data_mem ram (
        .clk(clk_pixel),
        .we(real_ram_write),      
        .addr(alu_result),        
        .write_data(read_data2),  
        .read_data(read_data_mem) 
    );

    // Timer Interrupt Block (CLINT)
    wire [31:0] clint_read_data;
    wire        timer_interrupt;

    clint timer_block (
        .clk(clk_pixel),
        .rst(rst),
        .we(mem_write & is_mmio_clint), // Only write if targeting the CLINT
        .addr(alu_result),
        .write_data(read_data2),
        .read_data(clint_read_data),
        .timer_int(timer_interrupt)     // The critical timer interrupt signal
    );

    // Intercept UART and CLINT reads, routing them appropriately; otherwise default to RAM
    wire uart_busy;
    wire [31:0] peripheral_read_data = is_mmio_clint  ? clint_read_data :
                                       is_uart_status ? {31'b0, uart_busy} : 
                                       read_data_mem;

    // Select between ALU math result, CSR data, or Memory/Peripheral data to save to register file
    wire [31:0] write_back_data = csr_we ? csr_read_data : (result_src ? peripheral_read_data : alu_result);

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

    // --- HARDWARE COMMUNICATIONS ---
    // Pulse tx_start high for exactly 1 clock cycle when the CPU writes to the UART address
    wire uart_tx_start = (mem_write && is_mmio_uart);

    uart_tx uart (
        .clk(clk_pixel),
        .rst(rst),
        .tx_start(uart_tx_start),
        .tx_data(read_data2[7:0]), // Transmit the lowest 8 bits as an ASCII character
        .tx_pin(uart_tx_pin),
        .tx_busy(uart_busy)
    );

endmodule