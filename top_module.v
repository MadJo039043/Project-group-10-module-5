`timescale 1ns/1ps

module top_module #(
    parameter FREQ = 50_000_000,
    parameter BAUD = 312_500,
    parameter DATA_WIDTH = 24
)(
    input wire clk,
    input wire rxd,
    output reg [14:0] led
);

    // ------------------------
    // Wires
    // ------------------------
    wire [23:0] bram_dout;
    wire tx_ready, rx_ready;
    wire [7:0] rx_byte;
    wire rst;
    wire halt;

    // ------------------------
    // Reset generator
    // ------------------------
    rst_gen #(
        .CC_ACTIVE(20)
    ) rst_gen_inst (
        .clk(clk),
        .rst(rst),
        .rst_n()
    );

    // ------------------------
    // UART RX
    // ------------------------
    uart_receive #(
        .CLK_FREQUENCY_HZ(FREQ),
        .BAUD_RATE(BAUD)
    ) uart_rx_inst (
        .rst(rst),
        .clk(clk),
        .rxd(rxd),
        .rxd_data(rx_byte),
        .rxd_ready(rx_ready)
    );

    // ------------------------
    // Packet RX FSM
    // ------------------------
    localparam PKT_HEADER = 3'b101;
    localparam delay_cnt = 32'd6400-1;
    localparam PKT_EXPECTED = 32'd784;

    localparam ST_IDLE  = 3'd0,
               ST_BYTE1 = 3'd1,
               ST_BYTE2 = 3'd2,
               ST_CHECK = 3'd3,
               ST_DONE  = 3'd4;

    reg [2:0] fsm_state;
    reg [31:0] cnt32b;
    reg timeout_flag;
    reg receive_done;
    reg [9:0] loc_reg;
    reg [7:0] data_reg;
    reg [2:0] footer_reg;
    reg [23:0] packet_raw;
    reg [31:0] count_packets;
    reg send_done; 

    wire [2:0] footer_calc;
    assign footer_calc[2] = ^data_reg;
    assign footer_calc[1] = ^loc_reg;
    assign footer_calc[0] = ^{data_reg[7:4], loc_reg[9:5]};
    wire packet_ok = (footer_calc == footer_reg);

    // ------------------------
    // UART TX FSM
    // ------------------------
    /*reg [2:0] tx_state;
    reg [1:0] tx_byte_sel;
    reg [23:0] tx_data;
    reg tx_en;
    reg [7:0] tx_byte;  */
    reg [9:0] bram_addr;
    reg [3:0] nn_result;
    reg [15:0] nn_delay_counter;
    localparam NN_PROCESSING_DELAY = 16'd1;

    // ------------------------
    // CPU snapshot array
    // ------------------------
    reg signed [23:0] R3_array [0:9];
    reg [3:0] max_idx;
    reg signed [23:0] max_val;
    
    reg chk_receive_done;
    reg chk_send_done;
    reg chk_instr;
    reg chk_timeout;
    reg chk_cpu_inst;
    reg chk_rx_ready;


    // ------------------------
    // Synchronous reset
    // ------------------------
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Packet FSM
            fsm_state    <= ST_IDLE;
            cnt32b       <= 32'd0;
            timeout_flag <= 1'b0;
            receive_done <= 1'b0;
            loc_reg      <= 10'd0;
            data_reg     <= 8'd0;
            footer_reg   <= 3'd0;
            packet_raw   <= 24'd0;
            count_packets<= 32'd0;
            nn_result        <= 4'd0;
            bram_addr        <= 10'd0;
            nn_delay_counter <= 16'd0;
            chk_receive_done <= 1'b0;


            /* UART TX FSM
            tx_state         <= 3'd0;
            tx_byte_sel      <= 2'd0;
            tx_data          <= 24'd0;
            tx_en            <= 1'b0;
            tx_byte          <= 8'd0;*/

            // CPU snapshots
            max_idx  <= 4'd0;
            max_val  <= 24'd0;
            for (i=0; i<10; i=i+1)
                R3_array[i] <= 24'd0;
        end
        else if(receive_done) chk_receive_done <= 1;
        else begin
            // Packet FSM
            (*parallel_case*)
            case (fsm_state)
                ST_IDLE: begin
                    timeout_flag <= 1'b0;
                    cnt32b <= 32'd0;
                    if (rx_ready && (rx_byte[7:5] == PKT_HEADER)) begin
                        packet_raw[23:16] <= rx_byte;
                        loc_reg[9:5] <= rx_byte[4:0];
                        fsm_state <= ST_BYTE1;
                    end
                    if (count_packets >= PKT_EXPECTED) fsm_state <= ST_DONE;
                end
                ST_BYTE1: begin
                    if (rx_ready) begin
                        packet_raw[15:8] <= rx_byte;
                        loc_reg[4:0] <= rx_byte[7:3];
                        data_reg[7:5] <= rx_byte[2:0];
                        cnt32b <= 32'd0;
                        fsm_state <= ST_BYTE2;
                    end else if (cnt32b == delay_cnt) begin
                        timeout_flag <= 1'b1;
                        cnt32b <= 32'd0;
                        fsm_state <= ST_IDLE;
                    end else
                        cnt32b <= cnt32b + 1;
                end
                ST_BYTE2: begin
                    if (rx_ready) begin
                        packet_raw[7:0] <= rx_byte;
                        data_reg[4:0] <= rx_byte[7:3];
                        footer_reg <= rx_byte[2:0];
                        cnt32b <= 32'd0;
                        fsm_state <= ST_CHECK;
                    end else if (cnt32b == delay_cnt) begin
                        timeout_flag <= 1'b1;
                        cnt32b <= 32'd0;
                        fsm_state <= ST_IDLE;
                    end else
                        cnt32b <= cnt32b + 1;
                end
                ST_CHECK: begin
                    if (packet_ok) begin
                        count_packets <= count_packets + 1;
                        if (count_packets + 1 >= PKT_EXPECTED) begin
                            receive_done <= 1'b1;
                            fsm_state <= ST_DONE;
                        end else begin
                            fsm_state <= ST_IDLE;
                        end
                    end else begin
                        timeout_flag <= 1'b1;
                        fsm_state <= ST_IDLE;
                    end
                end
                ST_DONE: begin
                    receive_done <= 1;
                    if (send_done) begin
                        receive_done <= 0;
                        count_packets <= 32'd0;
                        timeout_flag <= 1'b0;
                        fsm_state <= ST_IDLE;
                    end
                end
            endcase

            /* UART TX FSM
            case (tx_state)
                3'd0: begin
                    send_done <= 0;
                    if (receive_done) begin
                        tx_state <= 3'd1;
                        tx_byte_sel <= 2'd0;
                        bram_addr <= 10'd0;
                    end
                    tx_en <= 0;
                end
                3'd1: tx_state <= 3'd2; // TX_WAIT -> TX_READ
                3'd2: begin // TX_READ
                    tx_data <= bram_dout;
                    tx_state <= 3'd3;
                end
                3'd3: begin // TX_LOAD
                    if (tx_ready) begin
                        case (tx_byte_sel)
                            2'd0: tx_byte <= tx_data[23:16];
                            2'd1: tx_byte <= tx_data[15:8];
                            2'd2: tx_byte <= tx_data[7:0];
                        endcase
                        tx_en <= 1;
                        tx_state <= 3'd4;
                    end
                end
                3'd4: begin // TX_SEND
                    if (tx_byte_sel == 2'd2) begin
                        tx_byte_sel <= 2'd0;
                        bram_addr <= bram_addr + 1;
                        if (bram_addr == PKT_EXPECTED-1) begin
                            send_done <= 1;
                            tx_state <= 3'd0;
                        end else begin
                            tx_state <= 3'd1;
                        end
                    end else begin
                        tx_byte_sel <= tx_byte_sel + 1;
                        tx_state <= 3'd3;
                    end
                    tx_en <= 0;
                end
                3'd5: begin // TX_NN_RESULT
                    if (nn_delay_counter < NN_PROCESSING_DELAY)
                        nn_delay_counter <= nn_delay_counter + 1;
                    else if (tx_ready) begin
                        tx_byte <= 8'd48 + nn_result;
                        tx_en <= 1;
                        send_done <= 1;
                        tx_state <= 3'd0;
                    end 
                end
            endcase */
               
        
       end
    end

    // ------------------------
    // Shared RAM24 (Packet RX + TX + CPU)
    // ------------------------
    wire cpu_ram_we;
    wire [13:0] cpu_ram_addr;
    wire [23:0] cpu_ram_data_in;
    wire [23:0] cpu_ram_data_out;

    wire [13:0] ram_addr = (fsm_state == ST_CHECK && packet_ok) 
                           ? {4'b0000, loc_reg} 
                           : cpu_ram_addr;

    wire [23:0] ram_data_in = (fsm_state == ST_CHECK && packet_ok) 
                              ? packet_raw 
                              : cpu_ram_data_in;

    wire [3:0] ram_we = (fsm_state == ST_CHECK && packet_ok) 
                        ? 4'b1111 
                        : (cpu_ram_we ? 4'b1111 : 4'b0000); 

    RAM24 #(
        .ADDRESS_WIDTH(14),
        .DATA_WIDTH(24)
    ) SHARED_RAM (
        .clk(clk),
        .addr(ram_addr),
        .data_in(ram_data_in),
        .we(ram_we),
        .en(1'b1),
        .data_out(bram_dout)
    );

    assign cpu_ram_data_out = bram_dout;

    // ------------------------
    // UART TX
    // ------------------------
    //uart_send #(
    //    .CLK_FREQUENCY_HZ(FREQ),
    //    .BAUD_RATE(BAUD)
    //) uart_tx_inst (
    //    .rst(rst),
    //    .clk(clk),
    //    .din(tx_byte),
    //    .en(tx_en),
    //    .txd(txd),
    //    .txd_ready(tx_ready)
    //);

    // ------------------------
    // CPU instance
    // ------------------------
    wire [3:0] R3_idx;
    cpu24multi cpu_inst(
        .clk(clk),
        .rst(rst),
        .receive_done(receive_done),
        .alu_result(),
        .ALUop(),
        .pc(),
        .data_out(),
        .Notifier(),
        .mem_we_ext(cpu_ram_we),
        .mem_addr_ext(cpu_ram_addr),
        .mem_data_in_ext(cpu_ram_data_in),
        .mem_data_out_ext(cpu_ram_data_out),
        .halt(halt),
        .count_packets(),
        .R3_idx(R3_idx)
    );



   
// ------------------------
// Checklist signals
// ------------------------

always @(posedge clk) begin
led[2:0] <= cpu_inst.state;
led[9:3] <= count_packets;
led[13:10] <= R3_idx;
led[14]    <= chk_receive_done;
end



endmodule
