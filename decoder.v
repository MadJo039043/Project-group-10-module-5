`timescale 1ns / 1ps
// ISA fields (32-bit):
// [31:28]=opcode

// R-type (ADD, MUL):
//   [27:25]=rd   [24:22]=rs1  [21:19]=rs2   [18:0]=0

// LI (load immediate, signed):
//   [27:25]=rd   [24:0]=imm25

// LOAD (rd <- MEM[rb + off16], signed offset):
//   [27:25]=rd   [24:22]=rb    [21:6]=off16  [5:0]=0

// STORE (MEM[rb + off16] <- rX, signed offset):
//   [27:25]=rX   [24:22]=rb    [21:6]=off16  [5:0]=0

// BEQ (if R[rs1]==R[rs2]) PC <- PC+1+off22 (signed):
//   [27:25]=rs1  [24:22]=rs2   [21:0]=off22

// JMP (PC <- PC+1+off28, signed):
//   [27:0]=off28

// Opcodes: HALT=0, ADD=1, , MUL=3, LI=4, LOAD=5, STORE=6,
// Opcodes:
//   HALT=4'h0, ADD=4'h1, MUL=4'h3, LI=4'h4, LOAD=4'h5, STORE=4'h6, BEQ=4'h7, JMP=4'h8

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
    reg rw, mr, mw, W_src, asrc, br, jmp, h;
  reg [1:0] alu;

  always @(*)
   begin
    rw=0; mr=0; mw=0; W_src=0; asrc=0; br=0; jmp=0; h=0; alu=2'd0;
    case (op)
      4'h0: h   = 1'b1;                 // HALT
      4'h1: begin rw=1; alu=2'd0; end   // ADD
      4'h3: begin rw=1; alu=2'd1; end   // MUL
      4'h4: begin rw=1; alu=2'd2; asrc=1; end // LI (pass imm)
      4'h5: begin mr=1; rw=1; W_src=1; alu=2'd3; asrc=1; end // LOAD
      4'h6: begin mw=1; alu=2'd3; asrc=1; end             // STORE
      4'h7: br  = 1'b1;                 // BEQ
      4'h8: jmp = 1'b1;                 // JMP
      default: ;                        // NOP/unused
    endcase
  end

  assign RegWrite = rw;
  assign MemRead  = mr;
  assign MemWrite = mw;
  assign MemToReg = W_src;
  assign ALUSrc   = asrc;
  assign ALUop    = alu;
  assign Branch   = br;
  assign Jump     = jmp;
  assign Halt     = h;
endmodule

