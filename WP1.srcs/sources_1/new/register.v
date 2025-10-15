`timescale 1ns / 1ps
module register (
input clk,
input [2:0] rs1 , rs2, rd,
input RegWrite, //when is 1 write the selected data into rd
input [31:0] wdata, // the data that you store in rd when we is 1
output [31:0] r1,r2 // the busses that come out from rs1 and rs2 and go into ALU
    );
    reg counter;
    reg sum;
    // 8 registers that are 32 bits each
    reg[31:0] R [7:0];
    assign r1 = R[rs1];
    assign r2 = R[rs2];
    
     always @(posedge clk)
      begin
    if (RegWrite) begin
    if (rd == 3'd0) begin
    R[0] <= 32'd0;
    end
    else begin
    R[rd] <= wdata;
    end
    end
    end
    
    
endmodule
