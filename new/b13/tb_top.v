`timescale 1ns / 1ps

module tb_top;

// State parameters for S1 FSM (must match b13.v)
parameter GP001 = 0;
parameter GP010 = 1;
parameter GP011 = 2;
parameter GP100 = 3;
parameter GP100w = 4;
parameter GP101 = 5;
parameter GP110 = 6;
parameter GP111 = 7;

// State parameters for S2 FSM
parameter GP01 = 0;
parameter GP10 = 1;
parameter GP11 = 2;
parameter GP11w = 3;

// Bit transmission states
parameter START_BIT = 0;
parameter STOP_BIT = 1;
parameter BIT0 = 2;
parameter BIT1 = 3;
parameter BIT2 = 4;
parameter BIT3 = 5;
parameter BIT4 = 6;
parameter BIT5 = 7;
parameter BIT6 = 8;
parameter BIT7 = 9;

// Interface states
parameter G_IDLE = 0;
parameter G_LOAD = 1;
parameter G_SEND = 2;
parameter G_WAIT_END = 3;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg eoc;
reg dsr;
reg [7:0] data_in;

// Output signals
wire soc;
wire load_dato;
wire add_mpx2;
wire mux_en;
wire errorr;
wire data_out;
wire [3:0] canale;

// Loop counter
integer i;

// File for logging
integer file;

// Random control variables
reg [7:0] eoc_prob;     // Probability of eoc being high
reg [7:0] dsr_prob;     // Probability of dsr being high
integer eoc_delay;      // Delay counter for eoc response
reg eoc_active;

// Instantiate the DUT (Device Under Test)
b13 dut (
    .clock(clk),
    .reset(~rst_n),  // rst_n is active low, but b13 expects active high reset
    .eoc(eoc),
    .dsr(dsr),
    .data_in(data_in),
    .soc(soc),
    .load_dato(load_dato),
    .add_mpx2(add_mpx2),
    .mux_en(mux_en),
    .errorr(errorr),
    .data_out(data_out),
    .canale(canale)
);

// Clock generation - 10ns period (100MHz)
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// EOC (End of Conversion) stimulus generator
// Responds to SOC (Start of Conversion) after a delay
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        eoc <= 1'b0;
        eoc_delay <= 0;
        eoc_active <= 1'b0;
    end else begin
        // When SOC goes high, prepare to send EOC after random delay
        if (soc == 1'b1 && !eoc_active) begin
            eoc_delay <= 5 + ($random % 15);  // Random delay 5-20 cycles
            eoc_active <= 1'b1;
            eoc <= 1'b1;  // EOC stays high initially
        end
        
        // Count down delay
        if (eoc_active) begin
            if (eoc_delay > 0) begin
                eoc_delay <= eoc_delay - 1;
                eoc <= 1'b1;  // Keep EOC high during conversion
            end else begin
                eoc <= 1'b0;  // Lower EOC to signal conversion complete
                if (soc == 1'b0) begin
                    eoc_active <= 1'b0;  // Reset when SOC goes low
                end
            end
        end
    end
end

// Test stimulus
initial begin
    // Initialize signals
    rst_n = 0;
    dsr = 1;  // Data set ready - mostly high
    data_in = 8'h00;
    eoc_prob = 30;
    dsr_prob = 90;  // DSR is usually ready
    
    // Open file for logging
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\teoc\tdsr\tdata_in\tsoc\tload_dato\tadd_mpx2\tmux_en\terrorr\tdata_out\tcanale\tS1\tS2\titfc_state\tnext_bit\ttx_conta\tsend_en\ttre\tmpx\trdy\tsend_data\n");
    $fwrite(file, "-----\t---\t---\t-------\t---\t---------\t--------\t------\t------\t--------\t------\t--\t--\t----------\t--------\t--------\t-------\t---\t---\t---\t---------\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation with random input ===\n");
    $display("This is an ADC Interface with Serial Transmission testbench");
    $display("Inputs: eoc (end of conversion), dsr (data set ready), data_in[7:0]");
    $display("Outputs: soc (start conversion), canale[3:0] (channel), data_out (serial)\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        
        // Random data_in generation
        if ($random % 100 < 20) begin  // 20% chance to change data
            data_in <= $random;
        end
        
        // Random dsr generation (mostly high, occasionally low)
        if ($random % 100 < (100 - dsr_prob)) begin
            dsr <= 1'b0;
        end else begin
            dsr <= 1'b1;
        end
        
        // Log internal signals to file
        if (file) begin
            $fwrite(file, "%0d\t%b\t%b\t%h\t%b\t%b\t%b\t%b\t%b\t%b\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\t%b\t%b\t%b\t%b\t%b\n", 
                    i, eoc, dsr, data_in, soc, load_dato, add_mpx2, mux_en, errorr, data_out,
                    canale, dut.S1, dut.S2, dut.itfc_state, dut.next_bit, dut.tx_conta,
                    dut.send_en, dut.tre, dut.mpx, dut.rdy, dut.send_data);
        end
        
        // Display SOC pulses
        if (soc == 1'b1) begin
            $display("Time=%0t: Cycle %0d - SOC (Start of Conversion) | channel=%0d", 
                     $time, i, canale);
        end
        
        // Display EOC signals
        if (eoc == 1'b0 && soc == 1'b1) begin
            $display("Time=%0t: Cycle %0d - EOC (End of Conversion) | loading data=%h", 
                     $time, i, data_in);
        end
        
        // Display channel changes
        if (i > 0 && canale != 0) begin
            if (i % 100 == 0 || load_dato == 1) begin
                $display("Time=%0t: Cycle %0d - Channel=%0d data_in=%h load=%b", 
                         $time, i, canale, data_in, load_dato);
            end
        end
        
        // Display serial transmission
        if (dut.send_en == 1 && dut.next_bit == START_BIT && dut.tx_conta == 0) begin
            $display("Time=%0t: Cycle %0d - SERIAL TX START | data=%h (%d)", 
                     $time, i, dut.out_reg, dut.out_reg);
        end
        
        if (dut.tx_end == 1) begin
            $display("Time=%0t: Cycle %0d - SERIAL TX END", $time, i);
        end
        
        // Display errors
        if (errorr == 1) begin
            $display("Time=%0t: Cycle %0d - **ERROR** | S1=%0d S2=%0d itfc=%0d tre=%b dsr=%b", 
                     $time, i, dut.S1, dut.S2, dut.itfc_state, dut.tre, dsr);
        end
        
        // Display multiplexer control
        if (add_mpx2 == 1) begin
            $display("Time=%0t: Cycle %0d - MUX ADDRESS INCREMENT | mpx=%b", 
                     $time, i, dut.mpx);
        end
        
        // Display progress every 1000 cycles
        if (i % 1000 == 0) begin
            $display("Time=%0t: Cycle %0d | S1=%s(%0d) S2=%s(%0d) itfc=%s(%0d) channel=%0d", 
                     $time, i, s1_name(dut.S1), dut.S1, s2_name(dut.S2), dut.S2,
                     itfc_name(dut.itfc_state), dut.itfc_state, canale);
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
    $display("=== b13 ADC Interface with Serial TX Testbench ===");
    $display("Time\t\trst_n\tsoc\teoc\tcanale\tload\tdata_out\terrorr\tS1\tS2");
    $display("----\t\t-----\t---\t---\t------\t----\t--------\t------\t--\t--");
    $monitor("%0t\t%b\t%b\t%b\t%0d\t%b\t%b\t%b\t%0d\t%0d", 
             $time, rst_n, soc, eoc, canale, load_dato, data_out, errorr, dut.S1, dut.S2);
end

// Generate VCD file for waveform viewing
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    // Explicitly dump all internal signals
    $dumpvars(0, dut.S1);
    $dumpvars(0, dut.S2);
    $dumpvars(0, dut.itfc_state);
    $dumpvars(0, dut.next_bit);
    $dumpvars(0, dut.mpx);
    $dumpvars(0, dut.rdy);
    $dumpvars(0, dut.send_data);
    $dumpvars(0, dut.confirm);
    $dumpvars(0, dut.shot);
    $dumpvars(0, dut.send_en);
    $dumpvars(0, dut.tre);
    $dumpvars(0, dut.out_reg);
    $dumpvars(0, dut.tx_end);
    $dumpvars(0, dut.send);
    $dumpvars(0, dut.load);
    $dumpvars(0, dut.tx_conta);
    $dumpvars(0, dut.conta_tmp);
end

// State name decoders for display
function [79:0] s1_name;
    input [3:0] state;
    begin
        case(state)
            GP001: s1_name = "GP001_MUX_EN";
            GP010: s1_name = "GP010_DELAY";
            GP011: s1_name = "GP011_SOC";
            GP100: s1_name = "GP100_WAIT_RDY";
            GP100w: s1_name = "GP100w_WAIT";
            GP101: s1_name = "GP101_WAIT_EOC";
            GP110: s1_name = "GP110_LOAD";
            GP111: s1_name = "GP111_SEND";
            default: s1_name = "UNKNOWN";
        endcase
    end
endfunction

function [79:0] s2_name;
    input [1:0] state;
    begin
        case(state)
            GP01: s2_name = "GP01_IDLE";
            GP10: s2_name = "GP10_SHOT";
            GP11: s2_name = "GP11_CONFIRM";
            GP11w: s2_name = "GP11w_WAIT";
            default: s2_name = "UNKNOWN";
        endcase
    end
endfunction

function [79:0] itfc_name;
    input [1:0] state;
    begin
        case(state)
            G_IDLE: itfc_name = "G_IDLE";
            G_LOAD: itfc_name = "G_LOAD";
            G_SEND: itfc_name = "G_SEND";
            G_WAIT_END: itfc_name = "G_WAIT_END";
            default: itfc_name = "UNKNOWN";
        endcase
    end
endfunction

function [79:0] bit_name;
    input [3:0] state;
    begin
        case(state)
            START_BIT: bit_name = "START_BIT";
            BIT0: bit_name = "BIT0";
            BIT1: bit_name = "BIT1";
            BIT2: bit_name = "BIT2";
            BIT3: bit_name = "BIT3";
            BIT4: bit_name = "BIT4";
            BIT5: bit_name = "BIT5";
            BIT6: bit_name = "BIT6";
            BIT7: bit_name = "BIT7";
            STOP_BIT: bit_name = "STOP_BIT";
            default: bit_name = "UNKNOWN";
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
            $display("State Machines:");
            $display("  S1: %s (%0d)", s1_name(dut.S1), dut.S1);
            $display("  S2: %s (%0d)", s2_name(dut.S2), dut.S2);
            $display("  Interface: %s (%0d)", itfc_name(dut.itfc_state), dut.itfc_state);
            $display("  TX Bit: %s (%0d)", bit_name(dut.next_bit), dut.next_bit);
            $display("Inputs: eoc=%b dsr=%b data_in=%h (%0d)", eoc, dsr, data_in, data_in);
            $display("ADC Control: soc=%b load_dato=%b mux_en=%b canale=%0d", 
                     soc, load_dato, mux_en, canale);
            $display("MUX Control: add_mpx2=%b mpx=%b conta_tmp=%0d", 
                     add_mpx2, dut.mpx, dut.conta_tmp);
            $display("Data Flow: rdy=%b send_data=%b shot=%b confirm=%b", 
                     dut.rdy, dut.send_data, dut.shot, dut.confirm);
            $display("Serial TX: send_en=%b tre=%b tx_end=%b data_out=%b", 
                     dut.send_en, dut.tre, dut.tx_end, data_out);
            $display("  out_reg=%h (%0d) tx_conta=%0d", 
                     dut.out_reg, dut.out_reg, dut.tx_conta);
            $display("Error: errorr=%b", errorr);
        end
    end
end

// Track state transitions for S1
reg [3:0] prev_s1;
integer s1_transition_count;

initial begin
    @(posedge rst_n);
    prev_s1 = dut.S1;
    s1_transition_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.S1 != prev_s1) begin
            s1_transition_count = s1_transition_count + 1;
            $display("Time=%0t: S1 TRANSITION #%0d | %s(%0d) -> %s(%0d)", 
                     $time, s1_transition_count, 
                     s1_name(prev_s1), prev_s1,
                     s1_name(dut.S1), dut.S1);
            prev_s1 = dut.S1;
        end
    end
    
    #100;
    $display("\n=== S1 State Machine Summary ===");
    $display("Total S1 transitions: %0d", s1_transition_count);
end

// Track state transitions for S2
reg [1:0] prev_s2;
integer s2_transition_count;

initial begin
    @(posedge rst_n);
    prev_s2 = dut.S2;
    s2_transition_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.S2 != prev_s2) begin
            s2_transition_count = s2_transition_count + 1;
            $display("Time=%0t: S2 TRANSITION #%0d | %s(%0d) -> %s(%0d)", 
                     $time, s2_transition_count, 
                     s2_name(prev_s2), prev_s2,
                     s2_name(dut.S2), dut.S2);
            prev_s2 = dut.S2;
        end
    end
    
    #100;
    $display("\n=== S2 State Machine Summary ===");
    $display("Total S2 transitions: %0d", s2_transition_count);
end

// Track conversion cycles
integer conversion_count;
integer load_count;

initial begin
    @(posedge rst_n);
    conversion_count = 0;
    load_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        // Count conversions (SOC pulses)
        if (soc == 1'b1 && dut.S1 == GP011) begin
            conversion_count = conversion_count + 1;
            $display("Time=%0t: CONVERSION #%0d started on channel %0d", 
                     $time, conversion_count, canale);
        end
        
        // Count data loads
        if (load_dato == 1'b1) begin
            load_count = load_count + 1;
            $display("Time=%0t: DATA LOAD #%0d | data=%h channel=%0d", 
                     $time, load_count, data_in, canale);
        end
    end
    
    #100;
    $display("\n=== ADC Conversion Summary ===");
    $display("Total conversions started: %0d", conversion_count);
    $display("Total data loads: %0d", load_count);
end

// Track serial transmissions
integer tx_start_count;
integer tx_complete_count;
reg [7:0] tx_data_history [0:99];
integer tx_history_idx;

initial begin
    @(posedge rst_n);
    tx_start_count = 0;
    tx_complete_count = 0;
    tx_history_idx = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        // Count transmission starts
        if (dut.send_en == 1 && dut.next_bit == START_BIT && dut.tx_conta == 0) begin
            tx_start_count = tx_start_count + 1;
            if (tx_history_idx < 100) begin
                tx_data_history[tx_history_idx] = dut.out_reg;
                tx_history_idx = tx_history_idx + 1;
            end
            $display("Time=%0t: SERIAL TX START #%0d | data=%h (%0d)", 
                     $time, tx_start_count, dut.out_reg, dut.out_reg);
        end
        
        // Count transmission completions
        if (dut.tx_end == 1) begin
            tx_complete_count = tx_complete_count + 1;
            $display("Time=%0t: SERIAL TX COMPLETE #%0d", $time, tx_complete_count);
        end
    end
    
    #100;
    $display("\n=== Serial Transmission Summary ===");
    $display("Total transmissions started: %0d", tx_start_count);
    $display("Total transmissions completed: %0d", tx_complete_count);
    $display("First 10 transmitted bytes:");
    for (i=0; i<10 && i<tx_history_idx; i=i+1) begin
        $display("  TX[%0d] = %h (%0d)", i, tx_data_history[i], tx_data_history[i]);
    end
end

// Track error conditions
integer error_count;
reg prev_errorr;

initial begin
    @(posedge rst_n);
    error_count = 0;
    prev_errorr = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (errorr == 1 && prev_errorr == 0) begin
            error_count = error_count + 1;
            $display("Time=%0t: ERROR #%0d | tre=%b dsr=%b load=%b send=%b", 
                     $time, error_count, dut.tre, dsr, dut.load, dut.send);
        end
        prev_errorr = errorr;
    end
    
    #100;
    $display("\n=== Error Summary ===");
    $display("Total errors detected: %0d", error_count);
end

// Track channel scanning
integer channel_changes;
reg [3:0] prev_canale;

initial begin
    @(posedge rst_n);
    channel_changes = 0;
    prev_canale = canale;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (canale != prev_canale) begin
            channel_changes = channel_changes + 1;
            $display("Time=%0t: CHANNEL CHANGE #%0d | %0d -> %0d", 
                     $time, channel_changes, prev_canale, canale);
            prev_canale = canale;
        end
    end
    
    #100;
    $display("\n=== Channel Scanning Summary ===");
    $display("Total channel changes: %0d", channel_changes);
    $display("Average conversions per cycle: %0d", channel_changes / 8);
end

// Decode and display serial transmission bits
reg [7:0] rx_byte;
reg [3:0] rx_bit_count;
reg rx_active;

initial begin
    @(posedge rst_n);
    rx_byte = 0;
    rx_bit_count = 0;
    rx_active = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.send_en && dut.tx_conta > dut.DelayTime) begin
            case(dut.next_bit)
                START_BIT: begin
                    rx_active = 1;
                    rx_bit_count = 0;
                    rx_byte = 0;
                    $display("Time=%0t: RX - Start bit detected", $time);
                end
                BIT0, BIT1, BIT2, BIT3, BIT4, BIT5, BIT6, BIT7: begin
                    if (rx_active) begin
                        rx_byte[7-rx_bit_count] = data_out;
                        rx_bit_count = rx_bit_count + 1;
                    end
                end
                STOP_BIT: begin
                    if (rx_active) begin
                        $display("Time=%0t: RX - Complete byte received: %h (%0d)", 
                                 $time, rx_byte, rx_byte);
                        rx_active = 0;
                    end
                end
            endcase
        end
    end
end

endmodule
