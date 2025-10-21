`timescale 1ns / 1ps
//==========================================================
// ALU24 — 24-bit Arithmetic Logic Unit for Custom ISA
//==========================================================
//
// ALUop control mapping (matches decoder24.v):
//   3'b000 : ADD        (R[rd] = A + B)
//   3'b001 : MUL        (R[rd] = A * B)
//   3'b010 : PASS IMM   (R[rd] = B)         ; LI
//   3'b011 : ADDR ADD   (R[rd] = A + B)     ; LOAD/STORE address
//   3'b100 : OR         (R[rd] = A | B)     ; ORI
//   3'b101 : LUI        (R[rd] = B << 8)    ; LUI
//==========================================================

module ALU24(
  input  [23:0] A,
  input  [23:0] B,
  input  [2:0]  ALUop,       // expanded from 2 bits to 3 bits
  output reg [23:0] Y,
  output Z
);

  always @(*) begin
    case (ALUop)
      3'b000: Y = A + B;         // ADD, LOAD, STORE
      3'b001: Y = A * B;         // MUL
      3'b010: Y = B;             // LI (pass immediate)
      3'b011: Y = A + B;         // Addr add (same as ADD, kept distinct for clarity)
      3'b100: Y = A | B;         // ORI (bitwise OR)
      3'b101: Y = B << 8;        // LUI (load upper 8 bits)
      default: Y = 24'd0;        // Undefined → NOP
    endcase
  end

  // Zero flag for BEQ (Z=1 if result == 0)
  assign Z = (Y == 24'd0);

endmodule
