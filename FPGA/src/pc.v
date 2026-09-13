/**
 * @brief Program Counter (PC) Register
 *
 * This module holds the memory address of the currently executing instruction
 * It synchronously updates to the next address (calculated by branch logic, traps, 
 * or standard increments) on every positive clock edge. It also features an 
 * asynchronous reset to immediately halt and restart execution
 */
module pc_register(
    input  wire        clk,       // System clock
    input  wire        rst,       // Asynchronous active-high reset signal
    input  wire [31:0] pc_next,   // The calculated next instruction address
    output reg  [31:0] pc         // The current execution address
);

    // --- State Update Logic ---
    // This sequential block triggers on the rising edge of the clock OR 
    // the rising edge of the reset signal
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Upon system reset, force the Program Counter back to the boot address (0x0)
            pc <= 32'b0;          
        end else begin
            // On standard clock ticks, advance the Program Counter to the next calculated address
            pc <= pc_next;        
        end
    end

endmodule