`timescale 1ns / 1ps

module tb_top;

// State parameters (must match b12.v)
parameter G0 = 0;
parameter G1 = 1;
parameter G2 = 2;
parameter G3 = 3;
parameter G4 = 4;
parameter G5 = 5;
parameter G6 = 6;
parameter G7 = 7;
parameter G8 = 8;
parameter G9 = 9;
parameter G10 = 10;
parameter G10a = 11;
parameter G11 = 12;
parameter G12 = 13;
parameter Ea = 14;
parameter E0 = 15;
parameter E1 = 16;
parameter K0 = 17;
parameter K1 = 18;
parameter K2 = 19;
parameter K3 = 20;
parameter K4 = 21;
parameter K5 = 22;
parameter K6 = 23;
parameter W0 = 24;
parameter W1 = 25;

// Color parameters
parameter RED = 0;
parameter GREEN = 1;
parameter YELLOW = 2;
parameter BLUE = 3;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg start;
reg [3:0] k;

// Output signals
wire nloss;
wire [3:0] nl;
wire speaker;

// Loop counter
integer i;

// File for logging
integer file;

// Random control variables
reg [7:0] start_prob;  // Probability of start signal
reg [7:0] key_prob;    // Probability of key press

// Instantiate the DUT (Device Under Test)
b12 dut (
    .clock(clk),
    .reset(~rst_n),  // rst_n is active low, but b12 expects active high reset
    .start(start),
    .k(k),
    .nloss(nloss),
    .nl(nl),
    .speaker(speaker)
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
    k = 4'b0000;
    start_prob = 5;   // 5% chance of start pulse
    key_prob = 10;    // 10% chance of key press
    
    // Open file for logging
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\tstart\tk\tnloss\tnl\tspkr\tgamma\twr\taddr\tdata_in\tdata_out\tnum\tsound\tplay\ts\tind\tscan\tmax\ttimebase\tcountP1\n");
    $fwrite(file, "-----\t-----\t----\t-----\t----\t----\t-----\t--\t----\t-------\t--------\t---\t-----\t----\t-\t---\t----\t---\t--------\t-------\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation with random input ===\n");
    $display("This is a Simon Says game circuit testbench");
    $display("Inputs: start (game start), k[3:0] (color buttons)");
    $display("Outputs: nloss (loss indicator), nl[3:0] (LED indicators), speaker\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        
        // Random start signal generation (pulse)
        if ($random % 100 < start_prob && start == 0) begin
            start <= 1;
        end else begin
            start <= 0;
        end
        
        // Random key press generation
        if ($random % 100 < key_prob) begin
            // Press one random key at a time
            case ($random % 4)
                0: k <= 4'b0001;  // RED button
                1: k <= 4'b0010;  // GREEN button
                2: k <= 4'b0100;  // YELLOW button
                3: k <= 4'b1000;  // BLUE button
            endcase
        end else if ($random % 100 < 20) begin
            // 20% chance to release all keys
            k <= 4'b0000;
        end
        
        // Log internal signals to file
        if (file) begin
            $fwrite(file, "%0d\t%b\t%b\t%b\t%b\t%b\t%0d\t%b\t%0d\t%0d\t%0d\t%0d\t%0d\t%b\t%b\t%0d\t%0d\t%0d\t%0d\t%0d\n", 
                    i, start, k, nloss, nl, speaker, dut.gamma, dut.wr, dut.address, 
                    dut.data_in, dut.data_out, dut.num, dut.sound, dut.play, dut.s,
                    dut.ind, dut.scan, dut.max, dut.timebase, dut.countP1);
        end
        
        // Display game start
        if (start == 1) begin
            $display("Time=%0t: Cycle %0d - GAME START", $time, i);
        end
        
        // Display key presses
        if (k != 4'b0000) begin
            $display("Time=%0t: Cycle %0d - KEY PRESS | k=%b (RED=%b GREEN=%b YELLOW=%b BLUE=%b)", 
                     $time, i, k, k[0], k[1], k[2], k[3]);
        end
        
        // Display LED changes
        if (nl != 4'b0000) begin
            $display("Time=%0t: Cycle %0d - LED ON | nl=%b (RED=%b GREEN=%b YELLOW=%b BLUE=%b)", 
                     $time, i, nl, nl[0], nl[1], nl[2], nl[3]);
        end
        
        // Display speaker activity
        if (speaker == 1) begin
            $display("Time=%0t: Cycle %0d - SPEAKER ON | sound code=%0d", 
                     $time, i, dut.sound);
        end
        
        // Display loss condition
        if (nloss == 1) begin
            $display("Time=%0t: Cycle %0d - **LOSS** | state=%0d", 
                     $time, i, dut.gamma);
        end
        
        // Display memory writes
        if (dut.wr == 1) begin
            $display("Time=%0t: Cycle %0d - MEMORY WRITE | addr=%0d data=%0d", 
                     $time, i, dut.address, dut.data_in);
        end
        
        // Display progress every 1000 cycles
        if (i % 1000 == 0) begin
            $display("Time=%0t: Cycle %0d | state=%s(%0d) max_seq=%0d scan=%0d nl=%b speaker=%b", 
                     $time, i, state_name(dut.gamma), dut.gamma, dut.max, dut.scan, nl, speaker);
        end
    end
    
    // Close file and finish simulation
    if (file) $fclose(file);
    
    $display("\n=== Simulation Complete ===");
    $display("Total cycles run: %0d", i);
    $display("Check 'simulation_log.txt' for detailed signal log");
    $finish;
end

// Monitor for debugging
initial begin
    $display("=== b12 Simon Says Game Testbench ===");
    $display("Time\t\trst_n\tstart\tk\tnloss\tnl\tspkr\tgamma");
    $display("----\t\t-----\t-----\t----\t-----\t----\t----\t-----");
    $monitor("%0t\t%b\t%b\t%b\t%b\t%b\t%b\t%0d", 
             $time, rst_n, start, k, nloss, nl, speaker, dut.gamma);
end

// Generate VCD file for waveform viewing
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    // Explicitly dump all internal signals
    $dumpvars(0, dut.gamma);
    $dumpvars(0, dut.wr);
    $dumpvars(0, dut.address);
    $dumpvars(0, dut.data_in);
    $dumpvars(0, dut.data_out);
    $dumpvars(0, dut.num);
    $dumpvars(0, dut.sound);
    $dumpvars(0, dut.play);
    $dumpvars(0, dut.s);
    $dumpvars(0, dut.counterP4);
    $dumpvars(0, dut.count_P3);
    $dumpvars(0, dut.ind);
    $dumpvars(0, dut.scan);
    $dumpvars(0, dut.max);
    $dumpvars(0, dut.timebase);
    $dumpvars(0, dut.countP1);
    // Dump memory array
    for (i=0; i<32; i=i+1) begin
        $dumpvars(0, dut.memory[i]);
    end
end

// State name decoder for display
function [79:0] state_name;
    input [4:0] state;
    begin
        case(state)
            G0: state_name = "G0";
            G1: state_name = "G1";
            G2: state_name = "G2_STORE";
            G3: state_name = "G3_ADDR";
            G4: state_name = "G4_READ";
            G5: state_name = "G5_LED_ON";
            G6: state_name = "G6_WAIT";
            G7: state_name = "G7_PAUSE";
            G8: state_name = "G8_SETUP";
            G9: state_name = "G9_DELAY";
            G10: state_name = "G10_WAIT_KEY";
            G10a: state_name = "G10a_KEY_LED";
            G11: state_name = "G11_KEY_ON";
            G12: state_name = "G12_KEY_OFF";
            Ea: state_name = "Ea_ERROR_A";
            E0: state_name = "E0_ERROR_0";
            E1: state_name = "E1_ERROR_1";
            K0: state_name = "K0_LOSS_0";
            K1: state_name = "K1_LOSS_1";
            K2: state_name = "K2_LOSS_2";
            K3: state_name = "K3_LOSS_3";
            K4: state_name = "K4_LOSS_4";
            K5: state_name = "K5_LOSS_5";
            K6: state_name = "K6_LOSS_6";
            W0: state_name = "W0_WIN_0";
            W1: state_name = "W1_WIN_1";
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
            $display("State: %s (%0d)", state_name(dut.gamma), dut.gamma);
            $display("Inputs: start=%b k=%b (R=%b G=%b Y=%b B=%b)", 
                     start, k, k[0], k[1], k[2], k[3]);
            $display("Outputs: nloss=%b nl=%b speaker=%b", nloss, nl, speaker);
            $display("Memory Control: wr=%b addr=%0d data_in=%0d data_out=%0d", 
                     dut.wr, dut.address, dut.data_in, dut.data_out);
            $display("Game Control:");
            $display("  Random num=%0d, sound=%0d, play=%b", dut.num, dut.sound, dut.play);
            $display("  Sequence: scan=%0d max=%0d", dut.scan, dut.max);
            $display("  Timing: timebase=%0d countP1=%0d", dut.timebase, dut.countP1);
            $display("  Player: ind=%0d", dut.ind);
            $display("Speaker Control: s=%b counterP4=%0d", dut.s, dut.counterP4);
            
            // Display first 8 memory locations
            $display("Memory[0-7]: %0d %0d %0d %0d %0d %0d %0d %0d",
                     dut.memory[0], dut.memory[1], dut.memory[2], dut.memory[3],
                     dut.memory[4], dut.memory[5], dut.memory[6], dut.memory[7]);
        end
    end
end

// Track state transitions
reg [4:0] prev_state;
integer state_transition_count;

initial begin
    @(posedge rst_n);
    prev_state = dut.gamma;
    state_transition_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.gamma != prev_state) begin
            state_transition_count = state_transition_count + 1;
            $display("Time=%0t: STATE TRANSITION #%0d | %s(%0d) -> %s(%0d)", 
                     $time, state_transition_count, 
                     state_name(prev_state), prev_state,
                     state_name(dut.gamma), dut.gamma);
            prev_state = dut.gamma;
        end
    end
    
    #100;
    $display("\n=== State Transition Summary ===");
    $display("Total state transitions: %0d", state_transition_count);
end

// Track game statistics
integer game_starts;
integer win_state_entries;
integer loss_state_entries;
integer max_sequence_reached;

initial begin
    @(posedge rst_n);
    game_starts = 0;
    win_state_entries = 0;
    loss_state_entries = 0;
    max_sequence_reached = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        // Count game starts
        if (start == 1) begin
            game_starts = game_starts + 1;
            $display("Time=%0t: GAME START #%0d", $time, game_starts);
        end
        
        // Count win states
        if (dut.gamma == W0 && prev_state != W0 && prev_state != W1) begin
            win_state_entries = win_state_entries + 1;
            $display("Time=%0t: ENTERING WIN STATE! Total wins: %0d", $time, win_state_entries);
        end
        
        // Count loss indicators
        if (nloss == 1 && (dut.gamma == Ea || dut.gamma >= K0)) begin
            if (dut.gamma != prev_state) begin
                loss_state_entries = loss_state_entries + 1;
                $display("Time=%0t: ENTERING LOSS STATE! Total losses: %0d", $time, loss_state_entries);
            end
        end
        
        // Track maximum sequence
        if (dut.max > max_sequence_reached) begin
            max_sequence_reached = dut.max;
            $display("Time=%0t: NEW MAX SEQUENCE LENGTH: %0d", $time, max_sequence_reached);
        end
    end
    
    #100;
    $display("\n=== Game Statistics ===");
    $display("Total game starts: %0d", game_starts);
    $display("Win state entries: %0d", win_state_entries);
    $display("Loss state entries: %0d", loss_state_entries);
    $display("Maximum sequence reached: %0d", max_sequence_reached);
end

// Track memory operations
integer write_count;
reg [31:0] last_write_addr, last_write_data;

initial begin
    @(posedge rst_n);
    write_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.wr == 1) begin
            write_count = write_count + 1;
            last_write_addr = dut.address;
            last_write_data = dut.data_in;
            $display("Time=%0t: MEMORY WRITE #%0d | addr=%0d data=%0d (color=%s)", 
                     $time, write_count, dut.address, dut.data_in,
                     color_name(dut.data_in));
        end
    end
    
    #100;
    $display("\n=== Memory Operations Summary ===");
    $display("Total writes: %0d", write_count);
    $display("Last write: addr=%0d data=%0d", last_write_addr, last_write_data);
end

// Color name decoder
function [47:0] color_name;
    input [1:0] color;
    begin
        case(color)
            RED: color_name = "RED";
            GREEN: color_name = "GREEN";
            YELLOW: color_name = "YELLOW";
            BLUE: color_name = "BLUE";
            default: color_name = "UNKNOWN";
        endcase
    end
endfunction

// Track sound generation
integer sound_changes;
reg [3:0] prev_sound;

initial begin
    @(posedge rst_n);
    sound_changes = 0;
    prev_sound = dut.sound;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.play == 1 && dut.sound != prev_sound) begin
            sound_changes = sound_changes + 1;
            $display("Time=%0t: SOUND CHANGE #%0d | sound code=%0d", 
                     $time, sound_changes, dut.sound);
            prev_sound = dut.sound;
        end
    end
    
    #100;
    $display("\n=== Sound Generation Summary ===");
    $display("Total sound changes: %0d", sound_changes);
end

// Timeout watchdog - detect if stuck in a state
integer stuck_counter;
reg [4:0] stuck_state;

initial begin
    @(posedge rst_n);
    stuck_counter = 0;
    stuck_state = dut.gamma;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.gamma == stuck_state) begin
            stuck_counter = stuck_counter + 1;
            if (stuck_counter == 1000) begin
                $display("Time=%0t: WARNING - Stuck in state %s for 1000 cycles", 
                         $time, state_name(dut.gamma));
            end
        end else begin
            stuck_counter = 0;
            stuck_state = dut.gamma;
        end
    end
end

endmodule
