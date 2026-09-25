`ifndef OPCODES_V
`define OPCODES_V

// 5-bit opcodes (bits [31:27])
`define OP_ADD   5'd0
`define OP_SUB   5'd1
`define OP_OR    5'd2
`define OP_NOR   5'd3
`define OP_AND   5'd4
`define OP_ADDI  5'd5
`define OP_ORI   5'd6
`define OP_NORI  5'd7
`define OP_ANDI  5'd9
`define OP_LW    5'd10
`define OP_SW    5'd11
`define OP_J     5'd12
`define OP_CALL  5'd13
`define OP_JR    5'd14

// ALU control encodings
`define ALU_ADD  3'd0
`define ALU_SUB  3'd1
`define ALU_OR   3'd2
`define ALU_NOR  3'd3
`define ALU_AND  3'd4

`endif
