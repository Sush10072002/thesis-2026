`timescale 1ns / 1ps

module tb_top;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg x;

// Output signals
wire y;

// Loop counter
integer i, j;

// File for logging (optional)
integer file;

// Instantiate the DUT (Device Under Test)
b09 dut (
    .clock(clk),
    .reset(~rst_n),  // rst_n is active low, but b09 expects active high reset
    .x(x),
    .y(y)
);

// Clock generation - 10ns period (100MHz)
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// Test stimulus
initial begin
    // Initialize signals
    rst_n = 0;
    x = 0;
    
    // Open file for logging (optional - comment out if not needed)
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\tx\ty\tSTATO\td_in\td_out\told\n");
    $fwrite(file, "-----\t-\t-\t-----\t----\t-----\t---\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation with random input ===\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        // Random input generation for x signal
        x <= $random;
        
        // Log internal signals to file
        if (file) begin
            $fwrite(file, "%0d\t%b\t%b\t%0d\t%b\t%b\t%b\n", 
                    i, x, y, dut.stato, dut.d_in, dut.d_out, dut.old);
        end
        
        // Display state transitions
        if (dut.stato == 0) begin
            if (i % 1000 == 0 && i > 0) begin
                $display("Time=%0t: INIT state at cycle %0d", $time, i);
            end
        end
        
        if (dut.stato == 1 && dut.d_in[0] == 1'b1) begin
            $display("Time=%0t: RECEIVE->EXECUTE at cycle %0d | d_in=%b old=%b", 
                     $time, i, dut.d_in, dut.old);
        end
        
        if (dut.stato == 2) begin
            if (dut.d_in[0] == 1'b1) begin
                $display("Time=%0t: EXECUTE->LOAD_OLD at cycle %0d | d_in=%b d_out=%b y=%b", 
                         $time, i, dut.d_in, dut.d_out, y);
            end
        end
        
        if (dut.stato == 3) begin
            if (dut.d_in[0] == 1'b1) begin
                if (dut.d_in[8:1] == dut.old) begin
                    $display("Time=%0t: LOAD_OLD duplicate detected at cycle %0d | d_in[8:1]=%b old=%b", 
                             $time, i, dut.d_in[8:1], dut.old);
                end else begin
                    $display("Time=%0t: LOAD_OLD->EXECUTE new data at cycle %0d | d_in[8:1]=%b old=%b", 
                             $time, i, dut.d_in[8:1], dut.old);
                end
            end
        end
        
        // Display when y (output) is active (start bit)
        if (y == 1'b1) begin
            $display("Time=%0t: Output y=START at cycle %0d | stato=%0d d_out=%b", 
                     $time, i, dut.stato, dut.d_out);
        end
        
        // Display significant bit patterns
        if (dut.d_in == 9'b100000000 || dut.d_in == 9'b111111111) begin
            $display("Time=%0t: Notable d_in pattern at cycle %0d | d_in=%b stato=%0d", 
                     $time, i, dut.d_in, dut.stato);
        end
        
        // Periodic status display
        if (i % 5000 == 0 && i > 0) begin
            $display("Time=%0t: Progress - Cycle %0d | stato=%0d d_in=%b y=%b", 
                     $time, i, dut.stato, dut.d_in, y);
        end
    end
    
    // Close file and finish simulation
    if (file) $fclose(file);
    
    $display("\n=== Simulation Complete ===");
    $display("Total cycles run: %0d", i);
    $display("Check 'simulation_log.txt' for detailed signal log");
    $finish;
end

// Monitor for debugging (optional - comment out for faster simulation)
initial begin
    $display("=== b09 Serial Communication Testbench ===");
    $display("Time\t\trst_n\tx\ty\tSTATO\td_in\t\td_out");
    $display("----\t\t-----\t-\t-\t-----\t----\t\t-----");
    $monitor("%0t\t%b\t%b\t%b\t%0d\t%b\t%b", 
             $time, rst_n, x, y, dut.stato, dut.d_in, dut.d_out);
end

// Generate VCD file for waveform viewing (optional)
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    // Explicitly dump all internal signals
    $dumpvars(0, dut.stato);
    $dumpvars(0, dut.d_in);
    $dumpvars(0, dut.d_out);
    $dumpvars(0, dut.old);
end

// Data packet tracker
integer packet_id;
reg [8:0] prev_d_in;
reg [2:0] prev_stato;

initial begin
    packet_id = 0;
    prev_d_in = 9'b000000000;
    prev_stato = 0;
    
    @(posedge rst_n);
    
    forever begin
        @(posedge clk);
        
        // Detect start of new packet reception
        if (prev_stato == 1 && dut.stato == 2 && dut.d_in[0] == 1'b1) begin
            packet_id = packet_id + 1;
            $display("\n=== Packet #%0d Received at time %0t ===", packet_id, $time);
            $display("  Data: %b (0x%02h)", dut.old, dut.old);
            $display("  Starting transmission...");
        end
        
        // Detect packet transmission complete
        if (prev_stato == 2 && dut.stato == 3) begin
            $display("=== Packet #%0d Transmission Complete at time %0t ===", packet_id, $time);
        end
        
        prev_d_in = dut.d_in;
        prev_stato = dut.stato;
    end
end

// Bit shift observation in RECEIVE state
integer shift_count;

initial begin
    shift_count = 0;
    
    @(posedge rst_n);
    
    forever begin
        @(posedge clk);
        if (dut.stato == 1) begin
            shift_count = shift_count + 1;
            if (shift_count % 1000 == 0) begin
                $display("RECEIVE: %0d shifts performed, current d_in=%b", shift_count, dut.d_in);
            end
        end
    end
end

// Output bit stream analysis
integer output_bit_count;
reg [7:0] output_byte;
integer output_byte_count;

initial begin
    output_bit_count = 0;
    output_byte_count = 0;
    output_byte = 8'b00000000;
    
    @(posedge rst_n);
    
    forever begin
        @(posedge clk);
        // Track bits being output during EXECUTE state
        if (dut.stato == 2 && y != 1'b1 && y != 1'b0) begin
            // In middle of transmission
            output_bit_count = output_bit_count + 1;
        end
        
        // Track complete bytes transmitted
        if (dut.stato == 2 && dut.d_in[0] == 1'b1) begin
            output_byte_count = output_byte_count + 1;
            if (output_byte_count <= 10) begin
                $display("Byte #%0d transmitted: %b at time %0t", 
                         output_byte_count, dut.old, $time);
            end
        end
    end
end

endmodule
