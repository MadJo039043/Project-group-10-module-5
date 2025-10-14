// cpu_top.v
module cpu(
  input         clk,
  input         rst,
  // ... other I/O ...
  output [31:0] debug_rdata
);
  // width matches ADDR_W
  wire        mem_we;
  wire [11:0] mem_addr;    // ADDR_W = 12 → 12-bit word address
  wire [31:0] mem_wdata;
  wire [31:0] mem_rdata;

  // Instance (module name must match definition: data_ram)
  data_ram #(
    .ADDR_W  (12),
    .INIT_HEX("data.hex")
  ) DRAM (
    .clk   (clk),
    .we    (mem_we),
    .addr  (mem_addr),
    .wdata (mem_wdata),
    .rdata (mem_rdata)
  );

  assign debug_rdata = mem_rdata;

  // ... rest of your CPU (PC, ROM, decoder, regfile, etc.) ...

endmodule


