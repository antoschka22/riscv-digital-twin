module uart_tx #(
    parameter CLK_FREQ = 27000000, // Tang Nano 20K clock
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       tx_start,  // High for 1 cycle to start sending
    input  wire [7:0] tx_data,   // The ASCII character to send
    output reg        tx_pin,    // The physical wire to the Mac
    output reg        tx_busy    // High when transmitting (CPU should wait)
);

    localparam CLOCKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    // State Machine States
    localparam s_IDLE  = 3'b000;
    localparam s_START = 3'b001;
    localparam s_DATA  = 3'b010;
    localparam s_STOP  = 3'b011;

    reg [2:0]  state;
    reg [15:0] clock_count;
    reg [2:0]  bit_index;
    reg [7:0]  saved_data;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= s_IDLE;
            tx_pin <= 1'b1; // UART line is HIGH when idle
            tx_busy <= 1'b0;
            clock_count <= 0;
            bit_index <= 0;
        end else begin
            case (state)
                s_IDLE: begin
                    tx_pin <= 1'b1;
                    clock_count <= 0;
                    bit_index <= 0;
                    if (tx_start) begin
                        tx_busy <= 1'b1;
                        saved_data <= tx_data;
                        state <= s_START;
                    end else begin
                        tx_busy <= 1'b0;
                    end
                end

                s_START: begin
                    tx_pin <= 1'b0; // Pull low for start bit
                    if (clock_count < CLOCKS_PER_BIT - 1) begin
                        clock_count <= clock_count + 1;
                    end else begin
                        clock_count <= 0;
                        state <= s_DATA;
                    end
                end

                s_DATA: begin
                    tx_pin <= saved_data[bit_index]; // Send bit
                    if (clock_count < CLOCKS_PER_BIT - 1) begin
                        clock_count <= clock_count + 1;
                    end else begin
                        clock_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            state <= s_STOP;
                        end
                    end
                end

                s_STOP: begin
                    tx_pin <= 1'b1; // Pull high for stop bit
                    if (clock_count < CLOCKS_PER_BIT - 1) begin
                        clock_count <= clock_count + 1;
                    end else begin
                        state <= s_IDLE;
                    end
                end
                
                default: state <= s_IDLE;
            endcase
        end
    end
endmodule