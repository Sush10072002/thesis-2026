`timescale 1ns / 1ps

module tb_top;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg linea;

// Output signals
wire u;

// Loop counter
integer i;

// File for logging (optional)
integer file;

// Instantiate the DUT (Device Under Test)
b02 dut (
    .clock(clk),
    .reset(~rst_n),  // rst_n is active low, but b02 expects active high reset
    .linea(linea),
    .u(u)
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
    linea = 0;
    
    // Open file for logging (optional - comment out if not needed)
    file = $fopen("simulation_log.txt", "w");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        // Random input generation
        linea <= $random;
        
        // Log internal signals (optional)
        if (file) begin
            $fwrite(file, "Cycle %0d: linea=%b, u=%b, stato=%d\n", 
                    i, linea, u, dut.stato);
        end
        
        // Display key transitions (optional - can be commented out for performance)
        if (u == 1'b1) begin
            $display("Time=%0t: Output u asserted at cycle %0d, stato=%d", 
                     $time, i, dut.stato);
        end
    end
    
    // Close file and finish simulation
    if (file) $fclose(file);
    
    $display("\n=== Simulation Complete ===");
    $display("Total cycles run: %0d", i);
    $finish;
end

// Monitor for debugging (optional - comment out for faster simulation)
initial begin
    $display("=== Starting Simulation ===");
    $display("Time\t\trst_n\tlinea\tu\tstato");
    $monitor("%0t\t%b\t%b\t%b\t%d", $time, rst_n, linea, u, dut.stato);
end

// Generate VCD file for waveform viewing (optional)
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
end

endmodule