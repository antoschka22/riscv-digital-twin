/**
 * @brief Universal Asynchronous Receiver-Transmitter (UART) - TX Module
 *
 * Implements a standard 8-N-1 (8 data bits, no parity, 1 stop bit) UART 
 * transmitter. Utilizes a Finite State Machine (FSM) to serialize an 8-bit 
 * character over a single physical wire at a configurable baud rate
 */
module uart_tx #(
    // Default parameters tuned for the Tang Nano 20K FPGA
    parameter CLK_FREQ = 27000000, // Board clock frequency (27 MHz)
    parameter BAUD_RATE = 115200   // Target serial baud rate
)(
    input  wire       clk,       // System clock
    input  wire       rst,       // Active-high reset
    input  wire       tx_start,  // Trigger signal: pulse HIGH for 1 cycle to begin transmission
    input  wire [7:0] tx_data,   // The 8-bit ASCII character to transmit
    output reg        tx_pin,    // The physical wire connected to the USB-to-Serial bridge
    output reg        tx_busy    // HIGH when a transmission is in progress (CPU should stall/wait)
);

    // --- Clock Divider ---
    // Calculate how many system clock cycles occur per UART bit duration
    localparam CLOCKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    // --- Finite State Machine (FSM) States ---
    localparam s_IDLE  = 3'b000; // Waiting for transmission request
    localparam s_START = 3'b001; // Sending the START bit (LOW)
    localparam s_DATA  = 3'b010; // Sending the 8 DATA bits
    localparam s_STOP  = 3'b011; // Sending the STOP bit (HIGH)

    // Internal FSM registers
    reg [2:0]  state;           // Current FSM state
    reg [15:0] clock_count;     // Counter for generating the correct baud timing
    reg [2:0]  bit_index;       // Tracks which of the 8 data bits is currently being sent
    reg [7:0]  saved_data;      // Latches the input data so it doesn't change during transmission

    // --- Sequential FSM Logic ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset to default idle conditions
            state       <= s_IDLE;
            tx_pin      <= 1'b1;    // UART protocol dictates the line is HIGH when idle
            tx_busy     <= 1'b0;
            clock_count <= 0;
            bit_index   <= 0;
        end else begin
            case (state)
                
                s_IDLE: begin
                    tx_pin      <= 1'b1;
                    clock_count <= 0;
                    bit_index   <= 0;
                    
                    if (tx_start) begin
                        // Acknowledge the start request, latch data, and transition state
                        tx_busy    <= 1'b1;
                        saved_data <= tx_data;
                        state      <= s_START;
                    end else begin
                        tx_busy    <= 1'b0;
                    end
                end

                s_START: begin
                    tx_pin <= 1'b0; // Pull the line LOW to signal a START bit
                    
                    if (clock_count < CLOCKS_PER_BIT - 1) begin
                        clock_count <= clock_count + 1; // Wait for the bit duration
                    end else begin
                        clock_count <= 0;
                        state       <= s_DATA; // Move to data transmission
                    end
                end

                s_DATA: begin
                    tx_pin <= saved_data[bit_index]; // Drive the line with the current data bit
                    
                    if (clock_count < CLOCKS_PER_BIT - 1) begin
                        clock_count <= clock_count + 1; // Wait for the bit duration
                    end else begin
                        clock_count <= 0;
                        
                        // Check if we've sent all 8 bits
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            state <= s_STOP; // Move to stop bit transmission
                        end
                    end
                end

                s_STOP: begin
                    tx_pin <= 1'b1; // Pull the line HIGH to signal a STOP bit
                    
                    if (clock_count < CLOCKS_PER_BIT - 1) begin
                        clock_count <= clock_count + 1; // Wait for the bit duration
                    end else begin
                        state <= s_IDLE; // Transmission complete, return to idle
                    end
                end
                
                // Fallback to prevent FSM lockup
                default: state <= s_IDLE;
            endcase
        end
    end
endmodule