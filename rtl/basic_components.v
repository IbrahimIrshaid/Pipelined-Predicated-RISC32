`timescale 1ns/1ps
`include "opcodes.v"

// 32-bit ALU supporting required operations.
module alu32(
    input  [31:0] a,
    input  [31:0] b,
    input  [2:0]  alucont,
    output reg [31:0] result,
    output        z,
    output        n
);
    always @(*) begin
        case (alucont)
            `ALU_ADD: result = a + b;
            `ALU_SUB: result = a - b;
            `ALU_OR : result = a | b;
            `ALU_NOR: result = ~(a | b);
            `ALU_AND: result = a & b;
            default:  result = 32'h0;
        endcase
    end
    assign z = (result == 32'h0);
    assign n = result[31];
endmodule

// 32-register file with THREE read ports (needed for Rp and SW store-data).
// R0 hardwired to 0. R30 hardwired to the PC value of the instruction in Decode.
// Writes to R0 and R30 are ignored. R31 is normal storage (return address).
module regfile32(
    input         clk,
    input         we,
    input  [4:0]  ra1,
    input  [4:0]  ra2,
    input  [4:0]  ra3,
    input  [4:0]  wa,
    input  [31:0] wd,
    input  [31:0] pc_value,
    output [31:0] rd1,
    output [31:0] rd2,
    output [31:0] rd3
);
    reg [31:0] rf [31:0];
    integer i;

    initial begin
        for (i=0;i<32;i=i+1) rf[i] = 32'h0;
    end

    always @(posedge clk) begin
        if (we && (wa != 5'd0) && (wa != 5'd30)) begin
            rf[wa] <= wd;
        end
        rf[0] <= 32'h0;
    end

    function [31:0] rdata(input [4:0] ra);
        begin
            if (ra == 5'd0)       rdata = 32'h0;
            else if (ra == 5'd30) rdata = pc_value;
            else                  rdata = rf[ra];
        end
    endfunction

    assign rd1 = rdata(ra1);
    assign rd2 = rdata(ra2);
    assign rd3 = rdata(ra3);
endmodule

module signext12(input [11:0] imm, output [31:0] y);
    assign y = {{20{imm[11]}}, imm};
endmodule

module zeroext12(input [11:0] imm, output [31:0] y);
    assign y = {20'h0, imm};
endmodule

module signext22(input [21:0] off, output [31:0] y);
    assign y = {{10{off[21]}}, off};
endmodule
