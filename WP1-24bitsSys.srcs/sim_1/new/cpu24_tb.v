`timescale 1ns / 1ps

module cpu24_tb;
    // Parameters
    parameter CLK_PERIOD = 10;  // 10ns = 100MHz
    parameter INSTR_AW = 10;    // Match CPU parameters
    parameter DATA_AW = 12;

    // Parameters
    
    // Test signals
    reg clk;
    wire halt;  // Should be wire since it's an output from the CPU
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Instantiate CPU with correct parameters
    cpu24 #(
        .INSTR_AW(INSTR_AW),
        .DATA_AW(DATA_AW),
        .INSTR_HEX("C:/Users/david/Downloads/MNIST_UART-main/MNIST_UART-main/WP1-24bitsSys.srcs/sources_1/new/program.mem"),
        .DATA_HEX("C:/Users/david/Downloads/MNIST_UART-main/MNIST_UART-main/WP1-24bitsSys.srcs/sources_1/new/data.mem")
    ) dut (
        .clk(clk),
        .halt(halt)
    );
    
    // Connect monitoring signals
    assign current_instr = dut.instr;
    assign pc = dut.pc;
    assign alu_result = dut.alu_result;
    assign data_addr = dut.data_addr;
    assign data_read = dut.data_read;
    assign data_write = dut.data_write;
    assign data_wen = dut.data_wen;
    
    // Memory access monitor
    reg [23:0] max_activation;
    reg [3:0] predicted_digit;
    
    always @(posedge clk) begin
        if (data_wen) begin
            // Monitor writes to result area
            if (data_addr >= RESULT_ADDR && data_addr < RESULT_ADDR + NUM_CLASSES) begin
                if (data_write > max_activation) begin
                    max_activation = data_write;
                    predicted_digit = data_addr - RESULT_ADDR;
                end
            end
        end
    end
    
    // Test sequence
    initial begin
        // Initialize monitoring variables
        max_activation = 0;
        predicted_digit = 0;
        
        $display("Starting MNIST inference test at time %0t", $time);
        $display("Parameters:");
        $display("  Image size: %0d pixels", IMG_SIZE);
        $display("  Number of classes: %0d", NUM_CLASSES);
        $display("  Weight matrix: %0d x %0d", NUM_CLASSES, IMG_SIZE);
        $display("Memory map:");
        $display("  0x%0h - 0x%0h: Input image", 0, IMG_SIZE-1);
        $display("  0x%0h - 0x%0h: Weights", WEIGHT_START, BIAS_START-1);
        $display("  0x%0h - 0x%0h: Biases", BIAS_START, BIAS_START+NUM_CLASSES-1);
        $display("  0x%0h - 0x%0h: Result area", RESULT_ADDR, RESULT_ADDR+NUM_CLASSES-1);
        
        // Wait for computation or timeout
        fork
            begin
                // Timeout after 100K cycles
                repeat(100000) @(posedge clk);
                $display("ERROR: Simulation timeout at %0t", $time);
                $finish;
            end
            begin
                @(posedge halt);
                $display("\nComputation complete at %0t", $time);
                $display("Predicted digit: %0d (Activation: %0d)", predicted_digit, max_activation);
                #(CLK_PERIOD * 5);
                $finish;
            end
        join_any
    end
    
    // Performance monitoring
    integer cycle_count = 0;
    integer last_report = 0;
    
    always @(posedge clk) begin
        cycle_count = cycle_count + 1;
        
        // Report every 1000 cycles
        if ((cycle_count % 1000 == 0) || halt) begin
            $display("Cycle %0d:", cycle_count);
            $display("  PC: 0x%0h  Instruction: 0x%0h", pc, current_instr);
            if (data_wen)
                $display("  Memory Write: [0x%0h] <- 0x%0h", data_addr, data_write);
            else
                $display("  Memory Read:  [0x%0h] -> 0x%0h", data_addr, data_read);
            
            // Calculate and display performance
            if (halt) begin
                $display("\nPerformance Summary:");
                $display("Total cycles: %0d", cycle_count);
                $display("Average cycles per pixel: %0d", cycle_count / IMG_SIZE);
            end
        end
        
        // Print status every 100 cycles
        if (cycle_count % 100 == 0) begin
            $display("Cycle: %d", cycle_count);
        end
    end

endmodule