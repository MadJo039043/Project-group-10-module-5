`timescale 1ns/1ps
module instr_ROM24 #(
  parameter address_parameter = 10      // 1024 words
)(
  input  wire clk,
  input  [address_parameter-1:0] addr,
  output reg [23:0] instr
);

  reg [23:0] rom [0:(1<<address_parameter)-1];
  integer i;
  initial begin
    // Hardcoded program
    rom[0]  = 24'h900400;
    rom[1]  = 24'hA10400;
    rom[2]  = 24'h900510;
    rom[3]  = 24'hA14500;
    rom[4]  = 24'h90062E;
    rom[5]  = 24'hA186A0;
    rom[6]  = 24'h900730;
    rom[7]  = 24'hA1C700;
    rom[8]  = 24'hA00901;
    rom[9]  = 24'hA00A0A;
    rom[10] = 24'h900B03;
    rom[11] = 24'hA2CB10;
    rom[12] = 24'h100004;
    rom[13] = 24'h118120;
    rom[14] = 24'h520300;
    rom[15] = 24'h304B20;
    rom[16] = 24'h120520;
    rom[17] = 24'h100008;
    rom[18] = 24'h120230;
    rom[19] = 24'h530C00;
    rom[20] = 24'h110234;
    rom[21] = 24'h534D00;
    rom[22] = 24'h330D38;
    rom[23] = 24'h10CE0C;
    rom[24] = 24'h108908;
    rom[25] = 24'h708B1B;
    rom[26] = 24'h800012;
    rom[27] = 24'h11C120;
    rom[28] = 24'h620300;
    rom[29] = 24'h104904;
    rom[30] = 24'h704A20;
    rom[31] = 24'h80000D;
    rom[32] = 24'h51F700;
    rom[33] = 24'h11C91C;
    rom[34] = 24'h51F800;
    rom[35] = 24'h11C91C;
    rom[36] = 24'h51F900;
    rom[37] = 24'h11C91C;
    rom[38] = 24'h51FA00;
    rom[39] = 24'h11C91C;
    rom[40] = 24'h51FB00;
    rom[41] = 24'h11C91C;
    rom[42] = 24'h51FC00;
    rom[43] = 24'h11C91C;
    rom[44] = 24'h51FD00;
    rom[45] = 24'h11C91C;
    rom[46] = 24'h51FE00;
    rom[47] = 24'h11C91C;
    rom[48] = 24'h51CA00;
    rom[49] = 24'h11C91C;
    rom[50] = 24'h51C000;
    rom[51] = 24'h000000;
    rom[52] = 24'h000000;

    // Fill remaining ROM with NOP/HALT

    for (i = 53; i < (1<<address_parameter); i = i + 1)
      rom[i] = 24'h000000;
  end

  always @(posedge clk) begin
    instr <= rom[addr];
  end

endmodule
