`timescale 1ns / 1ps
// ISA fields (32-bit):
// [31:28]=opcode
// R-type:  [27:25]=rd, [24:22]=rs1, [21:19]=rs2, [18:0]=000
// LI:      [27:25]=rd, [24:0]=imm25 (signed)
// LOAD/ST: [27:25]=rX, [24:22]=rb,  [21:6]=off16 , [5:0]=000 (signed)
// BEQ:     [27:25]=rs1,[24:22]=rs2, [21:0]=off22 (signed)
// JMP:     [27:0]=off28 (signed)
// Opcodes: HALT=0000, ADD=0001, , MUL=0011, LI=0100, LOAD=0101, STORE=0110,
// BEQ=0111, JMP=1000

module decoder(
  input  [31:0] instr,
  output [2:0]  rd, rs1, rs2,
  output [31:0] imm25, off16, off22, off28,
  output        RegWrite, MemRead, MemWrite, MemToReg, ALUSrc,
  output [3:0]  ALUop,       // 0=ADD, 1=MUL, 2==PASS, 3=ADDR_ADD
  output        Branch, Jump, Halt
);
  wire [3:0] op = instr[31:28];
  assign imm25 = {{7{instr[24]}},  instr[24:0]}; //instr[24] is the sign bit of the 25-field, duplicate 1 7 times
  assign off16 = {{16{instr[21]}}, instr[21:6]};
  assign off22 = {{10{instr[21]}}, instr[21:0]};
  assign off28 = {{4{instr[27]}},  instr[27:0]};
    reg rw, mr, mw, m2r, asrc, br, jmp, h;
  reg [1:0] alu;

  always @* begin
    rw=0; mr=0; mw=0; m2r=0; asrc=0; br=0; jmp=0; h=0; alu=2'd0;
    case (op)
      4'h0: h   = 1'b1;                 // HALT
      4'h1: begin rw=1; alu=2'd0; end   // ADD
      4'h3: begin rw=1; alu=2'd1; end   // MUL
      4'h4: begin rw=1; alu=2'd2; asrc=1; end // LI (pass imm)
      4'h5: begin mr=1; rw=1; m2r=1; alu=2'd3; asrc=1; end // LOAD
      4'h6: begin mw=1; alu=2'd3; asrc=1; end             // STORE
      4'h7: br  = 1'b1;                 // BEQ
      4'h8: jmp = 1'b1;                 // JMP
      default: ;                        // NOP/unused
    endcase
  end

  assign RegWrite = rw;
  assign MemRead  = mr;
  assign MemWrite = mw;
  assign MemToReg = m2r;
  assign ALUSrc   = asrc;
  assign ALUop    = alu;
  assign Branch   = br;
  assign Jump     = jmp;
  assign Halt     = h;
endmodule

