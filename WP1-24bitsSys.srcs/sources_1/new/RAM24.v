`timescale 1ns/1ps
module RAM24 #(
    parameter ADDRESS_WIDTH = 14,  // Enough for all our data
    parameter DATA_WIDTH = 24,
    // Memory map parameters
    parameter X_BASE    = 14'h0000, // X_q data starts at 0x0000
    parameter W_BASE    = 14'h0310, // W_q data starts at 0x1000
    parameter B_BASE    = 14'h21B0, // b_q data starts at 0x2EA0
    parameter Y_BASE    = 14'h21BA,  // Y output starts at 0x3000
    parameter X_hexcode = "X_q_data.hex",
    parameter W_hexcode = "W_q_data.hex",
    parameter B_hexcode = "b_q_data.hex"
)(
    input                          clk,
    input                          we,         // write enable
    input      [ADDRESS_WIDTH-1:0] addr,      // address in words
    input      [DATA_WIDTH-1:0]    data_in,   // data to write
    output reg [DATA_WIDTH-1:0]    data_out   // data to read
);

    // Memory array
    reg [DATA_WIDTH-1:0] ram [0:(1<<ADDRESS_WIDTH)-1];

    // Initialize memory with constants and input data
    initial begin
        // Initialize constants
        ram[1]   = 24'd1;    // Constant 1
        ram[10]  = 24'd10;   // Constant 10
        ram[784] = 24'd784;  // Constant 784

        // Load X_q data (784 values)(Images)
        $readmemh(X_hexcode, ram, X_BASE, X_BASE + 783);
        
        // Load W_q data (10x784 values)(Weights)
        $readmemh(W_hexcode, ram, W_BASE, W_BASE + 7839);
        
        // Load b_q data (10 values)(Biasis)
        $readmemh(B_hexcode, ram, B_BASE, B_BASE + 9);

        // Y output area is left uninitialized (will be written during execution)
    end

    // Synchronous write, asynchronous read
    always @(posedge clk) begin
        if (we)
            ram[addr] <= data_in;
        data_out <= ram[addr];
    end
endmodule