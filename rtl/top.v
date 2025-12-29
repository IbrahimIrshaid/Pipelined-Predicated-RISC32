`timescale 1ns/1ps

module top(
    input clk,
    input reset
);
    wire [31:0] instrAddr;
    wire [31:0] instruction;

    wire        MemRd, MemWr;
    wire [31:0] dataAddr, datain, dataout;

    imem U_IMEM(.PC(instrAddr), .instruction(instruction));
    dmem U_DMEM(.clk(clk), .MemRd(MemRd), .MemWr(MemWr),
                .address(dataAddr), .DataIn(datain), .Dataout(dataout));

    cpu U_CPU(.clk(clk), .reset(reset),
              .dataout(dataout), .instruction(instruction),
              .MemRd(MemRd), .MemWr(MemWr),
              .datain(datain), .instrAddr(instrAddr), .dataAddr(dataAddr));
endmodule
