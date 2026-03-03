`timescale 1ns / 1ps

module tb_top;

// State parameters (must match b07.v)
parameter S_RESET = 0;
parameter S_START = 1;
parameter S_LOAD_X = 2;
parameter S_UPDATE_MAR = 3;
parameter S_LOAD_Y = 4;
parameter S_CALC_RETTA = 5;
parameter S_INCREMENTA = 6;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg start;

// Output signals
wire [7:0] punti_retta;

// Loop counter
integer i;

// File for logging (optional)
integer file;

// Instantiate the DUT (Device Under Test)
b07 dut (
    .clock(clk),
    .reset(~rst_n),  // rst_n is active low, but b07 expects active high reset
    .start(start),
    .punti_retta(punti_retta)
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
    start = 0;
    
    // Open file for logging (optional - comment out if not needed)
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\tstart\tpunti_retta\tstato\tmar\tcont\tx\ty\tt\n");
    $fwrite(file, "-----\t-----\t-----------\t-----\t---\t----\t-\t-\t-\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation with random input ===\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        // Random input generation
        start <= $random;
        
        // Log internal signals to file
        if (file) begin
            $fwrite(file, "%0d\t%b\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\n", 
                    i, start, punti_retta, dut.stato, dut.mar, dut.cont, dut.x, dut.y, dut.t);
        end
        
        // Display state transitions
        if (dut.stato == S_RESET) begin
            $display("Time=%0t: Cycle %0d - State S_RESET", $time, i);
        end
        
        if (dut.stato == S_START && start == 1) begin
            $display("Time=%0t: Cycle %0d - START detected, entering computation", $time, i);
        end
        
        if (dut.stato == S_INCREMENTA && dut.mar == 15) begin
            $display("Time=%0t: Cycle %0d - Computation complete | punti_retta=%0d cont=%0d x=%0d", 
                     $time, i, punti_retta, dut.cont, dut.x);
        end
        
        // Display when punti_retta changes
        if (i > 0 && punti_retta != 0) begin
            $display("Time=%0t: Cycle %0d - punti_retta=%0d | stato=%0d mar=%0d cont=%0d", 
                     $time, i, punti_retta, dut.stato, dut.mar, dut.cont);
        end
        
        // Display calculation progress every 1000 cycles
        if (i % 1000 == 0) begin
            $display("Time=%0t: Cycle %0d | stato=%0d mar=%0d cont=%0d x=%0d y=%0d t=%0d", 
                     $time, i, dut.stato, dut.mar, dut.cont, dut.x, dut.y, dut.t);
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
    $display("=== b07 Testbench ===");
    $display("Time\t\trst_n\tstart\tpunti_retta\tstato\tmar\tcont\tx\ty\tt");
    $display("----\t\t-----\t-----\t-----------\t-----\t---\t----\t-\t-\t-");
    $monitor("%0t\t%b\t%b\t%0d\t\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d", 
             $time, rst_n, start, punti_retta, dut.stato, dut.mar, dut.cont, dut.x, dut.y, dut.t);
end

// Generate VCD file for waveform viewing (optional)
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    // Explicitly dump all internal signals
    $dumpvars(0, dut.stato);
    $dumpvars(0, dut.cont);
    $dumpvars(0, dut.x);
    $dumpvars(0, dut.y);
    $dumpvars(0, dut.t);
    $dumpvars(0, dut.mar);
    // Dump memory array
    for (i=0; i<16; i=i+1) begin
        $dumpvars(0, dut.mem[i]);
    end
end

// Memory content display
initial begin
    // Wait for reset deassertion
    @(posedge rst_n);
    #10;
    
    $display("\n=== Memory Contents ===");
    for (i=0; i<16; i=i+1) begin
        $display("mem[%2d] = %3d (0x%h)", i, dut.mem[i], dut.mem[i]);
    end
    $display("");
end

// State name decoder for display
function [127:0] state_name;
    input [2:0] state;
    begin
        case(state)
            S_RESET: state_name = "S_RESET";
            S_START: state_name = "S_START";
            S_LOAD_X: state_name = "S_LOAD_X";
            S_UPDATE_MAR: state_name = "S_UPDATE_MAR";
            S_LOAD_Y: state_name = "S_LOAD_Y";
            S_CALC_RETTA: state_name = "S_CALC_RETTA";
            S_INCREMENTA: state_name = "S_INCREMENTA";
            default: state_name = "UNKNOWN";
        endcase
    end
endfunction

// Additional detailed logging every 100 cycles
initial begin
    @(posedge rst_n);
    
    for (i=0; i<500; i=i+1) begin
        @(posedge clk);
        if (i % 100 == 0) begin
            $display("\n--- Cycle %0d Snapshot ---", i);
            $display("State: %0s (%0d)", state_name(dut.stato), dut.stato);
            $display("MAR: %0d, CONT: %0d", dut.mar, dut.cont);
            $display("X: %0d, Y: %0d, T: %0d", dut.x, dut.y, dut.t);
            $display("punti_retta: %0d", punti_retta);
            $display("start: %b", start);
        end
    end
end

endmodule