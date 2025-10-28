    `timescale 1ns/1ps
    
    module tb_cpu24multi;
    
      // -----------------------------
      // Parameters
      // -----------------------------
      localparam integer MAX_CYCLES = 4000000;
      localparam PROG_FILE = "program.mem";
      localparam X_FILE    = "X_q_data.mem";
      localparam W_FILE    = "W_q_data.mem";
      localparam B_FILE    = "b_q_data.mem";
    
      // -----------------------------
      // Clock and Reset
      // -----------------------------
      reg clk = 0;
      always #5 clk = ~clk;   // 100 MHz
      reg rst = 1;
    
      initial begin
        #20 rst = 0;  // release reset after a short delay
      end
    
      // -----------------------------
      // Wires between CPU and RAM
      // -----------------------------
      wire        mem_we;
      wire [13:0] mem_addr;
      wire [23:0] mem_din;
      wire [23:0] mem_dout;
    
      // -----------------------------
      // CPU instance
      // -----------------------------
      wire halt;
      wire [2:0] ALUop;
      wire [3:0] opcode;
      wire [9:0] pc;
      wire [23:0] instr;
      wire [23:0] alu_result;
      wire Notifier;
      wire [23:0] A;
      wire [23:0] B;
      wire [23:0] Y;
assign A = dut.ALU_A;
assign B = dut.ALU_B;
assign Y = dut.ALU_Y;

      wire [23:0] R3_snapshot [0:9];
      assign R3_snapshot [0] = dut.R3_snapshot [0];
      assign R3_snapshot [1] = dut.R3_snapshot [1];
      assign R3_snapshot [2] = dut.R3_snapshot [2];
      assign R3_snapshot [3] = dut.R3_snapshot [3];
      assign R3_snapshot [4] = dut.R3_snapshot [4];
      assign R3_snapshot [5] = dut.R3_snapshot [5];
      assign R3_snapshot [6] = dut.R3_snapshot [6];
      assign R3_snapshot [7] = dut.R3_snapshot [7];
      assign R3_snapshot [8] = dut.R3_snapshot [8];
      assign R3_snapshot [9] = dut.R3_snapshot [9];


      reg [31:0] Counter;
      initial Counter = 0;
      always @(posedge clk) begin
        Counter <= Counter + 1;
        end
    
      cpu24multi #(
        .INSTR_HEX (PROG_FILE),
        .DATA_HEX_X(X_FILE),
        .DATA_HEX_W(W_FILE),
        .DATA_HEX_B(B_FILE)
      ) dut (
        .clk(clk),
        .rst(rst),
    
        // external memory bus
        .mem_we_ext(mem_we),
        .mem_addr_ext(mem_addr),
        .mem_data_in_ext(mem_din),
        .mem_data_out_ext(mem_dout),
    
        // debug outputs
        .alu_result(alu_result),
        .ALUop(ALUop),
        .opcode(opcode),
        .pc(pc),
        .instr(instr),
        .data_out(),
        .Notifier(Notifier),
        .halt(halt)
      );
    
      // -----------------------------
      // RAM instance (shared memory)
      // -----------------------------
      RAM24 #(
        .ADDRESS_WIDTH(14),
        .DATA_WIDTH(24),
        .X_hexcode(X_FILE),
        .W_hexcode(W_FILE),
        .B_hexcode(B_FILE)
      ) main_mem (
        .clk(clk),
        .we(mem_we ? 4'b1111 : 4'b0000),  // CPU controls write
        .addr(mem_addr),
        .data_in(mem_din),
        .en(1'b1),
        .data_out(mem_dout)
      );
    

        // -----------------------------
        // Monitor opcode and print R[8]
        // -----------------------------
reg [2:0] cycle_count = 3'd0; // 3-bit counter (0-4)

    
  

      always @(posedge Notifier) dump_registers();

    
      // -----------------------------
      // Helper: Dump CPU register file contents
      // -----------------------------
      task dump_registers;
        integer i;
        begin
          for (i = 1; i < 4; i = i + 2) begin
            $display("R[%0d] = 0x%06h (%0d)", i, dut.R[i], dut.R[i]);
          end
        end
      endtask
      
      always @(posedge halt) begin
      dump_registers();
      end
      

    
    endmodule
