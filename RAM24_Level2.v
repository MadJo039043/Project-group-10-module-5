`timescale 1ns/1ps
module RAM24 #(
    parameter ADDRESS_WIDTH = 14,   // Enough for all our data
    parameter DATA_WIDTH    = 24,

    // Memory map parameters
    parameter X_BASE    = 14'h0000, // Input X_q data starts here
    parameter W_BASE    = 14'h1000, // Weights start here (W1 for Layer 1)
    parameter B_BASE    = 14'h3200, // Biases start here (b1 for Layer 1)
    parameter H_BASE    = 14'h3240, // Hidden layer output area
    parameter W2_BASE   = 14'h3280, // Layer 2 weights start here
    parameter B2_BASE   = 14'h32E0, // Layer 2 biases start here
    parameter Y_BASE    = 14'h3300, // Output Y area

    // Memory init files
    //parameter X_hexcode = "X_q_data.mem",
    parameter W_hexcode  = "W_q_data.mem",
    parameter B_hexcode  = "b_q_data.mem",
    parameter W2_hexcode = "W2_q_data.mem",
    parameter B2_hexcode = "b2_q_data.mem"
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
         ram[1]   = 24'd1;    // Constant 1
         ram[10]  = 24'd10;   // Constant 10
         ram[256] = 24'd256;  // Constant 256
         ram[784] = 24'd784;  // Constant 784

        // Preload weights and biases
                // Load X_q data (784 values)(Images)
        //$readmemh(X_hexcode, ram, X_BASE, X_BASE + 783);
        
        // Load W1 data (256x784 values)(Layer 1 Weights)
        $readmemh(W_hexcode, ram, W_BASE, W_BASE + 200703);
        
        // Load b1 data (256 values)(Layer 1 Biases)
        $readmemh(B_hexcode, ram, B_BASE, B_BASE + 255);
        
        // Load W2 data (10x256 values)(Layer 2 Weights)
        $readmemh(W2_hexcode, ram, W2_BASE, W2_BASE + 2559);
        
        // Load b2 data (10 values)(Layer 2 Biases)
        $readmemh(B2_hexcode, ram, B2_BASE, B2_BASE + 9);
        
        // X input, H hidden, and Y output areas remain runtime-writable
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
                if (addr < 784) begin
                data_out <= {16'b0, ram[addr][10:3]};
                end else begin
                data_out <= ram[addr];
                end
            end
        end
    end

endmodule
