`timescale 1ns/1ps
`include "opcodes.v"

// Self-checking testbench: loads a program straight into IMEM, runs the
// pipeline, then checks architectural state. No NOPs are inserted, so the
// program exercises forwarding, load-use stalls, predicate reads and
// control-flow squashing.
module tb_selfcheck;
    reg clk = 0, reset = 1;
    top dut(.clk(clk), .reset(reset));
    always #5 clk = ~clk;

    integer errors = 0;

    function automatic [31:0] R(input [4:0] op, rp, rd, rs, rt);
        R = {op, rp, rd, rs, rt, 7'b0};
    endfunction
    function automatic [31:0] I(input [4:0] op, rp, rd, rs, input [11:0] imm);
        I = {op, rp, rd, rs, imm};
    endfunction
    function automatic [31:0] J(input [4:0] op, rp, input [21:0] off);
        J = {op, rp, off};
    endfunction

    task automatic put(input integer a, input [31:0] w);
        dut.U_IMEM.RAM[a*4+0] = w[7:0];   dut.U_IMEM.RAM[a*4+1] = w[15:8];
        dut.U_IMEM.RAM[a*4+2] = w[23:16]; dut.U_IMEM.RAM[a*4+3] = w[31:24];
    endtask

    task automatic check_reg(input [4:0] r, input [31:0] exp, input string msg);
        reg [31:0] got;
        got = (r == 0) ? 32'h0 : dut.U_CPU.dp.u_rf.rf[r];
        if (got !== exp) begin
            $display("FAIL  %-44s R%0d = %0d (0x%08h), expected %0d", msg, r, got, got, exp);
            errors++;
        end else
            $display("ok    %-44s R%0d = %0d", msg, r, got);
    endtask

    task automatic check_mem(input integer a, input [31:0] exp, input string msg);
        reg [31:0] got;
        got = {dut.U_DMEM.RAM[a*4+3], dut.U_DMEM.RAM[a*4+2], dut.U_DMEM.RAM[a*4+1], dut.U_DMEM.RAM[a*4+0]};
        if (got !== exp) begin
            $display("FAIL  %-44s MEM[%0d] = %0d, expected %0d", msg, a, got, exp);
            errors++;
        end else
            $display("ok    %-44s MEM[%0d] = %0d", msg, a, got);
    endtask

    integer k;
    initial begin
        for (k = 0; k < 4096; k++) dut.U_IMEM.RAM[k] = 8'h00;

        // --- ALU + forwarding -------------------------------------------------
        put( 0, I(`OP_ADDI, 0, 1, 0, 12'd5));          // R1 = 5
        put( 1, I(`OP_ADDI, 0, 2, 0, 12'd7));          // R2 = 7
        put( 2, R(`OP_ADD,  0, 3, 1, 2));              // R3 = 12   R2 from EX/MEM, R1 from MEM/WB
        put( 3, R(`OP_SUB,  0, 4, 3, 1));              // R4 = 7    R1 written back this cycle (regfile bypass)
        put( 4, I(`OP_ANDI, 0, 5, 3, 12'h00F));        // R5 = 12
        put( 5, I(`OP_ORI,  0, 6, 0, 12'h0A5));        // R6 = 0xA5
        put( 6, I(`OP_NORI, 0, 7, 0, 12'h000));        // R7 = 0xFFFFFFFF
        put( 7, I(`OP_ADDI, 0, 20, 0, 12'd1));         // R20 = 1
        put( 8, I(`OP_ADDI, 0, 20, 0, 12'd2));         // R20 = 2   (newer write to the same register)
        put( 9, R(`OP_ADD,  0, 21, 20, 0));            // R21 = 2   EX/MEM must win over MEM/WB
        // --- memory + load-use ----------------------------------------------
        put(10, I(`OP_SW,   0, 3, 0, 12'd3));          // MEM[3] = R3
        put(11, I(`OP_LW,   0, 8, 0, 12'd3));          // R8 = MEM[3] = 12
        put(12, R(`OP_ADD,  0, 9, 8, 1));              // R9 = 17   load-use stall
        // --- predication ----------------------------------------------------
        put(13, I(`OP_ADDI, 0, 11, 0, 12'd0));         // R11 = 0   (false predicate)
        put(14, I(`OP_ADDI, 0, 12, 0, 12'd1));         // R12 = 1   (true predicate)
        put(15, I(`OP_ADDI, 11, 13, 0, 12'd99));       // skipped: R11 == 0
        put(16, I(`OP_ADDI, 12, 13, 0, 12'd77));       // R13 = 77  predicate forwarded from MEM/WB
        put(17, I(`OP_ADDI, 11, 13, 0, 12'd55));       // skipped
        put(18, R(`OP_ADD,  0, 22, 13, 0));            // R22 = 77  skipped producer must not forward
        put(19, I(`OP_LW,   0, 23, 0, 12'd3));         // R23 = 12
        put(20, I(`OP_ADDI, 23, 24, 0, 12'd9));        // R24 = 9   predicate depends on a load (stall)
        // --- control flow ---------------------------------------------------
        put(21, J(`OP_J,    0, 22'd3));                // jump to 24
        put(22, I(`OP_ADDI, 0, 14, 0, 12'd111));       // wrong path, must be squashed
        put(23, I(`OP_ADDI, 0, 14, 0, 12'd222));       // wrong path, must be squashed
        put(24, I(`OP_ADDI, 0, 15, 0, 12'd45));        // R15 = 45
        put(25, J(`OP_J,    11, 22'd5));               // predicated-off jump: falls through
        put(26, J(`OP_CALL, 0, 22'd4));                // call 30, R31 = 27
        put(27, I(`OP_ADDI, 0, 16, 0, 12'd88));        // runs after return
        put(28, J(`OP_J,    0, 22'd0));                // halt: spin here
        put(29, I(`OP_ADDI, 0, 17, 0, 12'd123));       // never reached
        put(30, R(`OP_ADD,  0, 18, 31, 0));            // R18 = 27  R31 forwarded right after CALL
        put(31, R(`OP_JR,   0, 0, 31, 0));             // return to R31

        repeat (2) @(posedge clk);
        reset = 0;
        repeat (80) @(posedge clk);
        #1;

        check_reg(1,  5,            "ADDI");
        check_reg(3,  12,           "ADD, forwarding from EX/MEM and MEM/WB");
        check_reg(4,  7,            "SUB, same-cycle writeback bypass");
        check_reg(5,  12,           "ANDI (zero-extended)");
        check_reg(6,  32'h0A5,      "ORI");
        check_reg(7,  32'hFFFFFFFF, "NORI");
        check_reg(21, 2,            "forwarding picks the newest producer");
        check_mem(3,  12,           "SW");
        check_reg(8,  12,           "LW");
        check_reg(9,  17,           "load-use stall");
        check_reg(13, 77,           "predicate false skips, true executes");
        check_reg(22, 77,           "predicated-off result is not forwarded");
        check_reg(24, 9,            "predicate produced by a load");
        check_reg(14, 0,            "taken J squashes both wrong-path slots");
        check_reg(15, 45,           "J target executes");
        check_reg(31, 27,           "CALL links R31 = PC + 1");
        check_reg(18, 27,           "R31 forwarded right after CALL");
        check_reg(16, 88,           "JR returns to caller");
        check_reg(17, 0,            "halt loop: fall-through never executes");
        check_reg(0,  0,            "R0 hardwired to zero");

        if (errors == 0) $display("\nPASS: all checks succeeded");
        else             $display("\nFAILED: %0d check(s)", errors);
        $finish;
    end
endmodule
