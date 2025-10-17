`timescale 1ns / 1ps

module system_tb;

    // Parameters
    parameter CLK_PERIOD = 10;    // 10ns = 100MHz
    parameter INSTR_AW = 10;      // From cpu24.v
    parameter DATA_AW = 12;       // From cpu24.v
    parameter IMG_SIZE = 784;     // 28x28 MNIST image
    parameter NUM_WEIGHTS = 7840; // 10x784 weight matrix
    parameter NUM_BIASES = 10;    // 10 output classes
    
    // Test bench signals
    reg clk;
    wire halt;
    reg [23:0] instr_ram [0:(1<<INSTR_AW)-1];
    reg [23:0] data_ram [0:(1<<DATA_AW)-1];
    
    // Memory contents for MNIST
    reg [23:0] image_data [0:IMG_SIZE-1];
    reg [23:0] weight_data [0:NUM_WEIGHTS-1];
    reg [23:0] bias_data [0:NUM_BIASES-1];
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // DUT instantiation with correct ports and parameters
    cpu24 #(
        .INSTR_AW(INSTR_AW),
        .DATA_AW(DATA_AW),
        .INSTR_HEX("program.hex"),
        .DATA_HEX("data.hex")
    ) dut (
        .clk(clk),
        .halt(halt)
    );
    
    // Load test data
    initial begin
        // Load MNIST data
        $readmemh("W_q.txt", weight_data);
        $readmemh("b_q.txt", bias_data);
        $readmemh("X_q.txt", image_data);
        
        // Load program and initial data memory contents
        $readmemh(dut.INSTR_HEX, instr_ram);
        $readmemh(dut.DATA_HEX, data_ram);
        
        // Initialize data memory with MNIST data
        for (integer i = 0; i < IMG_SIZE; i = i + 1)
            data_ram[i] = image_data[i];
            
        for (integer i = 0; i < NUM_WEIGHTS; i = i + 1)
            data_ram[IMG_SIZE + i] = weight_data[i];
            
        for (integer i = 0; i < NUM_BIASES; i = i + 1)
            data_ram[IMG_SIZE + NUM_WEIGHTS + i] = bias_data[i];
    end
    
    // Test sequence
    initial begin
        $display("Starting CPU simulation with MNIST data");
        $display("Program: %s", dut.INSTR_HEX);
        $display("Data: %s", dut.DATA_HEX);
        
        // Wait for halt or timeout
        fork
            begin
                // Timeout after 100000 cycles
                repeat(100000) @(posedge clk);
                $display("Timeout reached at %t", $time);
                $finish;
            end
            begin
                // Wait for halt signal
                @(posedge halt);
                $display("Program halted at %t", $time);
                
                // Read final result from memory
                $display("MNIST Classification Result: %d", data_ram[IMG_SIZE + NUM_WEIGHTS + NUM_BIASES]);
                
                #(CLK_PERIOD * 5);
                $finish;
            end
        join_any
    end
    
    // Debug monitoring
    integer cycle_count = 0;
    always @(posedge clk) begin
        cycle_count = cycle_count + 1;
        
        // Monitor key signals every 1000 cycles
        if (cycle_count % 1000 == 0 || halt) begin
            $display("Cycle: %d", cycle_count);
            $display("Current PC: %h", dut.pc);
            $display("Current Instruction: %h", dut.instr);
            if (halt) begin
                $display("Program halted!");
            end
        end
    end

endmodule