`timescale 1ns / 1ps

module tb_top;

// Testbench signals
reg clk;
reg rst_n;
reg RESTART;
reg AVERAGE;
reg ENABLE;
reg signed [7:0] DATA_IN;
wire [7:0] DATA_OUT;

integer i;
integer error_count;

// Instantiate the DUT (Device Under Test)
b04 dut (
    .CLOCK(clk),
    .RESET(rst_n),
    .RESTART(RESTART),
    .AVERAGE(AVERAGE),
    .ENABLE(ENABLE),
    .DATA_IN(DATA_IN),
    .DATA_OUT(DATA_OUT)
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
    RESTART = 0;
    AVERAGE = 0;
    ENABLE = 0;
    DATA_IN = 0;
    error_count = 0;
    
    // Display header
    $display("========================================");
    $display("Starting b04 Testbench");
    $display("Running for 50,000 clock cycles");
    $display("========================================");
    
    // Apply reset
    #15;
    rst_n = 1;
    #20;
    rst_n = 0;
    #10;
    
    $display("Time: %0t - Reset released, starting random test", $time);
    
    // Run for 50,000 cycles with random inputs
    for (i = 0; i < 50000; i = i + 1) begin
        @(posedge clk);
        
        // Generate random inputs
        DATA_IN <= $random;
        RESTART <= $random % 2;
        AVERAGE <= $random % 2;
        ENABLE <= $random % 2;
        
        // Display progress every 5000 cycles
        if (i % 5000 == 0) begin
            $display("Cycle: %0d / 50000 - DATA_IN=%d, ENABLE=%b, AVERAGE=%b, RESTART=%b, DATA_OUT=%d", 
                     i, $signed(DATA_IN), ENABLE, AVERAGE, RESTART, $signed(DATA_OUT));
        end
        
        // Optional: Check for specific conditions or errors
        // Add your verification logic here if needed
    end
    
    // Final statistics
    #20;
    $display("\n========================================");
    $display("Simulation completed successfully!");
    $display("Total cycles run: 50,000");
    $display("Final state: %d", dut.stato);
    $display("Final RMAX: %d", $signed(dut.RMAX));
    $display("Final RMIN: %d", $signed(dut.RMIN));
    $display("Final DATA_OUT: %d", $signed(DATA_OUT));
    $display("========================================");
    
    $finish;
end

// Optional: Sample specific scenarios within the random test
initial begin
    // Wait for reset to complete
    wait(rst_n == 0);
    @(posedge clk);
    @(posedge clk);
    
    // Force a specific test scenario at cycle 1000
    @(posedge clk);
    repeat(998) @(posedge clk);
    
    $display("\n--- Forcing specific test at cycle 1000 ---");
    @(posedge clk);
    ENABLE = 1;
    AVERAGE = 0;
    RESTART = 0;
    DATA_IN = 50;
    
    @(posedge clk);
    DATA_IN = 30;
    
    @(posedge clk);
    DATA_IN = 40;
    
    // Resume random testing
    $display("--- Resuming random test ---\n");
end

// Monitor for extreme values or interesting events
always @(posedge clk) begin
    if (!rst_n) begin
        // Check for maximum/minimum tracking
        if (ENABLE && (DATA_IN > dut.RMAX || DATA_IN < dut.RMIN)) begin
            $display("Time: %0t - Extreme value detected: DATA_IN=%d, RMAX=%d, RMIN=%d", 
                     $time, $signed(DATA_IN), $signed(dut.RMAX), $signed(dut.RMIN));
        end
        
        // Monitor RESTART events
        if (RESTART) begin
            if ($time < 100000) // Only display first 10us to avoid spam
                $display("Time: %0t - RESTART triggered, computing average of RMAX and RMIN", $time);
        end
    end
end

// Waveform dump for viewing in waveform viewer
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    
    // Limit VCD file size by only dumping first portion
    // Uncomment the next line to dump only first 10000 cycles
    // #100000 $dumpoff;
end

// Optional: Timeout watchdog (in case simulation hangs)
initial begin
    #5000000; // 5ms timeout
    $display("ERROR: Simulation timeout!");
    $finish;
end

endmodule