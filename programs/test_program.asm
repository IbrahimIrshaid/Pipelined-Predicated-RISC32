; Same program as tb/tb_selfcheck.sv. Rp defaults to R0 (unconditional).
 0:  ADDI R1, R0, 5
 1:  ADDI R2, R0, 7
 2:  ADD R3, R1, R2
 3:  SUB R4, R3, R1
 4:  ANDI R5, R3, 0xF
 5:  ORI R6, R0, 0xA5
 6:  NORI R7, R0, 0
 7:  ADDI R20, R0, 1
 8:  ADDI R20, R0, 2
 9:  ADD R21, R20, R0
10:  SW R3, 3(R0)
11:  LW R8, 3(R0)
12:  ADD R9, R8, R1
13:  ADDI R11, R0, 0
14:  ADDI R12, R0, 1
15:  ADDI R13, R0, 99, R11
16:  ADDI R13, R0, 77, R12
17:  ADDI R13, R0, 55, R11
18:  ADD R22, R13, R0
19:  LW R23, 3(R0)
20:  ADDI R24, R0, 9, R23
21:  J +3
22:  ADDI R14, R0, 111
23:  ADDI R14, R0, 222
24:  ADDI R15, R0, 45
25:  J +5, R11
26:  CALL +4
27:  ADDI R16, R0, 88
28:  J +0
29:  ADDI R17, R0, 123
30:  ADD R18, R31, R0
31:  JR R31
