/**
 * @brief Control and Status Register (CSR) File
 *
 * This module manages the privileged architectural state of the RISC-V core.
 * It handles software reads/writes to CSRs and implements the hardware logic 
 * required to trigger and return from machine-mode traps (interrupts).
 */
module csr_file(
    input  wire        clk,
    input  wire        rst,
    
    // --- Software Interface ---
    // Used by system instructions to access CSR states
    input  wire [11:0] csr_addr,       // 12-bit address of the targeted CSR
    input  wire [31:0] csr_write_data, // Data to write into the CSR (typically from rs1)
    input  wire        csr_we,         // Write Enable flag from the control unit
    output reg  [31:0] csr_read_data,  // Data read out from the targeted CSR
    
    // --- Hardware Interface ---
    // Physical wires connected to other core components for trap execution
    input  wire        timer_int,      // Interrupt signal fed directly from the CLINT
    input  wire [31:0] current_pc,     // The current Program Counter (PC)
    input  wire        is_mret,        // HIGH when the CPU is executing an MRET instruction
    
    output wire [31:0] mtvec_out,      // The address to jump to when a trap fires
    output wire [31:0] mepc_out,       // The address to return to after trap completion
    output wire        trap_fire       // HIGH when a hardware trap is actively triggering
);

    // --- Physical 32-bit Registers ---
    reg [31:0] mstatus; // Machine Status (Bit 3 = MIE: Master Interrupt Enable)
    reg [31:0] mtvec;   // Machine Trap-Vector Base Address (Where to jump on trap)
    reg [31:0] mepc;    // Machine Exception Program Counter (Saved PC to return to)
    reg [31:0] mcause;  // Machine Cause (Reason for the trap)
    reg [31:0] mie;     // Machine Interrupt Enable (Bit 7 = MTIE: Timer Interrupt Enable)

    // The mip (Machine Interrupt Pending) register is combinational in our design.
    // Bit 7 (MTIP) directly reflects the physical state of the CLINT's timer_int wire.
    wire [31:0] mip = {24'b0, timer_int, 7'b0}; 

    // --- Hardware Trap Trigger ---
    // A trap fires if and only if: 
    // 1. Global interrupts are enabled (mstatus.MIE)
    // 2. Timer interrupts are enabled (mie.MTIE)
    // 3. A timer interrupt is currently pending (mip.MTIP)
    assign trap_fire = mstatus[3] & mie[7] & mip[7];

    // Continuously output the trap vectors for the PC multiplexer to use
    assign mtvec_out = mtvec;
    assign mepc_out  = mepc;

    // --- Synchronous Write Logic ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all privileged states to zero
            mstatus <= 32'b0;
            mtvec   <= 32'b0;
            mepc    <= 32'b0;
            mcause  <= 32'b0;
            mie     <= 32'b0;
        end else if (trap_fire) begin
            // HARDWARE TRAP EVENT: Context switch sequence
            mepc       <= current_pc;       // Save the interrupted instruction's address
            mcause     <= 32'h80000007;     // Set trap cause (7 = Machine Timer Interrupt)
            mstatus[3] <= 1'b0;             // Disable global interrupts to prevent nested traps
        end else if (is_mret) begin
            // TRAP RETURN EVENT (MRET instruction)
            mstatus[3] <= 1'b1;             // Re-enable global interrupts when resuming the task
        end else if (csr_we) begin
            // SOFTWARE WRITE EVENT: Instruction explicitly modifying a CSR (Simplified CSRRW)
            case (csr_addr)
                12'h300: mstatus <= csr_write_data;
                12'h304: mie     <= csr_write_data;
                12'h305: mtvec   <= csr_write_data;
                12'h341: mepc    <= csr_write_data;
                12'h342: mcause  <= csr_write_data;
            endcase
        end
    end

    // --- Combinational Read Logic ---
    // Multiplexes the requested register's data to the output port
    always @(*) begin
        case (csr_addr)
            12'h300: csr_read_data = mstatus;
            12'h304: csr_read_data = mie;
            12'h305: csr_read_data = mtvec;
            12'h341: csr_read_data = mepc;
            12'h342: csr_read_data = mcause;
            12'h344: csr_read_data = mip;
            default: csr_read_data = 32'b0; // Default to 0 for unimplemented CSRs
        endcase
    end
endmodule