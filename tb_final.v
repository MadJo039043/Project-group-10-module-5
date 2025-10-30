`timescale 1ns/1ps
module tb_full_system;

  // ======================================================
  // SIMULATION PARAMETERS
  // ======================================================
  localparam CLK_FREQ   = 50_000_000;   // 100 MHz
  localparam BAUD_RATE  = 312_500;
  localparam CLK_PERIOD = 20;            // ns
  localparam BIT_PERIOD = 1_000_000_000 / BAUD_RATE; // ~1600 ns per UART bit

  localparam X_FILE    = "X_q_data.mem";
  localparam PROG_FILE = "program.mem";
  localparam W_FILE    = "W_q_data.mem";
  localparam B_FILE    = "b_q_data.mem";
  localparam integer NUM_PIXELS = 785;

  // ======================================================
  // CLOCK AND RESET
  // ======================================================
  reg clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  reg rst = 1;
  initial #200 rst = 0;

  // ======================================================
  // UART INTERFACE
  // ======================================================
  reg rxd = 0;
  //wire txd;
  wire [14:0] led;
  wire receive_done;
  wire cpu_done = dut.cpu_inst.cpu_done;
  reg [2:0] state;
  reg [2:0] nstate;
  reg R3_idx = dut.cpu_inst.R3_idx;
  wire [31:0] count_packets = dut.count_packets;
always @(posedge clk) begin
  state <= dut.cpu_inst.state;
  nstate <= dut.cpu_inst.nstate;
end
  //wire [3:0] uart_cnt_4b;
  //assign uart_cnt_4b = dut.uart_tx_inst.cnt_4b;
  //wire [31:0] counter_baud;
  //assign counter_baud = dut.uart_tx_inst.counter_baud;




  // ======================================================
  // TOP MODULE
  // ======================================================
  top_module #(
    .FREQ(CLK_FREQ),
    .BAUD(BAUD_RATE)
  ) dut (
    .clk(clk),
    .rxd(rxd),
    .led(led)
  );

  assign receive_done = dut.receive_done;
  assign send_done    = dut.send_done;
  
  cpu24multi #(
        .DATA_HEX_W(W_FILE),
        .DATA_HEX_B(B_FILE)
      ) cpu_inst (
        .clk(clk),
        .rst(rst)
      );
      
  wire halt     = dut.cpu_inst.halt;
  wire [9:0] pc = dut.cpu_inst.pc;
  wire [3:0] opcode = dut.cpu_inst.opcode;
 /* wire [2:0] ALUop = dut.cpu_inst.ALUop;
  wire [23:0] alu_result = dut.cpu_inst.alu_result;*/
  wire Notifier = dut.cpu_inst.Notifier;
  wire [3:0] nn_result = dut.nn_result;
  // ======================================================
  // CPU INTERNAL SIGNALS
  // ======================================================
  
  // -----------------------------
// Access CPU R3_snapshot
// -----------------------------
wire [23:0] cpu_R3_snap_0  = dut.cpu_inst.R3_snapshot[0];
wire [23:0] cpu_R3_snap_1  = dut.cpu_inst.R3_snapshot[1];
wire [23:0] cpu_R3_snap_2  = dut.cpu_inst.R3_snapshot[2];
wire [23:0] cpu_R3_snap_3  = dut.cpu_inst.R3_snapshot[3];
wire [23:0] cpu_R3_snap_4  = dut.cpu_inst.R3_snapshot[4];
wire [23:0] cpu_R3_snap_5  = dut.cpu_inst.R3_snapshot[5];
wire [23:0] cpu_R3_snap_6  = dut.cpu_inst.R3_snapshot[6];
wire [23:0] cpu_R3_snap_7  = dut.cpu_inst.R3_snapshot[7];
wire [23:0] cpu_R3_snap_8  = dut.cpu_inst.R3_snapshot[8];
wire [23:0] cpu_R3_snap_9  = dut.cpu_inst.R3_snapshot[9];

 /*   wire [13:0] ram_addr = top_module.ram_addr;
    wire [23:0] ram_data_in = top_module.ram_data_in;
    wire [3:0] ram_we = top_module.ram_we;
    
      wire [23:0] A;
      wire [23:0] B;
      wire [23:0] Y;
assign A = dut.cpu_inst.ALU0.A;
assign B = dut.cpu_inst.ALU0.B;
assign Y = dut.cpu_inst.ALU0.Y;*/
    wire [23:0] instr = dut.cpu_inst.instr;


  // ======================================================
  // LOAD IMAGE DATA
  // ======================================================
  reg [7:0] X_data [0:NUM_PIXELS-1];
  initial begin
    $readmemh(X_FILE, X_data);
    $display("Loaded %0d image pixels from %s", NUM_PIXELS, X_FILE);
  end


  
  // ======================================================
  // UART SEND TASK
  // ======================================================
  task uart_send_byte(input [7:0] data);
    integer i;
    begin
      rxd <= 0; #(BIT_PERIOD); // start bit
      for (i = 0; i < 8; i=i+1) begin
        rxd <= data[i];
        #(BIT_PERIOD);
      end
      rxd <= 1; #(BIT_PERIOD); // stop bit
      #(BIT_PERIOD/2);
    end
  endtask

  // ======================================================
  // FOOTER CALCULATION FUNCTION
  // ======================================================
  function [2:0] calc_footer;
    input [7:0] data;
    input [9:0] loc;
    begin
      calc_footer[2] = ^data;
      calc_footer[1] = ^loc;
      calc_footer[0] = ^{data[7:4], loc[9:5]};
    end
  endfunction

  // ======================================================
  // SEND PACKETS VIA UART (MSB-first)
  // ======================================================
  integer n;
  reg [9:0] loc;
  reg [7:0] data8;
  reg [2:0] footer;
  reg [23:0] packet24;
  reg [7:0] byte0, byte1, byte2;

  initial begin
    @(negedge rst);
    #5000;
    $display("=== UART TRANSMISSION START ===");

    for (n = 0; n < NUM_PIXELS; n = n + 1) begin
      loc = n[9:0];
      data8 = X_data[n];
      footer = calc_footer(data8, loc);

      packet24 = {3'b101, loc, data8, footer}; // H(3)+Loc(10)+Data(8)+F(3)
      byte0 = packet24[23:16];
      byte1 = packet24[15:8];
      byte2 = packet24[7:0];

    

      uart_send_byte(byte0);
      uart_send_byte(byte1);
      uart_send_byte(byte2);
    end
    $display("=== UART TRANSMISSION COMPLETE ===");
  end
  
  // ======================================================
  // CPU REGISTER MONITOR
  // ======================================================
  integer cycles = 0;
  reg notifier_prev = 0;


  task dump_registers;
    integer i;
    begin
      for (i = 2; i < 4; i = i + 4) begin
        $display("R[%0d] = (%0d) (%0d)", i, dut.cpu_inst.R[2], dut.cpu_inst.R[9]);
      end
    end
  endtask

  always @(posedge clk) begin
    if (opcode == 7) dump_registers();
    end

  // ======================================================
  // SIMULATION CONTROL
  // ======================================================
  initial begin
    $dumpfile("tb_full_system.vcd");
    $dumpvars(0, tb_full_system);
    #100_000_000;
    $finish;
  end
  

endmodule
