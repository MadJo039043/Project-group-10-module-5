`timescale 1ns/1ps

module tb_uart_protocol;
    // Clock and reset
    reg clk = 0;
    reg rst = 1;
    
    // UART simulation signals
    reg tb_rx_ready = 0;
    reg [7:0] tb_rx_byte = 8'h00;
    
    // DUT outputs
    wire txd;
    wire dut_tx_en;
    wire [7:0] dut_tx_byte;
    
    // Clock generation (100MHz)
    always #5 clk = ~clk;

    // Instantiate DUT
    top_module #(
        .FREQ(100_000_000),
        .BAUD(625_000)
    ) dut (
        .clk(clk),
        .rst(rst),
        .rxd(1'b0),
        .txd(txd),
        .led(led),
        .tb_rx_ready(tb_rx_ready),
        .tb_rx_byte(tb_rx_byte),
        .tx_en(dut_tx_en),        
        .tx_byte(dut_tx_byte)      
    );


    // Predefined test packets (24-bit each)
    reg [23:0] test_packets [0:9];
    
    // File handling variables
    integer tx_file;
    integer packet_count = 0;
    reg [23:0] current_packet;
    reg [1:0] byte_counter = 0;
    
    initial begin
        // Initialize test packets
        test_packets[0] = 24'b101000000000000000000000; // Packet 0
        test_packets[1] = 24'b101000000000100000000010; // Packet 1
        test_packets[2] = 24'b101000000001000000000010; // Packet 2
        test_packets[3] = 24'b101000000001100000000000; // Packet 3
        test_packets[4] = 24'b101000000010000000000010; // Packet 4
        test_packets[5] = 24'b101000000010100000000000; // Packet 5
        test_packets[6] = 24'b101000000011000000000000; // Packet 6
        test_packets[7] = 24'b101000000011100000000010; // Packet 7
        test_packets[8] = 24'b101000000100000000000010; // Packet 8
        test_packets[9] = 24'b101000000100100000000000; // Packet 9
        
        // Open file for writing TX packets
        tx_file = $fopen("tx_packets.txt", "w");
        if (!tx_file) begin
            $display("Error: Could not open tx_packets.txt");
            $finish;
        end
        $fdisplay(tx_file, "Time(ns) | Packet Number | Packet Data (24-bit)");
        $fdisplay(tx_file, "--------------------------------------------");
    end

    // Test sequence
    integer i;
    integer timeout;
    localparam SIM_TIMEOUT = 2_000_000; // 2ms timeout
    
    initial begin
        $display("=== Starting Test with Specific Packets ===");
        
        // Reset sequence
        #100 rst = 0;
        #200; // Wait for reset to propagate
        
        // Send all test packets
        for (i = 0; i < 10; i = i + 1) begin
            send_packet(test_packets[i]);
            #1000; // Delay between packets
        end
        
        // Wait for processing
        wait_for_completion();
        
        // Verify transmission
        verify_transmission();
        
        // Close file and finish
        $fclose(tx_file);
        $display("=== Test Completed Successfully ===");
        $display("TX packets saved to tx_packets.txt");
        $finish;
    end

    // Monitor TX packets and write to file
    always @(posedge clk) begin
        if (dut_tx_en) begin
        case (byte_counter)
            0: begin
                current_packet[23:16] = dut_tx_byte;
                byte_counter = 1;
            end
            1: begin
                current_packet[15:8] = dut_tx_byte;
                byte_counter = 2;
            end
            2: begin
                current_packet[7:0] = dut_tx_byte;
                byte_counter = 0;
                $fdisplay(tx_file, "%9t | %13d | %24b", $time, packet_count, current_packet);
                packet_count = packet_count + 1;
            end
        endcase 
    end
 end

    // Send a complete 24-bit packet (3 bytes)
    task send_packet;
        input [23:0] packet;
        begin
            send_byte(packet[23:16]); // Byte 0 (Header + Addr[9:5])
            #100;
            send_byte(packet[15:8]);  // Byte 1 (Addr[4:0] + Data[7:5])
            #100;
            send_byte(packet[7:0]);   // Byte 2 (Data[4:0] + Footer)
            $display("[%0t] Sent packet %0d: %24b", $time, i, packet);
        end
    endtask

    task send_byte;
        input [7:0] data;
        begin
            tb_rx_byte = data;
            tb_rx_ready = 1;
            @(posedge clk);
            #1;
            tb_rx_ready = 0;
            repeat(20) @(posedge clk); // Inter-byte delay
        end
    endtask

    task wait_for_completion;
        begin
            $display("[%0t] Waiting for DUT to process packets...", $time);
            timeout = 1_000_000; // 1ms timeout
            
            while (dut.count_packets < 10 && timeout > 0) begin
                @(posedge clk);
                timeout = timeout - 1;
                
                // Progress report every 100us
                if (timeout % 100_000 == 0) begin
                    $display("[%0t] Status: %0d/10 packets processed, LED: %h", 
                            $time, dut.count_packets, led);
                end
            end
            
            if (timeout == 0) begin
                $display("[%0t] Error: Timeout waiting for completion (%0d/10 packets)", 
                        $time, dut.count_packets);
                $finish;
            end
            
            // Additional wait for TX to start
            timeout = 200_000;
            while (!dut_tx_en && timeout > 0) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            
            if (timeout == 0) begin
                $display("[%0t] Error: TX never started", $time);
                $finish;
            end
        end
    endtask

    task verify_transmission;
        begin
            $display("[%0t] Verifying results...", $time);
            
            // Check packet count
            if (dut.count_packets != 10) begin
                $display("Error: Received %0d packets, expected 10", dut.count_packets);
                $finish;
            end
            
            // Check LED output (should show 0x000A for 10 packets)
            if (led != 16'h000A) begin
                $display("Error: LED shows %h, expected 000A", led);
                $finish;
            end
            
            $display("All 10 packets processed correctly");
            $display("LED shows correct count: %h", led);
        end
    endtask

    // Global simulation timeout
    initial begin
        #SIM_TIMEOUT;
        $display("[%0t] Simulation timeout! Packets processed: %0d/10", 
                $time, dut.count_packets);
        $finish;
    end
endmodule