/**
 * @brief Core Local Interruptor (CLINT)
 *
 * Implements the hardware timer required for RISC-V machine-mode interrupts.
 * It maintains a 64-bit continuously incrementing counter (mtime) and compares 
 * it against a programmable threshold (mtimecmp) to generate timer interrupts 
 * used by the operating system for task scheduling
 */
module clint(
    input  wire        clk,          // System clock
    input  wire        rst,          // Synchronous active-high reset
    input  wire        we,           // Write enable signal from the CPU
    input  wire [31:0] addr,         // The memory-mapped address being accessed
    input  wire [31:0] write_data,   // 32-bit data to write (when we == 1)
    output reg  [31:0] read_data,    // 32-bit data requested by a Load instruction
    output wire        timer_int     // HIGH interrupt signal when mtime >= mtimecmp
);

    reg [63:0] mtime;
    reg [63:0] mtimecmp;

    // The physical interrupt trigger! Evaluated combinationallys
    assign timer_int = (mtime >= mtimecmp);

    // Synchronous Write and Counting Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset state: Zero the timer and set the compare threshold to maximum (infinity)
            mtime <= 64'b0;
            mtimecmp <= 64'hFFFFFFFFFFFFFFFF; // Default to max (never fire)
        end else begin
            // The clock ticks relentlessly every cycle
            mtime <= mtime + 1;

            // Handle memory-mapped writes from the C code/OS
            if (we) begin
                if (addr == 32'h02004000) mtimecmp[31:0]  <= write_data; // Write lower 32 bits of MTIMECMP
                if (addr == 32'h02004004) mtimecmp[63:32] <= write_data; // Write upper 32 bits of MTIMECMP
            end
        end
    end

    // Combinational Read Logic for Memory-Mapped I/O
    always @(*) begin
        case (addr)
            32'h0200BFF8: read_data = mtime[31:0];         // MTIME_LOW (Lower 32 bits)
            32'h0200BFFC: read_data = mtime[63:32];        // MTIME_HIGH (Upper 32 bits)
            32'h02004000: read_data = mtimecmp[31:0];      // MTIMECMP_LOW (Lower 32 bits)
            32'h02004004: read_data = mtimecmp[63:32];     // MTIMECMP_HIGH (Upper 32 bits)
            default:      read_data = 32'b0;               // Default to 0 for unmapped addresses
        endcase
    end

endmodule