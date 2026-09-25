`timescale 1ns/1ps

// Instruction memory: byte-addressed array loaded from memfile.dat,
// but the CPU provides WORD addresses. Instruction fetch is little-endian.
// PC is a word address; byte index = PC << 2.
module imem(
    input  logic [31:0] PC,
    output logic [31:0] instruction
);
    logic [7:0] RAM [0:4095];

    initial begin
        $readmemh("memfile.dat", RAM);
    end

    logic [31:0] b;
    always_comb begin
        b = PC << 2;
        instruction = {RAM[b+3], RAM[b+2], RAM[b+1], RAM[b+0]};
    end
endmodule

// Data memory: word-addressed. Reads are combinational (for simple simulation),
// writes happen on posedge when MemWr is asserted. Little-endian layout.
module dmem(
    input  logic        clk,
    input  logic        MemRd,
    input  logic        MemWr,
    input  logic [31:0] address,   // WORD address
    input  logic [31:0] DataIn,
    output logic [31:0] Dataout
);
    logic [7:0] RAM [0:4095];

    // optional init (commented): $readmemh("dmem_init.dat", RAM);

    logic [31:0] b;
    always_comb begin
        b = address << 2;
        if (MemRd) Dataout = {RAM[b+3], RAM[b+2], RAM[b+1], RAM[b+0]};
        else       Dataout = 32'h0;
    end

    always_ff @(posedge clk) begin
        if (MemWr) begin
            RAM[(address << 2) + 0] <= DataIn[7:0];
            RAM[(address << 2) + 1] <= DataIn[15:8];
            RAM[(address << 2) + 2] <= DataIn[23:16];
            RAM[(address << 2) + 3] <= DataIn[31:24];
        end
    end
endmodule
