`timescale 1ns/1ps
`include "opcodes.v"

module datapath(
    input         clk,
    input         reset,

    output [31:0] instrAddr,      // WORD address
    input  [31:0] instruction,

    output        MemRd,
    output        MemWr,
    output [31:0] dataAddr,       // WORD address
    output [31:0] datain,
    input  [31:0] dataout
);

    // =========================
    // IF stage
    // =========================
    reg [31:0] PC;
    assign instrAddr = PC;

    wire [31:0] PC_plus1 = PC + 32'd1;

    // jump resolution from EX stage
    reg        ex_take_jump;
    reg [31:0] ex_jump_target;

    // IF/ID pipeline regs
    reg [31:0] IFID_instr;
    reg [31:0] IFID_pc;

    // stall / flush
    reg stallF, stallD, flushD;

    wire [31:0] PC_next = ex_take_jump ? ex_jump_target : PC_plus1;

    always @(posedge clk) begin
        if (reset) begin
            PC <= 32'd0;
        end else if (!stallF) begin
            PC <= PC_next;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            IFID_instr <= 32'h0;
            IFID_pc    <= 32'h0;
        end else if (!stallD) begin
            IFID_pc    <= PC;
            IFID_instr <= flushD ? 32'h0 : instruction;
        end
    end

    // =========================
    // ID stage
    // =========================
    wire [4:0] opcodeD = IFID_instr[31:27];
    wire [4:0] RpD     = IFID_instr[26:22];
    wire [4:0] RdD     = IFID_instr[21:17];
    wire [4:0] RsD     = IFID_instr[16:12];
    wire [4:0] RtD     = IFID_instr[11:7];
    wire [11:0] imm12D = IFID_instr[11:0];
    wire [21:0] off22D = IFID_instr[21:0];

    // controller outputs
    wire       regwriteD, memreadD, memwriteD, memtoregD, alusrc_immD;
    wire [2:0] aluopD;
    wire       is_jumpD, is_callD, is_jrD, imm_zeroextD;

    controller u_ctrl(
        .opcode(opcodeD),
        .regwrite(regwriteD),
        .memread(memreadD),
        .memwrite(memwriteD),
        .memtoreg(memtoregD),
        .alusrc_imm(alusrc_immD),
        .aluop(aluopD),
        .is_jump(is_jumpD),
        .is_call(is_callD),
        .is_jr(is_jrD),
        .imm_zeroext(imm_zeroextD)
    );

    // register file read addressing:
    //   ra1 = Rs (base / operand)
    //   ra2 = Rt for R-type, Rd for SW (store-data), otherwise Rt (ignored)
    wire is_rtypeD = (opcodeD <= `OP_AND) || (opcodeD == `OP_JR);
    wire [4:0] ra2_sel = (opcodeD == `OP_SW) ? RdD : RtD;

    wire [31:0] RD1_raw, RD2_raw, RDp_raw;

    // WB interface wires
    reg  [31:0] WB_wdata;
    reg         WB_we;
    reg  [4:0]  WB_wa;

    regfile32 u_rf(
        .clk(clk),
        .we(WB_we),
        .ra1(RsD),
        .ra2(ra2_sel),
        .ra3(RpD),
        .wa(WB_wa),
        .wd(WB_wdata),
        .pc_value(IFID_pc),
        .rd1(RD1_raw),
        .rd2(RD2_raw),
        .rd3(RDp_raw)
    );


    // immediate extension
    wire [31:0] imm_sext, imm_zext;
    signext12 u_se(.imm(imm12D), .y(imm_sext));
    zeroext12 u_ze(.imm(imm12D), .y(imm_zext));
    wire [31:0] imm_extD = imm_zeroextD ? imm_zext : imm_sext;

    // sign-extended jump offset
    wire [31:0] off_extD;
    signext22 u_s22(.off(off22D), .y(off_extD));

    // For SW, RD2_raw already holds store-data (Reg[Rd]).
    wire [31:0] store_valD = RD2_raw;

    // =========================
    // Pipeline regs
    // =========================
    // ID/EX
    reg [4:0]  IDEX_Rp;
    reg [31:0] IDEX_rp_val;
    reg [4:0]  IDEX_opcode;
    reg        IDEX_regwrite, IDEX_memread, IDEX_memwrite, IDEX_memtoreg, IDEX_alusrc_imm;
    reg [2:0]  IDEX_aluop;
    reg        IDEX_is_jump, IDEX_is_call, IDEX_is_jr;
    reg [31:0] IDEX_pc;
    reg [31:0] IDEX_rs_val, IDEX_rt_val, IDEX_store_val;
    reg [31:0] IDEX_imm_ext, IDEX_off_ext;
    reg [4:0]  IDEX_dest;
    reg [4:0]  IDEX_Rs, IDEX_Rt, IDEX_Rd_field;

    // EX/MEM
    reg        EXMEM_pred;
    reg        EXMEM_regwrite, EXMEM_memread, EXMEM_memwrite, EXMEM_memtoreg;
    reg        EXMEM_is_call;
    reg [31:0] EXMEM_alu_out;
    reg [31:0] EXMEM_store_val;
    reg [4:0]  EXMEM_waddr;
    reg [31:0] EXMEM_pc_plus1;

    // MEM/WB
    reg        MEMWB_pred;
    reg        MEMWB_regwrite, MEMWB_memtoreg;
    reg        MEMWB_is_call;
    reg [31:0] MEMWB_alu_out;
    reg [31:0] MEMWB_mem_out;
    reg [4:0]  MEMWB_waddr;
    reg [31:0] MEMWB_pc_plus1;

    // destination register (Rd for most, R31 for CALL)
    wire [4:0] destD = is_callD ? 5'd31 : RdD;

    // =========================
    // Hazard detection (load-use)
    // =========================
    wire D_uses_rs = (opcodeD != `OP_J) && (opcodeD != `OP_CALL); // J/CALL don't need Rs
    wire D_uses_rt = (opcodeD <= `OP_AND); // R-type uses Rt
    wire D_uses_store = (opcodeD == `OP_SW);

    wire load_use_hazard =
        IDEX_memread && IDEX_regwrite && (IDEX_dest != 5'd0) && (IDEX_dest != 5'd30) &&
        ((D_uses_rs && (IDEX_dest == RsD)) ||
         (D_uses_rt && (IDEX_dest == RtD)) ||
         (D_uses_store && (IDEX_dest == RdD)) ||
         ((opcodeD == `OP_JR) && (IDEX_dest == RsD)) ||
         ((RpD != 5'd0) && (IDEX_dest == RpD)));

    always @(*) begin
        stallF = load_use_hazard;
        stallD = load_use_hazard;
        flushD = ex_take_jump;
    end

    always @(posedge clk) begin
        if (reset) begin
            IDEX_Rp         <= 5'd0;
            IDEX_rp_val     <= 32'h0;
            IDEX_opcode     <= 5'd0;
            IDEX_regwrite   <= 1'b0;
            IDEX_memread    <= 1'b0;
            IDEX_memwrite   <= 1'b0;
            IDEX_memtoreg   <= 1'b0;
            IDEX_alusrc_imm <= 1'b0;
            IDEX_aluop      <= `ALU_ADD;
            IDEX_is_jump    <= 1'b0;
            IDEX_is_call    <= 1'b0;
            IDEX_is_jr      <= 1'b0;
            IDEX_pc         <= 32'h0;
            IDEX_rs_val     <= 32'h0;
            IDEX_rt_val     <= 32'h0;
            IDEX_store_val  <= 32'h0;
            IDEX_imm_ext    <= 32'h0;
            IDEX_off_ext    <= 32'h0;
            IDEX_dest       <= 5'd0;
            IDEX_Rs         <= 5'd0;
            IDEX_Rt         <= 5'd0;
            IDEX_Rd_field   <= 5'd0;
        end else if (load_use_hazard || ex_take_jump) begin
            // bubble (load-use stall, or wrong-path instruction behind a taken jump)
            IDEX_Rp         <= 5'd0;
            IDEX_rp_val     <= 32'h0;
            IDEX_regwrite   <= 1'b0;
            IDEX_memread    <= 1'b0;
            IDEX_memwrite   <= 1'b0;
            IDEX_memtoreg   <= 1'b0;
            IDEX_is_jump    <= 1'b0;
            IDEX_is_call    <= 1'b0;
            IDEX_is_jr      <= 1'b0;
            IDEX_opcode     <= 5'd0;
            IDEX_alusrc_imm <= 1'b0;
            IDEX_aluop      <= `ALU_ADD;
            IDEX_pc         <= 32'h0;
            IDEX_rs_val     <= 32'h0;
            IDEX_rt_val     <= 32'h0;
            IDEX_store_val  <= 32'h0;
            IDEX_imm_ext    <= 32'h0;
            IDEX_off_ext    <= 32'h0;
            IDEX_dest       <= 5'd0;
            IDEX_Rs         <= 5'd0;
            IDEX_Rt         <= 5'd0;
            IDEX_Rd_field   <= 5'd0;
        end else begin
            IDEX_Rp         <= RpD;
            IDEX_rp_val     <= RDp_raw;
            IDEX_opcode     <= opcodeD;
            IDEX_regwrite   <= regwriteD;
            IDEX_memread    <= memreadD;
            IDEX_memwrite   <= memwriteD;
            IDEX_memtoreg   <= memtoregD;
            IDEX_alusrc_imm <= alusrc_immD;
            IDEX_aluop      <= aluopD;
            IDEX_is_jump    <= is_jumpD;
            IDEX_is_call    <= is_callD;
            IDEX_is_jr      <= is_jrD;
            IDEX_pc         <= IFID_pc;
            IDEX_rs_val     <= RD1_raw;
            // rt_val is used only for R-type; for others it is ignored
            IDEX_rt_val     <= RD2_raw;
            IDEX_store_val  <= store_valD;
            IDEX_imm_ext    <= imm_extD;
            IDEX_off_ext    <= off_extD;
            IDEX_dest       <= destD;
            IDEX_Rs         <= RsD;
            IDEX_Rt         <= RtD;
            IDEX_Rd_field   <= RdD;
        end
    end

    // =========================
    // EX stage (forwarding + ALU + jump)
    // =========================
    reg [31:0] ex_a, ex_b, ex_store, ex_p;
    wire fwd_mem = EXMEM_pred && EXMEM_regwrite && !EXMEM_memtoreg && (EXMEM_waddr != 5'd0) && (EXMEM_waddr != 5'd30);
    wire fwd_wb  = MEMWB_pred && MEMWB_regwrite && (MEMWB_waddr != 5'd0) && (MEMWB_waddr != 5'd30);
    wire [31:0] wb_value = MEMWB_memtoreg ? MEMWB_mem_out : MEMWB_alu_out;

    always @(*) begin
        ex_a = IDEX_rs_val;
        ex_b = IDEX_rt_val;
        ex_store = IDEX_store_val;
        ex_p = IDEX_rp_val;

        // forward from MEM/WB first, then EX/MEM, so the most recent producer wins
        if (fwd_wb && (MEMWB_waddr == IDEX_Rs))       ex_a     = wb_value;
        if (fwd_wb && (MEMWB_waddr == IDEX_Rt))       ex_b     = wb_value;
        if (fwd_wb && (MEMWB_waddr == IDEX_Rd_field)) ex_store = wb_value;
        if (fwd_wb && (MEMWB_waddr == IDEX_Rp))       ex_p     = wb_value;

        if (fwd_mem && (EXMEM_waddr == IDEX_Rs))       ex_a     = EXMEM_alu_out;
        if (fwd_mem && (EXMEM_waddr == IDEX_Rt))       ex_b     = EXMEM_alu_out;
        if (fwd_mem && (EXMEM_waddr == IDEX_Rd_field)) ex_store = EXMEM_alu_out;
        if (fwd_mem && (EXMEM_waddr == IDEX_Rp))       ex_p     = EXMEM_alu_out;
    end

    // predicate: execute if Rp == R0, otherwise if (forwarded) Reg[Rp] != 0
    wire pred_ex = (IDEX_Rp == 5'd0) ? 1'b1 : (ex_p != 32'h0);

    wire [31:0] alu_b_in = IDEX_alusrc_imm ? IDEX_imm_ext : ex_b;

    wire [31:0] alu_result;
    wire alu_z, alu_n;
    alu32 u_alu(.a(ex_a), .b(alu_b_in), .alucont(IDEX_aluop), .result(alu_result), .z(alu_z), .n(alu_n));

    wire [31:0] ex_pc_plus1 = IDEX_pc + 32'd1;
    wire [31:0] jump_target_off = IDEX_pc + IDEX_off_ext;
    wire [31:0] jump_target_jr  = ex_a; // Rs value

    always @(*) begin
        ex_take_jump  = 1'b0;
        ex_jump_target = 32'h0;
        if (pred_ex && IDEX_is_jump) begin
            ex_take_jump  = 1'b1;
            ex_jump_target = IDEX_is_jr ? jump_target_jr : jump_target_off;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            EXMEM_pred      <= 1'b0;
            EXMEM_regwrite  <= 1'b0;
            EXMEM_memread   <= 1'b0;
            EXMEM_memwrite  <= 1'b0;
            EXMEM_memtoreg  <= 1'b0;
            EXMEM_is_call   <= 1'b0;
            EXMEM_alu_out   <= 32'h0;
            EXMEM_store_val <= 32'h0;
            EXMEM_waddr     <= 5'd0;
            EXMEM_pc_plus1  <= 32'h0;
        end else begin
            EXMEM_pred      <= pred_ex;
            EXMEM_regwrite  <= IDEX_regwrite;
            EXMEM_memread   <= IDEX_memread;
            EXMEM_memwrite  <= IDEX_memwrite;
            EXMEM_memtoreg  <= IDEX_memtoreg;
            EXMEM_is_call   <= IDEX_is_call;
            EXMEM_alu_out   <= IDEX_is_call ? ex_pc_plus1 : alu_result;
            EXMEM_store_val <= ex_store;
            EXMEM_waddr     <= IDEX_is_call ? 5'd31 : IDEX_dest;
            EXMEM_pc_plus1  <= ex_pc_plus1;
        end
    end

    // =========================
    // MEM stage
    // =========================
    assign MemRd   = EXMEM_pred && EXMEM_memread;
    assign MemWr   = EXMEM_pred && EXMEM_memwrite;
    assign dataAddr = EXMEM_alu_out;   // word address
    assign datain   = EXMEM_store_val;

    always @(posedge clk) begin
        if (reset) begin
            MEMWB_pred     <= 1'b0;
            MEMWB_regwrite <= 1'b0;
            MEMWB_memtoreg <= 1'b0;
            MEMWB_is_call  <= 1'b0;
            MEMWB_alu_out  <= 32'h0;
            MEMWB_mem_out  <= 32'h0;
            MEMWB_waddr    <= 5'd0;
            MEMWB_pc_plus1 <= 32'h0;
        end else begin
            MEMWB_pred     <= EXMEM_pred;
            MEMWB_regwrite <= EXMEM_regwrite;
            MEMWB_memtoreg <= EXMEM_memtoreg;
            MEMWB_is_call  <= EXMEM_is_call;
            MEMWB_alu_out  <= EXMEM_alu_out;
            MEMWB_mem_out  <= dataout;
            MEMWB_waddr    <= EXMEM_waddr;
            MEMWB_pc_plus1 <= EXMEM_pc_plus1;
        end
    end

    // =========================
    // WB stage
    // =========================
    always @(*) begin
        WB_we = MEMWB_pred && MEMWB_regwrite;
        WB_wa = MEMWB_waddr;

        if (MEMWB_is_call && (MEMWB_waddr == 5'd31)) begin
            WB_wdata = MEMWB_pc_plus1;
        end else begin
            WB_wdata = MEMWB_memtoreg ? MEMWB_mem_out : MEMWB_alu_out;
        end
    end

endmodule
