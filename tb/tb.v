`timescale 1ns/1ps

module tb;
    reg clk=0;
    reg reset=1;

    top dut(.clk(clk), .reset(reset));

    always #5 clk = ~clk;

    initial begin
        // reset for a few cycles
        #20 reset = 0;

        // run
        #2000 $finish;
    end
endmodule
