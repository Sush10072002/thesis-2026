`timescale 1ns / 1ps

module tb_top;

// State parameters (must match b09.v)
parameter INIT = 0;
parameter RECEIVE = 1;
parameter EXECUTE = 2;
parameter LOAD_OLD = 3;

// Bit parameters (must match b09.v)
parameter Bit_start = 1'b1;
parameter Bit_stop = 1'b0;
parameter Bit_idle = 1'b0;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg x;

// Output signals
wire y;

// Loop counter
integer i;

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
    $fwrite(file, "Cycle\tx\ty\tSTATO\td_in\t\td_out\t\told\n");
    $fwrite(file, "-----\t-\t-\t-----\t---------\t--------\t--------\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation with random input ===\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<100000; i=i+1) begin
        @(posedge clk);
        // Random input generation
        x <= $random;
        
        // Log internal signals to file
        if (file) begin
            $fwrite(file, "%0d\t%b\t%b\t%0d\t%b\t%b\t%b\n", 
                    i, x, y, dut.stato, dut.d_in, dut.d_out, dut.old);
        end
        
        // Display state transitions
        if (dut.stato == INIT) begin
            $display("Time=%0t: Cycle %0d - State INIT", $time, i);
        end
        
        if (dut.stato == RECEIVE && dut.d_in[0] == Bit_start) begin
            $display("Time=%0t: Cycle %0d - RECEIVE: Start bit detected | d_in=%b old=%b", 
                     $time, i, dut.d_in, dut.old);
        end
        
        if (dut.stato == EXECUTE) begin
            $display("Time=%0t: Cycle %0d - EXECUTE | d_in=%b d_out=%b y=%b", 
                     $time, i, dut.d_in, dut.d_out, y);
        end
        
        if (dut.stato == LOAD_OLD) begin
            $display("Time=%0t: Cycle %0d - LOAD_OLD | d_in=%b old=%b y=%b", 
                     $time, i, dut.d_in, dut.old, y);
        end
        
        // Display when output y changes
        if (y == Bit_start) begin
            $display("Time=%0t: Cycle %0d - y=START | STATO=%0d d_out=%b", 
                     $time, i, dut.stato, dut.d_out);
        end
        
        if (y == Bit_stop) begin
            $display("Time=%0t: Cycle %0d - y=STOP | STATO=%0d d_in=%b", 
                     $time, i, dut.stato, dut.d_in);
        end
        
        // Display calculation progress every 1000 cycles
        if (i % 1000 == 0) begin
            $display("Time=%0t: Cycle %0d | STATO=%0d x=%b y=%b d_in=%b d_out=%b old=%b", 
                     $time, i, dut.stato, x, y, dut.d_in, dut.d_out, dut.old);
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
    $display("Time\t\trst_n\tx\ty\tSTATO\td_in\t\td_out\t\told");
    $display("----\t\t-----\t-\t-\t-----\t---------\t--------\t--------");
    $monitor("%0t\t%b\t%b\t%b\t%0d\t%b\t%b\t%b", 
             $time, rst_n, x, y, dut.stato, dut.d_in, dut.d_out, dut.old);
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

// State name decoder for display
function [127:0] state_name;
    input [2:0] state;
    begin
        case(state)
            INIT: state_name = "INIT";
            RECEIVE: state_name = "RECEIVE";
            EXECUTE: state_name = "EXECUTE";
            LOAD_OLD: state_name = "LOAD_OLD";
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
            $display("Inputs: x=%b", x);
            $display("Outputs: y=%b", y);
            $display("d_in:  %b (LSB=%b)", dut.d_in, dut.d_in[0]);
            $display("d_out: %b (LSB=%b)", dut.d_out, dut.d_out[0]);
            $display("old:   %b", dut.old);
            
            // Additional state-specific information
            case(dut.stato)
                RECEIVE: begin
                    $display("Status: Waiting for start bit (d_in[0]=%b)", dut.d_in[0]);
                end
                EXECUTE: begin
                    $display("Status: Transmitting d_out, current bit=%b", dut.d_out[0]);
                end
                LOAD_OLD: begin
                    if (dut.d_in[0] == Bit_start) begin
                        if (dut.d_in[8:1] == dut.old) begin
                            $display("Status: Duplicate data detected (d_in[8:1]=%b == old=%b)", dut.d_in[8:1], dut.old);
                        end else begin
                            $display("Status: New data detected (d_in[8:1]=%b != old=%b)", dut.d_in[8:1], dut.old);
                        end
                    end else begin
                        $display("Status: Waiting for start bit in LOAD_OLD");
                    end
                end
            endcase
        end
    end
end

// Track bit patterns and transitions
integer start_bit_count;
integer stop_bit_count;
integer idle_bit_count;
integer state_transitions [0:3];

initial begin
    start_bit_count = 0;
    stop_bit_count = 0;
    idle_bit_count = 0;
    for (i=0; i<4; i=i+1) begin
        state_transitions[i] = 0;
    end
    
    @(posedge rst_n);
    
    repeat(50000) begin
        @(posedge clk);
        
        // Count output bit types
        if (y == Bit_start) start_bit_count = start_bit_count + 1;
        if (y == Bit_stop) stop_bit_count = stop_bit_count + 1;
        if (y == Bit_idle) idle_bit_count = idle_bit_count + 1;
        
        // Count state visits
        if (dut.stato <= 3) begin
            state_transitions[dut.stato] = state_transitions[dut.stato] + 1;
        end
    end
    
    #100;
    $display("\n=== Signal Analysis ===");
    $display("Output bit counts:");
    $display("  Start bits (1): %0d", start_bit_count);
    $display("  Stop bits (0):  %0d", stop_bit_count);
    $display("  Idle bits (0):  %0d", idle_bit_count);
    
    $display("\nState visit counts:");
    $display("  INIT (0):     %0d", state_transitions[0]);
    $display("  RECEIVE (1):  %0d", state_transitions[1]);
    $display("  EXECUTE (2):  %0d", state_transitions[2]);
    $display("  LOAD_OLD (3): %0d", state_transitions[3]);
end

// Detect and display complete frame transmissions
reg prev_y;
integer frame_count;

initial begin
    @(posedge rst_n);
    prev_y = 0;
    frame_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        // Detect start of frame (transition to start bit)
        if (prev_y == 0 && y == 1 && dut.stato == EXECUTE) begin
            frame_count = frame_count + 1;
            $display("Time=%0t: Frame %0d START | d_out=%b old=%b", 
                     $time, frame_count, dut.d_out, dut.old);
        end
        
        prev_y = y;
    end
end

endmodule
