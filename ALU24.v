`timescale 1ns / 1ps

//==========================================================
// ALU24 - 24-bit Arithmetic Logic Unit for Custom ISA
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
 input [23:0] A,
 input [23:0] B,
  input  [2:0]  ALUop,       // 0=ADD, 1=MUL, 2=PASS, 3=ADDR_ADD(=ADD)
  output reg [23:0] Y,
  output Z
);

  // Signed versions for signed arithmetic operations
  wire signed [23:0] A_signed = A;
  wire signed [23:0] B_signed = B;
  wire signed [47:0] mul_result_signed = A_signed * B_signed;

  always @(*) begin
    case (ALUop)
      3'b000: Y = A + B;                           // ADD (unsigned is fine for addresses)
      3'b001: Y = mul_result_signed[23:0];         // MUL (use signed multiplication!)
      3'b010: Y = B;                               // LI (pass immediate)
      3'b011: Y = A + B;                           // Addr add (same as ADD)
      3'b100: Y = A | B;                           // ORI (bitwise OR)
      3'b101: Y = B;                               // LUI uses pre-shifted immediate -> PASS_B
      default: Y = 24'd0;                          // Undefined → NOP
    endcase
  end
  // Zero flag for BEQ (Z=1 if result == 0)
  assign Z = (Y == 24'd0);
endmodule