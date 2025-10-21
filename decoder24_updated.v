`timescale 1ns/1ps
//==========================================================
// 24-bit Custom ISA Decoder (Final Version)
//==========================================================
//
// Instruction format summary:
//
//   [23:20] = opcode (4 bits)
//
//   R-type (ADD, MUL):
//     [19:14] = rs
//     [13:8]  = rt
//     [7:2]   = rd
//     [1:0]   = 00
//
//   I-type (LI, LUI, ORI, LOAD, STORE, BEQ):
//     [19:14] = rs
//     [13:8]  = rt
//     [7:0]   = imm8
//
//   J-type (JMP, HALT):
//     [19:0]  = target (signed for relative jumps)
//
//-----------------------------------------------------------
// Opcode Map (matches assembler & documentation)
//
//   0000 : HALT
//   0001 : ADD
//   0011 : MUL
//   0100 : LI
//   0101 : LOAD
//   0110 : STORE
//   0111 : BEQ
//   1000 : JMP
//   1001 : LUI
//   1010 : ORI
//-----------------------------------------------------------

module decoder24(
  input  [23:0] instr,
  output [5:0]  rd, rs, rt,
  output [23:0] imm8_signed, imm8_unsigned, off8, off20,
  output        RegWrite, MemRead, MemWrite, MemToReg, ALUSrc,
  output [2:0]  ALUop,        // 0=ADD, 1=MUL, 2=PASS, 3=ADDR_ADD, 4=OR, 5=LUI
  output        Branch, Jump, Halt
);

  //==========================================================
  // Field Extraction
  //==========================================================
  wire [3:0] op = instr[23:20];
  assign rs = instr[19:14];
  assign rt = instr[13:8];
  assign rd = instr[7:2];

  //==========================================================
  // Immediate / Offset Extensions
  //==========================================================
  assign imm8_signed   = {{16{instr[7]}}, instr[7:0]};   // for signed 8-bit immediates
  assign imm8_unsigned = {16'b0, instr[7:0]};            // for LUI/ORI (zero-extended)
  assign off8  = {{16{instr[7]}}, instr[7:0]};           // branch/memory offset (signed)
  assign off20 = {{4{instr[19]}}, instr[19:0]};          // jump offset (signed)

  //==========================================================
  // Control Logic
  //==========================================================
  reg rw, mr, mw, W_src, asrc, br, jmp, h;
  reg [2:0] alu;

  always @(*) begin
    // default control signals
    rw=0; mr=0; mw=0; W_src=0; asrc=0; br=0; jmp=0; h=0; alu=3'd0;

    case (op)
      4'h0: h   = 1'b1;                         // HALT
      4'h1: begin rw=1; alu=3'd0; end           // ADD
      4'h3: begin rw=1; alu=3'd1; end           // MUL
      4'h4: begin rw=1; alu=3'd2; asrc=1; end   // LI (pass imm8)
      4'h5: begin rw=1; mr=1; W_src=1; alu=3'd3; asrc=1; end // LOAD
      4'h6: begin mw=1; alu=3'd3; asrc=1; end   // STORE
      4'h7: br  = 1'b1;                         // BEQ
      4'h8: jmp = 1'b1;                         // JMP
      4'h9: begin rw=1; alu=3'd5; asrc=1; end   // LUI (imm << 8)
      4'hA: begin rw=1; alu=3'd4; asrc=1; end   // ORI (rs | imm8)
      default: ;                                // NOP
    endcase
  end

  //==========================================================
  // Output Signal Assignments
  //==========================================================
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
