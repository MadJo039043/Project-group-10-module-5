`timescale 1ns/1ps

// 24-bit ISA (word-addressed PC/memory)
//
//  [23:20]=opcode
//
//  R-type (ADD, MUL):
//    [19:14]=rs1   [13:8]=rs2   [7:2]=rd   [1:0]=00
//
//  LI (load immediate, signed 8):
//    [19:14]=rs1   [13:8]=rs2    [7:0]=imm8
//
//  LOAD (rd <- MEM[ rb + off8 ], signed):
//    [19:14]=rd   [13:8]=rb    [7:0]=off8
//
//  STORE (MEM[ rb + off8 ] <- rX, signed):
//    [19:14]=rX   [13:8]=rb    [7:0]=off8
//    (note: for STORE the "data" register is in the rd field)
//
//  BEQ (if R[rs1]==R[rs2]) PC <- PC+1+off8  (signed):
//    [19:14]=rs1  [13:8]=rs2   [7:0]=off8
//
//  JMP (PC <- PC+1+off20, signed):
//    [19:0]=off20
//
// Opcodes: HALT=0, ADD=1, , MUL=3, LI=4, LOAD=5, STORE=6,
// Opcodes:
//   HALT=4'h0, ADD=4'h1, MUL=4'h3, LI=4'h4, LOAD=4'h5, STORE=4'h6, BEQ=4'h7, JMP=4'h8
//    reg rw, mr, mw, W_src, asrc, br, jmp, h;
//  reg [1:0] alu;

//  always @(*)
//   begin
//    rw=0; mr=0; mw=0; W_src=0; asrc=0; br=0; jmp=0; h=0; alu=2'd0;
//    case (op)
//      4'h0: h   = 1'b1;                 // HALT
//      4'h1: begin rw=1; alu=2'd0; end   // ADD
//      4'h3: begin rw=1; alu=2'd1; end   // MUL
//      4'h4: begin rw=1; alu=2'd2; asrc=1; end // LI (pass imm)
//      4'h5: begin mr=1; rw=1; W_src=1; alu=2'd3; asrc=1; end // LOAD
//      4'h6: begin mw=1; alu=2'd3; asrc=1; end             // STORE
//      4'h7: br  = 1'b1;                 // BEQ
//      4'h8: jmp = 1'b1;                 // JMP
//      default: ;                        // NOP/unused
//    endcase
//  end

//  assign RegWrite = rw;
//  assign MemRead  = mr;
//  assign MemWrite = mw;
//  assign MemToReg = W_src;
//  assign ALUSrc   = asrc;
//  assign ALUop    = alu;
//  assign Branch   = br;
//  assign Jump     = jmp;
//  assign Halt     = h;
module decoder24(
  input  [23:0] instr,   // IR
  output [5:0]  rd, rs1, rs2,
  output [23:0] imm8, off8, off20
);
wire [3:0] opcode = instr[23:20];
  // Common field layout (for your ISA)
  assign rs1   = instr[19:14];   // destination (R-type)
  assign rs2  = instr[13:8];    // source 1
  assign rd  = instr[7:2];     // source 2 (or dest for I-type like LI, ORI, LUI)

  // Immediate fields
  assign imm8  = {{16{instr[7]}},  instr[7:0]};   // 8-bit sign-extended immediate
  assign off8  = {{16{instr[7]}},  instr[7:0]};   // branch offset
  assign off20 = {{4{instr[19]}},  instr[19:0]};  // 20-bit jump offset

endmodule
