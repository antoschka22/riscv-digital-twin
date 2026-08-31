module clint(
    input  wire        clk,
    input  wire        rst,
    input  wire        we,           // Write enable from the CPU
    input  wire [31:0] addr,         // The memory address being accessed
    input  wire [31:0] write_data,   // Data to write (if we == 1)
    output reg  [31:0] read_data,    // Data requested by a Load instruction
    output wire        timer_int     // HIGH when mtime >= mtimecmp
);

    reg [63:0] mtime;
    reg [63:0] mtimecmp;

    // The physical interrupt trigger!
    assign timer_int = (mtime >= mtimecmp);

    // Synchronous Write and Counting Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mtime <= 64'b0;
            mtimecmp <= 64'hFFFFFFFFFFFFFFFF; // Default to max (never fire)
        end else begin
            // The clock ticks relentlessly every cycle
            mtime <= mtime + 1;

            // Handle memory-mapped writes from the C code
            if (we) begin
                if (addr == 32'h02004000) mtimecmp[31:0]  <= write_data; // MTIMECMP_LOW
                if (addr == 32'h02004004) mtimecmp[63:32] <= write_data; // MTIMECMP_HIGH
            end
        end
    end

    // Combinational Read Logic
    always @(*) begin
        case (addr)
            32'h0200BFF8: read_data = mtime[31:0];         // MTIME_LOW
            32'h0200BFFC: read_data = mtime[63:32];        // MTIME_HIGH
            32'h02004000: read_data = mtimecmp[31:0];      // MTIMECMP_LOW
            32'h02004004: read_data = mtimecmp[63:32];     // MTIMECMP_HIGH
            default:      read_data = 32'b0;
        endcase
    end

endmodule