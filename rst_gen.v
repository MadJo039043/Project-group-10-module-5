//Reset Generator
//Developer: 
//For specified clock cycles

module rst_gen #(
    parameter CC_ACTIVE = 32'd100 //should be greater than 1CC
)
(
    input clk,
    output rst,
    output rst_n
);

reg [31:0] count32b = 32'd0;
reg reset_assert = 1'b1;

always@(posedge clk) begin
    if( count32b >= CC_ACTIVE-1 ) begin
        reset_assert <= 1'b0;
    end
    else begin
        reset_assert <= 1'b1;
        count32b <= count32b + 32'd1;
    end
end

assign rst = reset_assert;
assign rst_n = ~reset_assert;

endmodule
