`timescale 1ns/1ps

module cpu_tb;
    reg clk;
    reg rst;
    wire led_pin; // NEW: Wire to monitor the LED

    cpu_top uut (
        .clk(clk),
        .rst(rst),
        .led_pin(led_pin) // Connect the wire to the CPU
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("cpu_sim.vcd");
        $dumpvars(0, cpu_tb);

        clk = 0;
        rst = 1;
        #10 rst = 0;

        #100 $finish; // Run for 100 nanoseconds then stop
    end
endmodule