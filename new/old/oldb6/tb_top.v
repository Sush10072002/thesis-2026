`timescale 1ns / 1ps

module tb_top;

// Parameters
parameter CLOCK_PERIOD = 10; // 10ns clock period (100MHz)

// Testbench signals
reg clk;
reg rst_n;
reg eql;
reg cont_eql;

wire [2:1] cc_mux;
wire [2:1] uscite;
wire enable_count;
wire ackout;

// Instantiate the DUT (Device Under Test)
b06 dut (
    .cc_mux(cc_mux),
    .eql(eql),
    .uscite(uscite),
    .clock(clk),
    .enable_count(enable_count),
    .ackout(ackout),
    .reset(~rst_n),  // Active high reset in DUT, active low in testbench
    .cont_eql(cont_eql)
);

// Clock generation
initial begin
    clk = 0;
    forever #(CLOCK_PERIOD/2) clk = ~clk;
end

// Test stimulus
integer i;
initial begin
    // Initialize signals
    rst_n = 0;
    eql = 0;
    cont_eql = 0;
    
    // Apply reset
    #(CLOCK_PERIOD * 5);
    rst_n = 1;
    #(CLOCK_PERIOD * 2);
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        // Generate random inputs
        eql <= $random;
        cont_eql <= $random;
    end
    
    // Finish simulation
    #(CLOCK_PERIOD * 10);
    $display("Simulation completed: 50000 cycles");
    $finish;
end

// Optional: Waveform dumping for viewing in waveform viewer
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
end

// Optional: Monitor outputs
initial begin
    $monitor("Time=%0t rst_n=%b eql=%b cont_eql=%b | cc_mux=%b uscite=%b enable_count=%b ackout=%b state=%d",
             $time, rst_n, eql, cont_eql, cc_mux, uscite, enable_count, ackout, dut.state);
end

endmodule