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

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg r_button;
reg g_button;
reg key;
reg start;
reg test;
reg rts;
reg rtr;
reg [3:0] v_in;

// Output signals
wire [3:0] v_out;
wire cts;
wire ctr;

// Loop counter
integer i;

// File for logging (optional)
integer file;

// Instantiate the DUT (Device Under Test)
b10 dut (
    .clock(clk),
    .reset(~rst_n),  // rst_n is active low, but b10 expects active high reset
    .r_button(r_button),
    .g_button(g_button),
    .key(key),
    .start(start),
    .test(test),
    .rts(rts),
    .rtr(rtr),
    .v_in(v_in),
    .v_out(v_out),
    .cts(cts),
    .ctr(ctr)
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
    r_button = 0;
    g_button = 0;
    key = 0;
    start = 0;
    test = 0;
    rts = 0;
    rtr = 0;
    v_in = 4'b0000;
    
    // Open file for logging (optional - comment out if not needed)
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\tr_btn\tg_btn\tkey\tstart\ttest\trts\trtr\tv_in\tv_out\tcts\tctr\tSTATO\tvoto0\tvoto1\tvoto2\tvoto3\tsign\tlast_g\tlast_r\n");
    $fwrite(file, "-----\t-----\t-----\t---\t-----\t----\t---\t---\t----\t-----\t---\t---\t-----\t-----\t-----\t-----\t-----\t----\t------\t------\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation with random inputs ===\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
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
        
        // Log internal signals to file
        if (file) begin
            $fwrite(file, "%0d\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%0d\t%b\t%b\t%b\t%b\t%b\t%b\t%b\n", 
                    i, r_button, g_button, key, start, test, rts, rtr, v_in, v_out, cts, ctr,
                    dut.stato, dut.voto0, dut.voto1, dut.voto2, dut.voto3, dut.sign, dut.last_g, dut.last_r);
        end
        
        // Display state transitions
        if (dut.stato == STARTUP) begin
            $display("Time=%0t: Cycle %0d - State STARTUP | test=%b", $time, i, test);
        end
        
        if (dut.stato == STANDBY && start == 1) begin
            $display("Time=%0t: Cycle %0d - STANDBY: start detected", $time, i);
        end
        
        if (dut.stato == GET_IN) begin
            $display("Time=%0t: Cycle %0d - GET_IN | key=%b r_btn=%b g_btn=%b voto0=%b voto1=%b voto2=%b", 
                     $time, i, key, r_button, g_button, dut.voto0, dut.voto1, dut.voto2);
        end
        
        if (dut.stato == START_TX) begin
            $display("Time=%0t: Cycle %0d - START_TX | voto0=%b voto1=%b voto2=%b voto3=%b", 
                     $time, i, dut.voto0, dut.voto1, dut.voto2, dut.voto3);
        end
        
        if (dut.stato == SEND) begin
            $display("Time=%0t: Cycle %0d - SEND | rtr=%b v_out=%b cts=%b", 
                     $time, i, rtr, v_out, cts);
        end
        
        if (dut.stato == TX_2_RX) begin
            $display("Time=%0t: Cycle %0d - TX_2_RX | rts=%b ctr=%b", $time, i, rts, ctr);
        end
        
        if (dut.stato == RECEIVE) begin
            $display("Time=%0t: Cycle %0d - RECEIVE | rts=%b v_in=%b", $time, i, rts, v_in);
        end
        
        if (dut.stato == RX_2_TX) begin
            $display("Time=%0t: Cycle %0d - RX_2_TX | rtr=%b cts=%b", $time, i, rtr, cts);
        end
        
        if (dut.stato == END_TX) begin
            $display("Time=%0t: Cycle %0d - END_TX | rtr=%b", $time, i, rtr);
        end
        
        if (dut.stato == TEST_1) begin
            $display("Time=%0t: Cycle %0d - TEST_1 | v_in=%b sign=%b", $time, i, v_in, dut.sign);
        end
        
        if (dut.stato == TEST_2) begin
            $display("Time=%0t: Cycle %0d - TEST_2 | sign=%b", $time, i, dut.sign);
        end
        
        // Display handshake signals
        if (cts == 1 || ctr == 1) begin
            $display("Time=%0t: Cycle %0d - Handshake | cts=%b ctr=%b rts=%b rtr=%b", 
                     $time, i, cts, ctr, rts, rtr);
        end
        
        // Display calculation progress every 1000 cycles
        if (i % 1000 == 0) begin
            $display("Time=%0t: Cycle %0d | STATO=%0d v_out=%b cts=%b ctr=%b voto[3:0]=%b%b%b%b", 
                     $time, i, dut.stato, v_out, cts, ctr, dut.voto3, dut.voto2, dut.voto1, dut.voto0);
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
    $display("=== b10 Voting System Testbench ===");
    $display("Time\t\trst_n\tstart\tkey\tv_in\tv_out\tcts\tctr\tSTATO\tvoto0\tvoto1\tvoto2\tvoto3");
    $display("----\t\t-----\t-----\t---\t----\t-----\t---\t---\t-----\t-----\t-----\t-----\t-----");
    $monitor("%0t\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%0d\t%b\t%b\t%b\t%b", 
             $time, rst_n, start, key, v_in, v_out, cts, ctr, dut.stato, 
             dut.voto0, dut.voto1, dut.voto2, dut.voto3);
end

// Generate VCD file for waveform viewing (optional)
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    // Explicitly dump all internal signals
    $dumpvars(0, dut.stato);
    $dumpvars(0, dut.voto0);
    $dumpvars(0, dut.voto1);
    $dumpvars(0, dut.voto2);
    $dumpvars(0, dut.voto3);
    $dumpvars(0, dut.sign);
    $dumpvars(0, dut.last_g);
    $dumpvars(0, dut.last_r);
    $dumpvars(0, dut.cts);
    $dumpvars(0, dut.ctr);
end

// State name decoder for display
function [127:0] state_name;
    input [3:0] state;
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

// Additional detailed logging every 100 cycles
initial begin
    @(posedge rst_n);
    
    for (i=0; i<500; i=i+1) begin
        @(posedge clk);
        if (i % 100 == 0) begin
            $display("\n--- Cycle %0d Snapshot ---", i);
            $display("State: %0s (%0d)", state_name(dut.stato), dut.stato);
            $display("Inputs: r_button=%b g_button=%b key=%b start=%b test=%b", 
                     r_button, g_button, key, start, test);
            $display("Handshake: rts=%b rtr=%b cts=%b ctr=%b", rts, rtr, cts, ctr);
            $display("Data: v_in=%b v_out=%b", v_in, v_out);
            $display("Vote registers: voto0=%b voto1=%b voto2=%b voto3=%b", 
                     dut.voto0, dut.voto1, dut.voto2, dut.voto3);
            $display("Sign: %b", dut.sign);
            $display("Button history: last_g=%b last_r=%b", dut.last_g, dut.last_r);
            
            // Additional state-specific information
            case(dut.stato)
                GET_IN: begin
                    $display("Status: Collecting vote input");
                    if (key == 1) begin
                        $display("  Key pressed, buttons: g=%b r=%b", g_button, r_button);
                    end
                end
                START_TX: begin
                    $display("Status: Calculating parity voto3 = voto0 XOR voto1 XOR voto2");
                    $display("  Result: %b XOR %b XOR %b = %b", 
                             dut.voto0, dut.voto1, dut.voto2, dut.voto3);
                end
                SEND: begin
                    $display("Status: Waiting for rtr=%b to send data", rtr);
                    if (dut.voto0 == 0 && dut.voto1 == 1 && dut.voto2 == 1 && dut.voto3 == 0) begin
                        $display("  Special pattern detected (0110) - will go to END_TX");
                    end
                end
                RECEIVE: begin
                    $display("Status: Waiting for rts=%b to receive data", rts);
                end
            endcase
        end
    end
end

// Track button edge detection
reg prev_g, prev_r;
integer g_edge_count, r_edge_count;

initial begin
    @(posedge rst_n);
    prev_g = 0;
    prev_r = 0;
    g_edge_count = 0;
    r_edge_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        // Detect green button rising edge
        if (prev_g == 0 && g_button == 1 && dut.stato == GET_IN) begin
            g_edge_count = g_edge_count + 1;
            $display("Time=%0t: Green button edge detected #%0d", $time, g_edge_count);
        end
        
        // Detect red button rising edge
        if (prev_r == 0 && r_button == 1 && dut.stato == GET_IN) begin
            r_edge_count = r_edge_count + 1;
            $display("Time=%0t: Red button edge detected #%0d", $time, r_edge_count);
        end
        
        prev_g = g_button;
        prev_r = r_button;
    end
    
    #100;
    $display("\n=== Button Edge Detection ===");
    $display("Green button edges: %0d", g_edge_count);
    $display("Red button edges: %0d", r_edge_count);
end

// Track transmission sequences
integer tx_count, rx_count;

initial begin
    @(posedge rst_n);
    tx_count = 0;
    rx_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        // Count transmissions
        if (dut.stato == SEND && cts == 1) begin
            tx_count = tx_count + 1;
            $display("Time=%0t: TX #%0d | v_out=%b", $time, tx_count, v_out);
        end
        
        // Count receptions
        if (dut.stato == RECEIVE && rts == 1) begin
            rx_count = rx_count + 1;
            $display("Time=%0t: RX #%0d | v_in=%b", $time, rx_count, v_in);
        end
    end
    
    #100;
    $display("\n=== Communication Statistics ===");
    $display("Transmissions: %0d", tx_count);
    $display("Receptions: %0d", rx_count);
end

endmodule