module pc_register(
    input  wire        clk,
    input  wire        rst,       // Reset signal
    input  wire [31:0] pc_next,   // The address to go to on the next clock cycle
    output reg  [31:0] pc         // The current execution address
);

    // This block triggers on the rising edge of the clock OR the rising edge of reset
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= 32'b0;          // If reset is high, jump back to address 0
        end else begin
            pc <= pc_next;        // Otherwise, move to the next PC
        end
    end

endmodule