module csr_file(
    input  wire        clk,
    input  wire        rst,
    
    // Software Interface (Instructions writing to CSRs)
    input  wire [11:0] csr_addr,       // 12-bit address of the CSR
    input  wire [31:0] csr_write_data, // Data to write (from rs1)
    input  wire        csr_we,         // Write Enable
    output reg  [31:0] csr_read_data,  // Data read from CSR
    
    // Hardware Interface (The physical wires)
    input  wire        timer_int,      // Wire from the CLINT
    input  wire [31:0] current_pc,     // Current PC
    input  wire        is_mret,        // HIGH when executing MRET
    
    output wire [31:0] mtvec_out,      // Where to jump on a trap
    output wire [31:0] mepc_out,       // Where to return after a trap
    output wire        trap_fire       // HIGH when a trap is triggering!
);

    // The physical 32-bit registers
    reg [31:0] mstatus; // Bit 3 = MIE (Master Interrupt Enable)
    reg [31:0] mtvec;   // Trap handler address
    reg [31:0] mepc;    // Saved PC
    reg [31:0] mcause;  // Trap reason
    reg [31:0] mie;     // Bit 7 = MTIE (Timer Interrupt Enable)

    // The mip (Machine Interrupt Pending) register is combinational in our design.
    // It directly reflects the physical state of the timer_int wire.
    wire [31:0] mip = {24'b0, timer_int, 7'b0}; 

    // The Hardware Trap Trigger: Fire if MIE is 1, MTIE is 1, and MTIP is 1
    assign trap_fire = mstatus[3] & mie[7] & mip[7];

    assign mtvec_out = mtvec;
    assign mepc_out  = mepc;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mstatus <= 32'b0;
            mtvec   <= 32'b0;
            mepc    <= 32'b0;
            mcause  <= 32'b0;
            mie     <= 32'b0;
        end else if (trap_fire) begin
            // HARDWARE TRAP: Save PC, disable interrupts, set cause
            mepc       <= current_pc;
            mcause     <= 32'h80000007; // Cause 7: Machine Timer Interrupt
            mstatus[3] <= 1'b0;         // Clear MIE
        end else if (is_mret) begin
            // MRET: Re-enable interrupts when leaving the trap
            mstatus[3] <= 1'b1;         // Set MIE
        end else if (csr_we) begin
            // Software writing to CSRs (Simplified CSRRW)
            case (csr_addr)
                12'h300: mstatus <= csr_write_data;
                12'h304: mie     <= csr_write_data;
                12'h305: mtvec   <= csr_write_data;
                12'h341: mepc    <= csr_write_data;
                12'h342: mcause  <= csr_write_data;
            endcase
        end
    end

    always @(*) begin
        case (csr_addr)
            12'h300: csr_read_data = mstatus;
            12'h304: csr_read_data = mie;
            12'h305: csr_read_data = mtvec;
            12'h341: csr_read_data = mepc;
            12'h342: csr_read_data = mcause;
            12'h344: csr_read_data = mip;
            default: csr_read_data = 32'b0;
        endcase
    end
endmodule