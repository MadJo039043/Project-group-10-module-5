`timescale 1ns/1ps
module Ram #(
  parameter address_parameter = 12,  //1960 words-weights, 196 words- image 
  parameter hexcode = "data.hex"   // initialize the hexcode into Vivado 
)
(
  input              clk,
  input              we,   //write enable
  input  [address_parameter-1:0] addr, //address_parameter in words
  input  [31:0]       data_in, //where you write
  output reg [31:0]   data_out //where you read
);

  reg [31:0] ram_blk [0:(1<<address_parameter)-1];
  // Synchronizer for we
reg we_ff1, we_ff2;
wire we_sync;
assign we_sync = we_ff2;

  initial begin
      $display("Initializing data RAM: %s", hexcode);
      $readmemh(hexcode, ram_blk);
    end
// Double-flopping logic
always @(posedge clk) begin 
        we_ff1 <= we;
        we_ff2 <= we_ff1;
    end
  // synchronous write, synchronous read (1-cycle latency)
  always @(posedge clk) begin
    if (we_sync)
     ram_blk[addr] <= data_in;
    data_out <= ram_blk[addr];
  end

endmodule
