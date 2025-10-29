`timescale 1ns/1ps
module instr_ROM24 #(
  parameter address_parameter = 10,     // 1024 words
  parameter hexcode = "program.mem"
)(
  input                   clk,
  input  [address_parameter-1:0]     addr,    //10 bit address_parameter 
  output reg [23:0]       instr
);

  reg [23:0] rom [0:(1<<address_parameter)-1];

initial begin
  $display("=== Attempting to load: %s ===", hexcode);
  $readmemh(hexcode, rom);
  $display("=== Finished loading ===");
  #1; // small delay so rom updates
  $display("ROM[0]=%h  ROM[1]=%h", rom[0], rom[1]);
end


  always @(posedge clk) begin
    instr = rom[addr];
  end

endmodule