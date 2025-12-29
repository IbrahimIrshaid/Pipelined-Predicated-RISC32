`timescale 1ns/1ps

// CPU core wrapper (datapath only). Uses separate instruction and data memories externally.
module cpu(
    input         clk,
    input         reset,
    input  [31:0] dataout,
    input  [31:0] instruction,
    output        MemRd,
    output        MemWr,
    output [31:0] datain,
    output [31:0] instrAddr,
    output [31:0] dataAddr
);
    datapath dp(
        .clk(clk),
        .reset(reset),
        .instrAddr(instrAddr),
        .instruction(instruction),
        .MemRd(MemRd),
        .MemWr(MemWr),
        .dataAddr(dataAddr),
        .datain(datain),
        .dataout(dataout)
    );
endmodule
