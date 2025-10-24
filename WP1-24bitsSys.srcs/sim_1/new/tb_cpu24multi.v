`timescale 1ns/1ps

module tb_cpu24multi;
  // --- user knobs ---
  localparam integer MAX_CYCLES   = 20000;   // safety stop
localparam PROG_FILE = "program.mem";
localparam X_FILE    = "X_q_data.mem";
localparam W_FILE    = "W_q_data.mem";
localparam B_FILE    = "b_q_data.mem";


  // clock
  reg clk = 1'b0;
  always #5 clk = ~clk;   // 100 MHz

  // DUT
  wire halt;
  cpu24multi #(
    .INSTR_HEX (PROG_FILE),
    .DATA_HEX_X(X_FILE),
    .DATA_HEX_W(W_FILE),
    .DATA_HEX_B(B_FILE)
  ) dut (
    .clk  (clk),
    .halt (halt)
  );
  always @(posedge clk) begin
  if (dut.state == 2)  // during EXEC
    $display("EXEC: ALUop=%b A=%0d B=%0d -> Y=%0d", dut.ALUop, dut.A, dut.B, dut.ALU0.Y);
end
always @(posedge clk)begin
  if (dut.IRwe)
    $display("FETCH: PC=%0d INSTR=%h", dut.pc, dut.instr);
end


  // cycle counter + run control
  integer cycles = 0;
  reg saw7 = 0;

  // Pretty print on each register write-back
  // (These nets exist inside your CPU and can be probed hierarchically.)
  //   dut.dest   : destination register index
  //   dut.wb     : value written back
  //   dut.pc     : program counter
  //   dut.state  : FSM state (0..5)
  // If your tool complains about any of these, just comment that line out.
  always @(posedge clk) begin
    cycles <= cycles + 1;

    if (dut.RegWrite) begin
      $display("[%0t] WB: R[%0d] <= 0x%06h (%0d)  PC=%0d  state=%0d",
               $time, dut.dest, dut.wb, dut.wb, dut.pc, dut.state);
      if (dut.wb == 24'd7) saw7 <= 1;
    end

    if (halt) begin
      $display("\n*** HALT asserted at cycle %0d (time %0t) ***\n", cycles, $time);
      dump_registers();
      report_result_and_finish();
    end

    if (cycles >= MAX_CYCLES) begin
      $display("\n*** TIMEOUT after %0d cycles ***\n", cycles);
      dump_registers();
      report_result_and_finish();
    end
  end

  // Helper: dump entire regfile (64 x 24)
  task dump_registers;
    integer i;
    begin
      $display("---- Register File Dump (R[0..63]) ----");
      for (i = 0; i < 64; i = i + 1) begin
        $display("R[%0d] = 0x%06h (%0d)", i, dut.R[i], dut.R[i]);
      end
      $display("---------------------------------------\n");
    end
  endtask

  // Helper: final report
  task report_result_and_finish;
    integer i;
    begin
      // also scan regs for value 7, in case write-back print was missed
      if (!saw7) begin
        for (i = 0; i < 64; i = i + 1)
          if (dut.R[i] == 24'd7) saw7 = 1;
      end

      if (saw7)
        $display("✅ TEST PASS: value 7 was produced somewhere in the CPU.");
      else
        $display("❌ TEST FAIL: value 7 never appeared in any register.");

      // (Optional) If you know the result lives in data memory at a fixed address,
      // uncomment ONE of the two lines below depending on your RAM implementation:
      // $display("DMEM[addr]=%0d", dut.DMEM.ram[12'h300]);     // if RAM array name is 'ram'
      // $display("DMEM[addr]=%0d", dut.DMEM.ram_blk[12'h300]); // if RAM array name is 'ram_blk'

      $finish;
    end
  endtask

  // Start banner
  initial begin
    $display("=== tb_cpu24multi: starting simulation ===");
    $display("Program: %s | X:%s | W:%s | B:%s", PROG_FILE, X_FILE, W_FILE, B_FILE);
  end

endmodule
