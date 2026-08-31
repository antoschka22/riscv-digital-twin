module vram (
    input  wire        clk,
    
    // Port A: For the CPU (Write Only)
    input  wire        cpu_we,
    input  wire [16:0] cpu_addr,  // 320 * 240 = 76,800 pixels (requires 17 bits)
    input  wire [7:0]  cpu_data,  // 8-bit color (e.g., RRRGGGBB)
    
    // Port B: For the VGA Controller (Read Only)
    input  wire [16:0] vga_addr,
    output reg  [7:0]  vga_data
);

    // Create physical Block RAM for 76,800 pixels
    reg [7:0] memory [0:76799];

    // Dual-port behavior: Both operations happen simultaneously on the clock edge
    always @(posedge clk) begin
        if (cpu_we) begin
            memory[cpu_addr] <= cpu_data;
        end
        // The VGA controller constantly reads whatever address it is pointing to
        vga_data <= memory[vga_addr];
    end

endmodule