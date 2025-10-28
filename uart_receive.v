//UART Receive (RX)
//Developer: 
//BaudCount = [Clock_Frequency / (Baud_Rate*16)]-1  (Ideally clock frequency should be multiple of baurd_rate to avoid clock related glitches)

module uart_receive #(
    parameter CLK_FREQUENCY_HZ = 100_000_000,
    parameter BAUD_RATE = 1_562_500
)
(
    input rst,
    input clk,
    input rxd,
    output reg [7:0] rxd_data = 8'd0,
    output reg rxd_ready = 1'b0
);

localparam  SM_IDLE = 3'd0,
            SM_START = 3'd1,
            SM_RX = 3'd2,
            SM_RX_1 = 3'd3,
            SM_STOP_CHK = 3'd4;

localparam div_count = 16;  //Number of time_slots to divide one Tbit duration
reg [31:0] baud_count = (CLK_FREQUENCY_HZ/(BAUD_RATE*div_count))-1; // clock divider value
//
reg [31:0] baud_counter = {32{1'b0}};
wire tbit_div_tick;
//
reg [2:0] rxd_sampler = 3'b111;
wire falledge_startbit;
//
reg [3:0] bit_duration_counter = 4'd0;
wire tbit_sampling_cond;
wire tbit_75percent_cond;
wire tbit_done_cond;
//
reg rxd_bit_error = 1'b0;
reg rxd_bit = 1'b0;
//
reg [2:0] fsm_tx = SM_IDLE;
reg [3:0] cnt_4b = 4'd0;
reg [7:0] rxd_temp = 8'd0;

//------------------------------------------

always@(posedge clk) begin
    if(rst || tbit_div_tick) 
        baud_counter <= {32{1'b0}};
    else
        baud_counter <= baud_counter + 32'd1;
end

assign tbit_div_tick = (baud_counter == baud_count)? 1'b1: 1'b0;

//------------------------------------------

always@(posedge clk) begin
    if(rst) 
        rxd_sampler <= 3'b111;
    else if(tbit_div_tick)
        rxd_sampler <= {rxd_sampler[1:0], rxd};
end

assign falledge_startbit = rxd_sampler[2] & (~rxd_sampler[1]) ? 1'b1: 1'b0;

//------------------------------------------

always @(posedge clk) begin
    if(rst || fsm_tx==SM_IDLE) begin
        bit_duration_counter <= 4'd0;
    end
    else if(tbit_div_tick) begin
        bit_duration_counter <= bit_duration_counter + 4'd1;
    end
end

assign tbit_sampling_cond   = (bit_duration_counter == 4'd10);
assign tbit_75percent_cond  = (bit_duration_counter == 4'd11);
assign tbit_done_cond       = (bit_duration_counter == 4'd15);

//------------------------------------------

always @(posedge clk) begin
  if (rst) begin
    rxd_bit_error <= 1'b0;
    rxd_bit <= 1'b0;
  end
  else if (tbit_sampling_cond & tbit_div_tick) begin
    case (rxd_sampler)
    3'b000:  begin rxd_bit_error <= 1'b0; rxd_bit <= 1'b0; end  //Ok
    3'b001:  begin rxd_bit_error <= 1'b1; rxd_bit <= 1'b0; end  //Error 
    3'b010:  begin rxd_bit_error <= 1'b1; rxd_bit <= 1'b0; end  //Error (majority count)
    3'b011:  begin rxd_bit_error <= 1'b1; rxd_bit <= 1'b1; end  //Error
    3'b100:  begin rxd_bit_error <= 1'b1; rxd_bit <= 1'b0; end  //Error
    3'b101:  begin rxd_bit_error <= 1'b1; rxd_bit <= 1'b1; end  //Error
    3'b110:  begin rxd_bit_error <= 1'b1; rxd_bit <= 1'b1; end  //Error
    3'b111:  begin rxd_bit_error <= 1'b0; rxd_bit <= 1'b1; end  //Ok
    endcase
  end
end

//------------------------------------------

always@(posedge clk) begin

    if(rst) begin
        fsm_tx <= SM_IDLE;
        cnt_4b <= 4'd0;
        rxd_temp <= 8'd0;
        rxd_data <= 8'd0;
        rxd_ready <= 1'b0;
    end
    else begin
        
        (*parallel_case*)
        case(fsm_tx)

            SM_IDLE: begin
                rxd_ready <= 1'b0;
                if(falledge_startbit) begin
                    fsm_tx <= SM_START;
                    cnt_4b <= 4'd0;
                    rxd_temp <= 8'd0;
                end
            end

            SM_START: begin
                if(tbit_75percent_cond & tbit_div_tick & (rxd_bit_error || rxd_bit)) begin
                    fsm_tx <= SM_IDLE;
                end
                else if(tbit_done_cond & tbit_div_tick) begin
                    fsm_tx <= SM_RX;
                end
            end
            
            SM_RX: begin
                if(tbit_75percent_cond & tbit_div_tick) begin
                    fsm_tx <= SM_RX_1;
                    rxd_temp <= {rxd_bit, rxd_temp[7:1]};
                end
            end

            SM_RX_1: begin
                if(tbit_done_cond & tbit_div_tick)begin
                    //
                    if( cnt_4b >= 4'd7 ) begin
                        fsm_tx <= SM_STOP_CHK;
                        cnt_4b <= 4'd0;
                    end
                    else begin
                        fsm_tx <= SM_RX;
                        cnt_4b <= cnt_4b + 4'd1;  
                    end
                end
            end

            SM_STOP_CHK: begin
                if(tbit_75percent_cond & tbit_div_tick)begin
                    fsm_tx <= SM_IDLE;
                    if( ~rxd_bit_error & rxd_bit ) begin
                        rxd_data <= rxd_temp;
                        rxd_ready <= 1'b1;
                    end
                end
            end

            default: begin
                fsm_tx <= SM_IDLE;
                cnt_4b <= 4'd0;
                rxd_temp <= 8'd0;
                rxd_data <= 8'd0;
                rxd_ready <= 1'b0;
            end

        endcase    
    end    

end

endmodule
