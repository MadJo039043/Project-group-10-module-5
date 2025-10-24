`timescale 1ns/1ps

module decoder24(
  input  [23:0] instr,   // IR
  output [5:0]  rd, rs1, rs2,
  output [23:0] imm8, off8, off20,
  output [3:0] opcode
);
  assign opcode = instr[23:20];
  // Common field layout (for your ISA)
  assign rs1   = instr[19:14];   // destination (R-type)
  assign rs2  = instr[13:8];    // source 1
  assign rd  = instr[7:2];     // source 2 (or dest for I-type like LI, ORI, LUI)

  // Immediate fields
  assign imm8  = {{16{instr[7]}},  instr[7:0]};   // 8-bit sign-extended immediate
  assign off8  = {{16{instr[7]}},  instr[7:0]};   // branch offset
  assign off20 = {{4{instr[19]}},  instr[19:0]};  // 20-bit jump offset

endmodule
