`timescale 1ns / 1ps

module pc #(
  parameter PC_W = 10
)(
  input                  clk,
  input                  halt,          //, HALT
  input                  branch,   // Branch && condition
  input                  jump,
  input      [PC_W-1:0]  br_off,        // branch offset (already sign-ext & sliced)
  input      [PC_W-1:0]  jmp_off,       // jump   offset (already sign-ext & sliced)
  output reg [PC_W-1:0]  pc
);
wire [PC_W-1:0] pc_plus_1 = pc +1'b1;
 wire [PC_W-1:0] pc_branch = pc_plus_1 + br_off;
  wire [PC_W-1:0] pc_jump   = pc_plus_1 + jmp_off;

  wire [PC_W-1:0] next_pc =
      halt        ? pc :
      jump   ? pc_jump :
      branch ? pc_branch :
                    pc_plus_1;
endmodule
