`timescale 1ns/1ps

module cpu_tb;
    reg clk;
    reg [31:0] instruction;

    // Instantiate the CPU
    cpu_top uut (
        .clk(clk),
        .instruction(instruction)
    );

    // Generate a virtual clock: Toggle the clk wire every 5 nanoseconds
    always #5 clk = ~clk;

    initial begin
        // Setup the waveform dumper for GTKWave
        $dumpfile("cpu_sim.vcd");
        $dumpvars(0, cpu_tb);

        // Start at time 0
        clk = 0;
        instruction = 32'h00000000; // NOP

        // Cycle 1: ADDI x1, x0, 15
        // (Machine code for adding 15 to register 0, saving in register 1)
        #10 instruction = 32'h00f00093;

        // Cycle 2: ADDI x2, x1, 10
        // (Adds 10 to register 1, saving in register 2)
        #10 instruction = 32'h00a08113;

        // Cycle 3: ADD x3, x1, x2
        // (Adds register 1 and register 2, saving in register 3)
        #10 instruction = 32'h002081b3;

        // Let the final result write to the register file, then end simulation
        #20 $finish;
    end
endmodule