`timescale 1ns / 1ps


module ALU(
 input [31:0] A,
 input [31:0] B,
  input  [1:0]  ALUop,       // 0=ADD, 1=MUL, 2=PASS, 3=ADDR_ADD(=ADD)
  output reg [31:0] Y,
  output Z
);
  always @(*) 
  begin
    case (ALUop)
      2'd0: Y = A + B;
      2'd1: Y = A * B;
      2'd2: Y = B;          // pass immediate
      2'd3: Y = A + B;      // stores the addresses (tweaks for future)
    endcase
  end
  assign Z = (Y == 32'd0);
endmodule
