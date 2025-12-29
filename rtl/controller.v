`timescale 1ns/1ps
`include "opcodes.v"

// Decode for the predicated 32-bit RISC ISA described in the assignment.
// This module is purely combinational.
module controller(
    input  logic [4:0] opcode,
    output logic       regwrite,
    output logic       memread,
    output logic       memwrite,
    output logic       memtoreg,     // 1 => write back memory data, 0 => write back ALU result
    output logic       alusrc_imm,   // 1 => ALU B comes from immediate
    output logic [2:0] aluop,
    output logic       is_jump,      // J or CALL or JR
    output logic       is_call,
    output logic       is_jr,
    output logic       imm_zeroext   // 1 => zero-extend immediate (logical imm ops)
);
    always_comb begin
        // defaults = NOP
        regwrite     = 1'b0;
        memread      = 1'b0;
        memwrite     = 1'b0;
        memtoreg     = 1'b0;
        alusrc_imm   = 1'b0;
        aluop        = `ALU_ADD;
        is_jump      = 1'b0;
        is_call      = 1'b0;
        is_jr        = 1'b0;
        imm_zeroext  = 1'b0;

        unique case (opcode)
            `OP_ADD: begin regwrite=1; aluop=`ALU_ADD; end
            `OP_SUB: begin regwrite=1; aluop=`ALU_SUB; end
            `OP_OR : begin regwrite=1; aluop=`ALU_OR ; end
            `OP_NOR: begin regwrite=1; aluop=`ALU_NOR; end
            `OP_AND: begin regwrite=1; aluop=`ALU_AND; end

            `OP_ADDI: begin regwrite=1; alusrc_imm=1; aluop=`ALU_ADD; end
            `OP_ORI : begin regwrite=1; alusrc_imm=1; aluop=`ALU_OR ; imm_zeroext=1; end
            `OP_NORI: begin regwrite=1; alusrc_imm=1; aluop=`ALU_NOR; imm_zeroext=1; end
            `OP_ANDI: begin regwrite=1; alusrc_imm=1; aluop=`ALU_AND; imm_zeroext=1; end

            `OP_LW: begin
                regwrite=1; memread=1; memtoreg=1;
                alusrc_imm=1; aluop=`ALU_ADD;
            end
            `OP_SW: begin
                memwrite=1;
                alusrc_imm=1; aluop=`ALU_ADD;
            end

            `OP_J: begin
                is_jump=1;
            end
            `OP_CALL: begin
                is_jump=1; is_call=1; regwrite=1; // writes R31
            end
            `OP_JR: begin
                is_jump=1; is_jr=1;
            end
            default: begin end
        endcase
    end
endmodule
