`timescale 1ns/1ps

module tb_cpu24multi;
  // --- user knobs ---
  localparam integer MAX_CYCLES   = 380000;   // safety stop
  localparam PROG_FILE = "program.mem";
  localparam X_FILE    = "X_q_data.mem";
  localparam W_FILE    = "W_q_data.mem";
  localparam B_FILE    = "b_q_data.mem";

  // clock
  reg clk = 1'b0;
  always #5 clk = ~clk;   // 100 MHz

  // DUT
  wire halt;
  wire [2:0] ALUop;
  wire [3:0] opcode;
  wire [9:0] pc;
  wire [23:0] instr;
  wire [23:0] alu_result;


  cpu24multi #(
    .INSTR_HEX (PROG_FILE),
    .DATA_HEX_X(X_FILE),
    .DATA_HEX_W(W_FILE),
    .DATA_HEX_B(B_FILE)
  ) dut (
    .clk  (clk),
    .halt (halt),
    .ALUop (ALUop),
    .opcode (opcode),
    .pc (pc),
    .instr (instr),
    .alu_result (alu_result),
    .Notifier (Notifier)
  );

  // cycle counter
  integer cycles = 0;

  always @(posedge clk) begin
    cycles <= cycles + 1;
 end


    always @(posedge Notifier) begin

        dump_registers();

  end




  // Helper: dump entire regfile (64 x 24)
  task dump_registers;
    integer i;
    begin
    i = 1;
    if (dut.R[i+2] > 8388608) begin 
        $display("%0d = <0", dut.R[i]);
        end else begin
        $display("%0d = 0x%06h (%0d)", dut.R[i], dut.R[i+2], dut.R[i+2]);
        end
    end
  endtask

  // Start banner
  initial begin
    $display("=== tb_cpu24multi: starting simulation ===");
    $display("Program: %s | X:%s | W:%s | B:%s", PROG_FILE, X_FILE, W_FILE, B_FILE);
  end
always @(posedge clk) begin
    if (halt) begin
        dump_registers();   // optional: dump registers on halt
        #1000 $finish;            // stop simulation immediately
    end
end
endmodule
