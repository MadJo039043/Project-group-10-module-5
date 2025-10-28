`timescale 1ns/1ps
module RAM24 #(
    parameter ADDRESS_WIDTH = 14,   // Enough for all our data
    parameter DATA_WIDTH    = 24,

    // Memory map parameters
    parameter X_BASE    = 14'h0000, // Input X_q data starts here
    parameter W_BASE    = 14'h1000, // Weights start here
    parameter B_BASE    = 14'h2EA0, // Biases start here
    parameter Y_BASE    = 14'h3000, // Output Y area

    // Memory init files
    parameter X_hexcode = "X_q_data.mem",
    parameter W_hexcode = "W_q_data.mem",
    parameter B_hexcode = "b_q_data.mem"
)(
    input                          clk,
    input      [3:0]               we,         // write enable (1 bit per byte)
    input      [ADDRESS_WIDTH-1:0] addr,       // address
    input      [DATA_WIDTH-1:0]    data_in,    // data to write
    input                          en,         // enable
    output reg [DATA_WIDTH-1:0]    data_out    // data to read
);

    // ---------------------------
    // Internal BRAM
    // ---------------------------
    reg [DATA_WIDTH-1:0] ram [0:(1<<ADDRESS_WIDTH)-1];

    // ---------------------------
    // Initialization (optional)
    // ---------------------------
            integer i;
    initial begin
        for (i = 0; i < (1<<ADDRESS_WIDTH); i = i + 1)
            ram[i] = {DATA_WIDTH{1'b0}};

        // Basic constants
        // ram[1]   = 24'd1;    // Constant 1
        // ram[10]  = 24'd10;   // Constant 10
        // ram[784] = 24'd784;  // Constant 784

        // Preload weights and biases
                // Load X_q data (784 values)(Images)
        // $readmemh(X_hexcode, ram, X_BASE, X_BASE + 783);
        
        // Load W_q data (10x784 values)(Weights)
        $readmemh(W_hexcode, ram, W_BASE, W_BASE + 7839);
        
        // Load b_q data (10 values)(Biasis)
        $readmemh(B_hexcode, ram, B_BASE, B_BASE + 9);
  // 10 biases
        // X input & Y output areas remain runtime-writable
    end

    // ---------------------------
    // Synchronous Write-First Logic
    // ---------------------------
    always @(posedge clk) begin
        if (en) begin
            if (&we) begin
                // Write and immediately return new value (write-first)
                ram[addr] <= data_in;
                data_out  <= data_in;
            end else begin
                // Read only
                data_out <= ram[addr];
            end
        end
    end

endmodule
