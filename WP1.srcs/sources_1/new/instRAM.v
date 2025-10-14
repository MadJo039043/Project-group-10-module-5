instRAM #(.ADDR_W(12), .INIT_HEX("data.hex")) DRAM (
  .clk   (clk),
  .we    (mem_we),
  .addr  (mem_addr),   // word address from your CPU
  .wdata (mem_wdata),
  .rdata (mem_rdata)
);

    );
endmodule
