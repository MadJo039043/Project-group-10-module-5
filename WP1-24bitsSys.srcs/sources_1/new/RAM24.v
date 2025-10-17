`timescale 1ns/1ps
module RAM24 #(
  parameter address_parameter = 12,  //1960 words-weights, 196 words- image 
  parameter hexcode = "data.mem"   // initialize the hexcode into Vivado 
)
(
  input              clk,
  input              we,   //write enable
  input  [address_parameter-1:0] addr, //address_parameter in words
  input  [23:0]       data_in, //where you write
  output reg [23:0]   data_out //where you read
);

  reg [23:0] ram_blk [0:(1<<address_parameter)-1];

  initial begin
      $display("Initializing data RAM: %s", hexcode);
      $readmemh(hexcode, ram_blk);
    end

  always @(posedge clk) begin
    if (we)
     ram_blk[addr] <= data_in;
    data_out <= ram_blk[addr];
  end

endmodule