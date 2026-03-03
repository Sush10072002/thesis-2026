`timescale 1ns / 1ps

module tb_top;

// State parameters (must match b10.v)
parameter STARTUP = 0;
parameter STANDBY = 1;
parameter GET_IN = 2;
parameter START_TX = 3;
parameter SEND = 4;
parameter TX_2_RX = 5;
parameter RECEIVE = 6;
parameter RX_2_TX = 7;
parameter END_TX = 8;
parameter TEST_1 = 9;
parameter TEST_2 = 10;

// Simulation parameters
parameter PERIOD = 10;  // Clock period in ns
parameter SIM_CYCLES = 50000;  // Number of simulation cycles

// Clock and reset
reg clk;
reg rst_n;

// Input signals
reg  r_button;
reg  g_button;
reg  key;
reg  start;
reg  test;
reg  rts;
reg  rtr;
reg [3:0] v_in;

// Output signals
wire [3:0] v_out;
wire  cts;
wire  ctr;

// Loop counter
integer i;

// File for logging
integer file;

// Instantiate the DUT (Device Under Test)
b10 dut (
    .clock    (clk),
    .reset    (~rst_n),
    .r_button (r_button),
    .g_button (g_button),
    .key      (key),
    .start    (start),
    .test     (test),
    .rts      (rts),
    .rtr      (rtr),
    .v_in     (v_in),
    .v_out    (v_out),
    .cts      (cts),
    .ctr      (ctr)
);

// Clock generation - 10ns period (100MHz)
initial begin
    clk = 0;
    forever #(PERIOD/2) clk = ~clk;
end

// Test stimulus
initial begin
    // Initialize signals
    rst_n = 0;
    r_button = 1'b0;
    g_button = 1'b0;
    key = 1'b0;
    start = 1'b0;
    test = 1'b0;
    rts = 1'b0;
    rtr = 1'b0;
    v_in = 4'h0;
    
    // Open file for logging
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\tr_button\tg_button\tkey\tstart\ttest\trts\trtr\tv_in\tv_out\tcts\tctr\tstato\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50000 cycle simulation with random input ===\n");
    
    // Run for specified cycles with random inputs
    for (i=0; i<SIM_CYCLES; i=i+1) begin
        @(posedge clk);
        // Random input generation
        r_button <= $random;
        g_button <= $random;
        key <= $random;
        start <= $random;
        test <= $random;
        rts <= $random;
        rtr <= $random;
        v_in <= $random;
        
        // Log signals to file
        if (file) begin
            $fwrite(file, "%0d\t%h\t%h\t%h\t%h\t%h\t%h\t%h\t%h\t%h\t%b\t%b\t%0d\n", 
                    i, r_button, g_button, key, start, test, rts, rtr, v_in, v_out, cts, ctr, dut.stato);
        end
        
        // Display state transitions
        if (dut.stato == STARTUP) begin
            if (i % 100 == 0)  // Display every 100 cycles in this state
                $display("Time=%0t: Cycle %0d - State: STARTUP", $time, i);
        end
                if (dut.stato == STANDBY) begin
            if (i % 100 == 0)  // Display every 100 cycles in this state
                $display("Time=%0t: Cycle %0d - State: STANDBY", $time, i);
        end
                if (dut.stato == GET_IN) begin
            if (i % 100 == 0)  // Display every 100 cycles in this state
                $display("Time=%0t: Cycle %0d - State: GET_IN", $time, i);
        end
                if (dut.stato == START_TX) begin
            if (i % 100 == 0)  // Display every 100 cycles in this state
                $display("Time=%0t: Cycle %0d - State: START_TX", $time, i);
        end
                if (dut.stato == SEND) begin
            if (i % 100 == 0)  // Display every 100 cycles in this state
                $display("Time=%0t: Cycle %0d - State: SEND", $time, i);
        end
                if (dut.stato == TX_2_RX) begin
            if (i % 100 == 0)  // Display every 100 cycles in this state
                $display("Time=%0t: Cycle %0d - State: TX_2_RX", $time, i);
        end
                if (dut.stato == RECEIVE) begin
            if (i % 100 == 0)  // Display every 100 cycles in this state
                $display("Time=%0t: Cycle %0d - State: RECEIVE", $time, i);
        end
                if (dut.stato == RX_2_TX) begin
            if (i % 100 == 0)  // Display every 100 cycles in this state
                $display("Time=%0t: Cycle %0d - State: RX_2_TX", $time, i);
        end
                if (dut.stato == END_TX) begin
            if (i % 100 == 0)  // Display every 100 cycles in this state
                $display("Time=%0t: Cycle %0d - State: END_TX", $time, i);
        end
                if (dut.stato == TEST_1) begin
            if (i % 100 == 0)  // Display every 100 cycles in this state
                $display("Time=%0t: Cycle %0d - State: TEST_1", $time, i);
        end
        
        // Display progress every 1000 cycles
        if (i % 1000 == 0) begin
            $display("Time=%0t: Cycle %0d | State=%0d", $time, i, dut.stato);
        end
    end
    
    // Close file and finish simulation
    if (file) $fclose(file);
    
    $display("\n=== Simulation Complete ===");
    $display("Total cycles run: %%0d", i);
    $display("Check 'simulation_log.txt' for detailed signal log");
    $finish;
end

// State name decoder for display
function [127:0] state_name;
    input [31:0] state;
    begin
        case(state)
            STARTUP: state_name = "STARTUP";
            STANDBY: state_name = "STANDBY";
            GET_IN: state_name = "GET_IN";
            START_TX: state_name = "START_TX";
            SEND: state_name = "SEND";
            TX_2_RX: state_name = "TX_2_RX";
            RECEIVE: state_name = "RECEIVE";
            RX_2_TX: state_name = "RX_2_TX";
            END_TX: state_name = "END_TX";
            TEST_1: state_name = "TEST_1";
            TEST_2: state_name = "TEST_2";
            default: state_name = "UNKNOWN";
        endcase
    end
endfunction

// Monitor for debugging
initial begin
    $display("=== b10 Testbench ===");
    $display("Time\trst_n\tstato\tv_out\tcts\tctr");
    $display("----\t-----\t-----\t-----\t---\t---");
    $monitor("%0t\t%0d\t%h\t%b\t%b", 
             $time, rst_n, dut.stato, v_out, cts, ctr);
end

// Generate VCD file for waveform viewing
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    // Dump all DUT signals
    $dumpvars(0, dut);
    // Explicitly dump state register
    $dumpvars(0, dut.stato);
end

// Track output signal changes
reg [3:0] prev_v_out;
reg prev_cts;
reg prev_ctr;

initial begin
    @(posedge rst_n);
    prev_v_out = 0;
    prev_cts = 0;
    prev_ctr = 0;
    
    repeat(SIM_CYCLES) begin
        @(posedge clk);
        
        if (dut.v_out != prev_v_out) begin
            $display("Time=%0t: v_out changed: %h -> %h", $time, prev_v_out, dut.v_out);
            prev_v_out = dut.v_out;
        end
        if (dut.cts != prev_cts) begin
            $display("Time=%0t: cts changed: %h -> %h", $time, prev_cts, dut.cts);
            prev_cts = dut.cts;
        end
        if (dut.ctr != prev_ctr) begin
            $display("Time=%0t: ctr changed: %h -> %h", $time, prev_ctr, dut.ctr);
            prev_ctr = dut.ctr;
        end
    end
end

// Track state transitions
reg [3:0] prev_state;
integer state_change_count;

initial begin
    @(posedge rst_n);
    prev_state = dut.stato;
    state_change_count = 0;
    
    repeat(SIM_CYCLES) begin
        @(posedge clk);
        
        if (dut.stato != prev_state) begin
            state_change_count = state_change_count + 1;
            $display("Time=%%0t: State transition #%%0d: %%s (%%0d) -> %%s (%%0d)", 
                     $time, state_change_count, 
                     state_name(prev_state), prev_state,
                     state_name(dut.stato), dut.stato);
            prev_state = dut.stato;
        end
    end
    
    #100;
    $display("\n=== State Transition Statistics ===");
    $display("Total state transitions: %%0d", state_change_count);
    $display("Final state: %s (%0d)", state_name(dut.stato), dut.stato);
end

endmodule
