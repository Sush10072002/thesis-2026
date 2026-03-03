`timescale 1ns / 1ps

module tb_top;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg line1;
reg line2;

// Output signals
wire outp;
wire overflw;

// Loop counter
integer i;

// File for logging (optional)
integer file;

// Instantiate the DUT (Device Under Test)
b01 dut (
    .clock(clk),
    .reset(~rst_n),  // rst_n is active low, but b01 expects active high reset
    .line1(line1),
    .line2(line2),
    .outp(outp),
    .overflw(overflw)
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
    line1 = 0;
    line2 = 0;
    
    // Open file for logging (optional - comment out if not needed)
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\tline1\tline2\toutp\toverflw\tstato\n");
    $fwrite(file, "-----\t-----\t-----\t----\t-------\t-----\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation with random inputs ===\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        // Random input generation
        line1 <= $random;
        line2 <= $random;
        
        // Log internal signals to file
        if (file) begin
            $fwrite(file, "%0d\t%b\t%b\t%b\t%b\t%0d\n", 
                    i, line1, line2, outp, overflw, dut.stato);
        end
        
        // Display overflow events
        if (overflw == 1'b1) begin
            $display("Time=%0t: OVERFLOW at cycle %0d | line1=%b line2=%b outp=%b stato=%0d", 
                     $time, i, line1, line2, outp, dut.stato);
        end
        
        // Display state transitions to overflow state (state e=3)
        if (dut.stato == 3) begin
            $display("Time=%0t: Entered OVERFLOW state (e) at cycle %0d", $time, i);
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
    $display("=== b01 State Machine Testbench ===");
    $display("Time\t\trst_n\tline1\tline2\toutp\toverflw\tstato");
    $display("----\t\t-----\t-----\t-----\t----\t-------\t-----");
    $monitor("%0t\t%b\t%b\t%b\t%b\t%b\t%0d", 
             $time, rst_n, line1, line2, outp, overflw, dut.stato);
end

// Generate VCD file for waveform viewing (optional)
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    $dumpvars(0, dut.stato);  // Explicitly dump internal state
end

// Statistics tracking (optional)
integer overflow_count;
integer state_a_count, state_b_count, state_c_count, state_e_count;
integer state_f_count, state_g_count, state_wf0_count, state_wf1_count;

initial begin
    overflow_count = 0;
    state_a_count = 0;
    state_b_count = 0;
    state_c_count = 0;
    state_e_count = 0;
    state_f_count = 0;
    state_g_count = 0;
    state_wf0_count = 0;
    state_wf1_count = 0;
    
    // Wait for reset deassertion
    @(posedge rst_n);
    
    // Count statistics during simulation
    repeat(50000) begin
        @(posedge clk);
        if (overflw) overflow_count = overflow_count + 1;
        
        case(dut.stato)
            0: state_a_count = state_a_count + 1;
            1: state_b_count = state_b_count + 1;
            2: state_c_count = state_c_count + 1;
            3: state_e_count = state_e_count + 1;
            4: state_f_count = state_f_count + 1;
            5: state_g_count = state_g_count + 1;
            6: state_wf0_count = state_wf0_count + 1;
            7: state_wf1_count = state_wf1_count + 1;
        endcase
    end
    
    // Display statistics
    #100;
    $display("\n=== Simulation Statistics ===");
    $display("Overflow events: %0d", overflow_count);
    $display("\nState visit counts:");
    $display("  State a (0):   %0d", state_a_count);
    $display("  State b (1):   %0d", state_b_count);
    $display("  State c (2):   %0d", state_c_count);
    $display("  State e (3):   %0d (overflow state)", state_e_count);
    $display("  State f (4):   %0d", state_f_count);
    $display("  State g (5):   %0d", state_g_count);
    $display("  State wf0 (6): %0d", state_wf0_count);
    $display("  State wf1 (7): %0d", state_wf1_count);
end

endmodule
