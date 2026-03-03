`timescale 1ns / 1ps

module tb_top;

// State parameters (must match all processor variants)
parameter FETCH = 0;
parameter EXEC = 1;

// Value parameters
parameter ZERO = 0;
parameter ONE = 1;
parameter TWO = 2;
parameter THREE = 3;
parameter FOUR = 4;
parameter FIVE = 5;
parameter SIX = 6;
parameter SEVEN = 7;
parameter EIGHT = 8;
parameter NINE = 9;
parameter TEN = 10;
parameter ELEVEN = 11;
parameter TWELVE = 12;
parameter THIRTEEN = 13;
parameter FOURTEEN = 14;
parameter FIFTEEN = 15;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals for b22
reg [31:0] si;

// Output signals from b22
wire [19:0] so;
wire rd;
wire wr;

// Loop counter
integer i;

// File for logging
integer file;

// Tracking variables
integer rd_transitions;
integer wr_transitions;
integer so_changes;
reg prev_rd, prev_wr;
reg [19:0] prev_so;

// Instantiate the DUT (Device Under Test)
b22 dut (
    .clock(clk),
    .reset(~rst_n),  // rst_n is active low, but b22 expects active high reset
    .si(si),
    .so(so),
    .rd(rd),
    .wr(wr)
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
    si = 32'h00000000;
    
    // Open file for logging
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\tsi\t\tso\t\trd\twr\taddr_1\t\taddr_2\t\taddr_3\t\trd_1\trd_2\trd_3\twr_1\twr_2\twr_3\tstate_1\tstate_2\tstate_3\treg3_1\t\treg3_2\t\treg3_3\t\tB_1\tB_2\tB_3\n");
    $fwrite(file, "-----\t--------\t-----\t\t--\t--\t-----\t\t-----\t\t-----\t\t----\t----\t----\t----\t----\t----\t-------\t-------\t-------\t--------\t--------\t--------\t---\t---\t---\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation for b22 with random inputs ===\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        
        // Random input generation
        si <= $random;
        
        // Generate specific test patterns every 1000 cycles
        if (i % 1000 == 0) begin
            si <= 32'hFFFFFFFF;  // Max value
        end
        else if (i % 1000 == 1) begin
            si <= 32'h00000000;  // Min value
        end
        else if (i % 1000 == 2) begin
            si <= 32'hAAAAAAAA;  // Alternating pattern
        end
        else if (i % 1000 == 3) begin
            si <= 32'h55555555;  // Alternating pattern
        end
        else if (i % 1000 == 4) begin
            si <= 32'h0000FFFF;  // Lower half max
        end
        else if (i % 1000 == 5) begin
            si <= 32'hFFFF0000;  // Upper half max
        end
        else if (i % 1000 == 6) begin
            si <= 32'h00FF00FF;  // Byte pattern
        end
        else if (i % 1000 == 7) begin
            si <= 32'hFF00FF00;  // Byte pattern
        end
        else if (i % 1000 == 8) begin
            si <= 32'h12345678;  // Specific pattern
        end
        else if (i % 1000 == 9) begin
            si <= 32'h87654321;  // Reverse pattern
        end
        
        // Log to file
        if (file) begin
            $fwrite(file, "%0d\t%h\t%h\t%b\t%b\t%h\t%h\t%h\t%b\t%b\t%b\t%b\t%b\t%b\t%0d\t%0d\t%0d\t%h\t%h\t%h\t%b\t%b\t%b\n",
                    i, si, so, rd, wr,
                    dut.addr_1, dut.addr_2, dut.addr_3,
                    dut.rd_1, dut.rd_2, dut.rd_3,
                    dut.wr_1, dut.wr_2, dut.wr_3,
                    dut.P1.state, dut.P2.state, dut.P3.state,
                    dut.P1.reg3, dut.P2.reg3, dut.P3.reg3,
                    dut.P1.B, dut.P2.B, dut.P3.B);
        end
        
        // Display state transitions (first 100 cycles only)
        if (i < 100) begin
            if (dut.P1.state == FETCH) begin
                $display("Time=%0t: Cycle %0d - P1 FETCH | MAR=%0d datai_1=%h rd_1=%b", 
                         $time, i, dut.P1.MAR, dut.datai_1, dut.rd_1);
            end
            if (dut.P2.state == FETCH) begin
                $display("Time=%0t: Cycle %0d - P2 FETCH | MAR=%0d datai_2=%h rd_2=%b", 
                         $time, i, dut.P2.MAR, dut.datai_2, dut.rd_2);
            end
            if (dut.P3.state == FETCH) begin
                $display("Time=%0t: Cycle %0d - P3 FETCH | MAR=%0d datai_3=%h rd_3=%b", 
                         $time, i, dut.P3.MAR, dut.datai_3, dut.rd_3);
            end
        end
        
        // Display combined outputs every 1000 cycles
        if (i % 1000 == 0) begin
            $display("\nTime=%0t: Cycle %0d | si=%h so=%h rd=%b wr=%b", 
                     $time, i, si, so, rd, wr);
            $display("  P1 (b14):     state=%0d addr=%h reg3=%h B=%b", 
                     dut.P1.state, dut.addr_1, dut.P1.reg3, dut.P1.B);
            $display("  P2 (b14_1):   state=%0d addr=%h reg3=%h B=%b", 
                     dut.P2.state, dut.addr_2, dut.P2.reg3, dut.P2.B);
            $display("  P3 (b14rev):  state=%0d addr=%h reg3=%h B=%b", 
                     dut.P3.state, dut.addr_3, dut.P3.reg3, dut.P3.B);
        end
    end
    
    // Close file and finish simulation
    if (file) $fclose(file);
    
    $display("\n=== Simulation Complete ===");
    $display("Total cycles run: %0d", i);
    $display("rd transitions: %0d", rd_transitions);
    $display("wr transitions: %0d", wr_transitions);
    $display("so changes: %0d", so_changes);
    $display("Check 'simulation_log.txt' for detailed signal log");
    $finish;
end

// Monitor for debugging
initial begin
    $display("=== b22 Circuit Testbench ===");
    $display("Time\t\trst_n\tsi\t\tso\t\trd\twr\taddr_1\t\taddr_2\t\taddr_3\t\tstate_1\tstate_2\tstate_3");
    $display("----\t\t-----\t--------\t-----\t\t--\t--\t-----\t\t-----\t\t-----\t\t-------\t-------\t-------");
    $monitor("%0t\t%b\t%h\t%h\t%b\t%b\t%h\t%h\t%h\t%0d\t%0d\t%0d",
             $time, rst_n, si, so, rd, wr, 
             dut.addr_1, dut.addr_2, dut.addr_3,
             dut.P1.state, dut.P2.state, dut.P3.state);
end

// Generate VCD file for waveform viewing
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    
    // Dump top-level DUT signals
    $dumpvars(0, dut.addr_1);
    $dumpvars(0, dut.addr_2);
    $dumpvars(0, dut.addr_3);
    $dumpvars(0, dut.datai_1);
    $dumpvars(0, dut.datai_2);
    $dumpvars(0, dut.datai_3);
    $dumpvars(0, dut.datao_1);
    $dumpvars(0, dut.datao_2);
    $dumpvars(0, dut.datao_3);
    $dumpvars(0, dut.rd_1);
    $dumpvars(0, dut.rd_2);
    $dumpvars(0, dut.rd_3);
    $dumpvars(0, dut.wr_1);
    $dumpvars(0, dut.wr_2);
    $dumpvars(0, dut.wr_3);
    
    // Dump P1 (b14) signals
    $dumpvars(0, dut.P1.state);
    $dumpvars(0, dut.P1.reg0);
    $dumpvars(0, dut.P1.reg1);
    $dumpvars(0, dut.P1.reg2);
    $dumpvars(0, dut.P1.reg3);
    $dumpvars(0, dut.P1.B);
    $dumpvars(0, dut.P1.MAR);
    $dumpvars(0, dut.P1.IR);
    $dumpvars(0, dut.P1.r);
    $dumpvars(0, dut.P1.m);
    
    // Dump P2 (b14_1) signals
    $dumpvars(0, dut.P2.state);
    $dumpvars(0, dut.P2.reg0);
    $dumpvars(0, dut.P2.reg1);
    $dumpvars(0, dut.P2.reg2);
    $dumpvars(0, dut.P2.reg3);
    $dumpvars(0, dut.P2.B);
    $dumpvars(0, dut.P2.MAR);
    $dumpvars(0, dut.P2.IR);
    $dumpvars(0, dut.P2.r);
    $dumpvars(0, dut.P2.m);
    
    // Dump P3 (b14rev) signals
    $dumpvars(0, dut.P3.state);
    $dumpvars(0, dut.P3.reg0);
    $dumpvars(0, dut.P3.reg1);
    $dumpvars(0, dut.P3.reg2);
    $dumpvars(0, dut.P3.reg3);
    $dumpvars(0, dut.P3.B);
    $dumpvars(0, dut.P3.MAR);
    $dumpvars(0, dut.P3.IR);
    $dumpvars(0, dut.P3.r);
    $dumpvars(0, dut.P3.m);
end

// Detailed snapshot every 100 cycles
initial begin
    @(posedge rst_n);
    
    for (i=0; i<500; i=i+1) begin
        @(posedge clk);
        if (i % 100 == 0) begin
            $display("\n========== Cycle %0d Snapshot ==========", i);
            $display("Inputs:");
            $display("  si=%h (%0d)", si, si);
            $display("Outputs:");
            $display("  so=%h (%0d) [calc: (%h + %h - %h) mod 2^20]", 
                     so, so, dut.addr_1, dut.addr_2, dut.addr_3);
            $display("  rd=%b [calc: (rd_1=%b ^ ~rd_2=%b) | rd_3=%b]", 
                     rd, dut.rd_1, dut.rd_2, dut.rd_3);
            $display("  wr=%b [calc: (wr_1=%b ^ ~wr_2=%b) | wr_3=%b]", 
                     wr, dut.wr_1, dut.wr_2, dut.wr_3);
            
            $display("\nInternal routing signals:");
            $display("  datai_1=%h datao_1=%h", dut.datai_1, dut.datao_1);
            $display("  datai_2=%h datao_2=%h", dut.datai_2, dut.datao_2);
            $display("  datai_3=%h datao_3=%h", dut.datai_3, dut.datao_3);
            
            $display("\nP1 (b14) state:");
            $display("  state=%0d IR=%h MAR=%h", dut.P1.state, dut.P1.IR, dut.P1.MAR);
            $display("  reg0=%h reg1=%h reg2=%h reg3=%h", 
                     dut.P1.reg0, dut.P1.reg1, dut.P1.reg2, dut.P1.reg3);
            $display("  r=%h m=%h B=%b", dut.P1.r, dut.P1.m, dut.P1.B);
            
            $display("\nP2 (b14_1) state:");
            $display("  state=%0d IR=%h MAR=%h", dut.P2.state, dut.P2.IR, dut.P2.MAR);
            $display("  reg0=%h reg1=%h reg2=%h reg3=%h", 
                     dut.P2.reg0, dut.P2.reg1, dut.P2.reg2, dut.P2.reg3);
            $display("  r=%h m=%h B=%b", dut.P2.r, dut.P2.m, dut.P2.B);
            
            $display("\nP3 (b14rev) state:");
            $display("  state=%0d IR=%h MAR=%h", dut.P3.state, dut.P3.IR, dut.P3.MAR);
            $display("  reg0=%h reg1=%h reg2=%h reg3=%h", 
                     dut.P3.reg0, dut.P3.reg1, dut.P3.reg2, dut.P3.reg3);
            $display("  r=%h m=%h B=%b", dut.P3.r, dut.P3.m, dut.P3.B);
        end
    end
end

// Track rd and wr transitions
initial begin
    @(posedge rst_n);
    prev_rd = rd;
    prev_wr = wr;
    rd_transitions = 0;
    wr_transitions = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (rd != prev_rd) begin
            rd_transitions = rd_transitions + 1;
            if (rd_transitions < 50) begin
                $display("Time=%0t: Cycle %0d - rd changed: %b -> %b (rd_1=%b rd_2=%b rd_3=%b)", 
                         $time, i, prev_rd, rd, dut.rd_1, dut.rd_2, dut.rd_3);
            end
            prev_rd = rd;
        end
        
        if (wr != prev_wr) begin
            wr_transitions = wr_transitions + 1;
            if (wr_transitions < 50) begin
                $display("Time=%0t: Cycle %0d - wr changed: %b -> %b (wr_1=%b wr_2=%b wr_3=%b)", 
                         $time, i, prev_wr, wr, dut.wr_1, dut.wr_2, dut.wr_3);
            end
            prev_wr = wr;
        end
    end
    
    #100;
    $display("\n=== Transition Summary ===");
    $display("rd transitions: %0d", rd_transitions);
    $display("wr transitions: %0d", wr_transitions);
end

// Monitor output changes
initial begin
    @(posedge rst_n);
    prev_so = so;
    so_changes = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (so != prev_so) begin
            so_changes = so_changes + 1;
            if (so_changes < 30) begin
                $display("Time=%0t: so changed: %h -> %h (addr_1=%h addr_2=%h addr_3=%h)", 
                         $time, prev_so, so, dut.addr_1, dut.addr_2, dut.addr_3);
            end
            prev_so = so;
        end
    end
    
    #100;
    $display("Total so changes: %0d", so_changes);
end

// Track ALL register modifications for all three processors
reg [31:0] prev_p1_reg0, prev_p1_reg1, prev_p1_reg2, prev_p1_reg3;
reg [31:0] prev_p2_reg0, prev_p2_reg1, prev_p2_reg2, prev_p2_reg3;
reg [31:0] prev_p3_reg0, prev_p3_reg1, prev_p3_reg2, prev_p3_reg3;
integer p1_reg_changes, p2_reg_changes, p3_reg_changes;

initial begin
    @(posedge rst_n);
    prev_p1_reg0 = 0; prev_p1_reg1 = 0; prev_p1_reg2 = 0; prev_p1_reg3 = 0;
    prev_p2_reg0 = 0; prev_p2_reg1 = 0; prev_p2_reg2 = 0; prev_p2_reg3 = 0;
    prev_p3_reg0 = 0; prev_p3_reg1 = 0; prev_p3_reg2 = 0; prev_p3_reg3 = 0;
    p1_reg_changes = 0;
    p2_reg_changes = 0;
    p3_reg_changes = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        // Track P1 register changes
        if (dut.P1.reg0 != prev_p1_reg0 || dut.P1.reg1 != prev_p1_reg1 || 
            dut.P1.reg2 != prev_p1_reg2 || dut.P1.reg3 != prev_p1_reg3) begin
            p1_reg_changes = p1_reg_changes + 1;
            if (i < 200 && dut.P1.reg3 != prev_p1_reg3) begin
                $display("Time=%0t: P1.reg3 changed: %h -> %h (incr)", 
                         $time, prev_p1_reg3, dut.P1.reg3);
            end
            prev_p1_reg0 = dut.P1.reg0;
            prev_p1_reg1 = dut.P1.reg1;
            prev_p1_reg2 = dut.P1.reg2;
            prev_p1_reg3 = dut.P1.reg3;
        end
        
        // Track P2 register changes
        if (dut.P2.reg0 != prev_p2_reg0 || dut.P2.reg1 != prev_p2_reg1 || 
            dut.P2.reg2 != prev_p2_reg2 || dut.P2.reg3 != prev_p2_reg3) begin
            p2_reg_changes = p2_reg_changes + 1;
            if (i < 200 && dut.P2.reg3 != prev_p2_reg3) begin
                $display("Time=%0t: P2.reg3 changed: %h -> %h (incr)", 
                         $time, prev_p2_reg3, dut.P2.reg3);
            end
            prev_p2_reg0 = dut.P2.reg0;
            prev_p2_reg1 = dut.P2.reg1;
            prev_p2_reg2 = dut.P2.reg2;
            prev_p2_reg3 = dut.P2.reg3;
        end
        
        // Track P3 register changes
        if (dut.P3.reg0 != prev_p3_reg0 || dut.P3.reg1 != prev_p3_reg1 || 
            dut.P3.reg2 != prev_p3_reg2 || dut.P3.reg3 != prev_p3_reg3) begin
            p3_reg_changes = p3_reg_changes + 1;
            if (i < 200 && dut.P3.reg3 != prev_p3_reg3) begin
                $display("Time=%0t: P3.reg3 changed: %h -> %h (decr)", 
                         $time, prev_p3_reg3, dut.P3.reg3);
            end
            prev_p3_reg0 = dut.P3.reg0;
            prev_p3_reg1 = dut.P3.reg1;
            prev_p3_reg2 = dut.P3.reg2;
            prev_p3_reg3 = dut.P3.reg3;
        end
    end
    
    #100;
    $display("\n=== Register Change Summary ===");
    $display("P1 (b14) register changes:    %0d", p1_reg_changes);
    $display("P2 (b14_1) register changes:  %0d", p2_reg_changes);
    $display("P3 (b14rev) register changes: %0d", p3_reg_changes);
end

// State name decoder for display
function [63:0] state_name;
    input state;
    begin
        case(state)
            FETCH: state_name = "FETCH";
            EXEC: state_name = "EXEC";
            default: state_name = "UNKNOWN";
        endcase
    end
endfunction

// Track instruction execution patterns for all three processors
integer fetch_count_p1, exec_count_p1;
integer fetch_count_p2, exec_count_p2;
integer fetch_count_p3, exec_count_p3;

initial begin
    @(posedge rst_n);
    fetch_count_p1 = 0; exec_count_p1 = 0;
    fetch_count_p2 = 0; exec_count_p2 = 0;
    fetch_count_p3 = 0; exec_count_p3 = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.P1.state == FETCH) fetch_count_p1 = fetch_count_p1 + 1;
        if (dut.P1.state == EXEC) exec_count_p1 = exec_count_p1 + 1;
        if (dut.P2.state == FETCH) fetch_count_p2 = fetch_count_p2 + 1;
        if (dut.P2.state == EXEC) exec_count_p2 = exec_count_p2 + 1;
        if (dut.P3.state == FETCH) fetch_count_p3 = fetch_count_p3 + 1;
        if (dut.P3.state == EXEC) exec_count_p3 = exec_count_p3 + 1;
    end
    
    #100;
    $display("\n=== Instruction Cycle Summary ===");
    $display("P1 (b14):     FETCH=%0d EXEC=%0d", fetch_count_p1, exec_count_p1);
    $display("P2 (b14_1):   FETCH=%0d EXEC=%0d", fetch_count_p2, exec_count_p2);
    $display("P3 (b14rev):  FETCH=%0d EXEC=%0d", fetch_count_p3, exec_count_p3);
end

// Coverage checker
integer max_so, min_so;
reg [31:0] max_datao1, min_datao1;
reg [31:0] max_datao2, min_datao2;
reg [31:0] max_datao3, min_datao3;

initial begin
    @(posedge rst_n);
    max_so = 0; min_so = 20'hFFFFF;
    max_datao1 = 0; min_datao1 = 32'hFFFFFFFF;
    max_datao2 = 0; min_datao2 = 32'hFFFFFFFF;
    max_datao3 = 0; min_datao3 = 32'hFFFFFFFF;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (so > max_so) max_so = so;
        if (so < min_so) min_so = so;
        
        if (dut.datao_1 > max_datao1) max_datao1 = dut.datao_1;
        if (dut.datao_1 < min_datao1) min_datao1 = dut.datao_1;
        
        if (dut.datao_2 > max_datao2) max_datao2 = dut.datao_2;
        if (dut.datao_2 < min_datao2) min_datao2 = dut.datao_2;
        
        if (dut.datao_3 > max_datao3) max_datao3 = dut.datao_3;
        if (dut.datao_3 < min_datao3) min_datao3 = dut.datao_3;
    end
    
    #100;
    $display("\n=== Coverage Summary ===");
    $display("so range:     %h to %h (%0d to %0d)", min_so, max_so, min_so, max_so);
    $display("datao_1 range: %h to %h", min_datao1, max_datao1);
    $display("datao_2 range: %h to %h", min_datao2, max_datao2);
    $display("datao_3 range: %h to %h", min_datao3, max_datao3);
end

// Monitor B flag changes for all three processors
integer b1_set_count, b1_clear_count;
integer b2_set_count, b2_clear_count;
integer b3_set_count, b3_clear_count;
reg prev_b1, prev_b2, prev_b3;

initial begin
    @(posedge rst_n);
    prev_b1 = dut.P1.B;
    prev_b2 = dut.P2.B;
    prev_b3 = dut.P3.B;
    b1_set_count = 0; b1_clear_count = 0;
    b2_set_count = 0; b2_clear_count = 0;
    b3_set_count = 0; b3_clear_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.P1.B != prev_b1) begin
            if (dut.P1.B == 1'b1) b1_set_count = b1_set_count + 1;
            else b1_clear_count = b1_clear_count + 1;
            prev_b1 = dut.P1.B;
        end
        
        if (dut.P2.B != prev_b2) begin
            if (dut.P2.B == 1'b1) b2_set_count = b2_set_count + 1;
            else b2_clear_count = b2_clear_count + 1;
            prev_b2 = dut.P2.B;
        end
        
        if (dut.P3.B != prev_b3) begin
            if (dut.P3.B == 1'b1) b3_set_count = b3_set_count + 1;
            else b3_clear_count = b3_clear_count + 1;
            prev_b3 = dut.P3.B;
        end
    end
    
    #100;
    $display("\n=== B Flag Summary ===");
    $display("P1 B: set=%0d clear=%0d", b1_set_count, b1_clear_count);
    $display("P2 B: set=%0d clear=%0d", b2_set_count, b2_clear_count);
    $display("P3 B: set=%0d clear=%0d", b3_set_count, b3_clear_count);
end

// Monitor complex data routing decisions
integer routing_mode1_count, routing_mode2_count;

initial begin
    @(posedge rst_n);
    routing_mode1_count = 0;
    routing_mode2_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        // Check routing condition
        if ((dut.addr_1 < (2**19) && dut.addr_2 < (2**19) && dut.addr_3 > (2**19-1) && dut.rd_1 == 1'b0) || 
            (dut.addr_1 > (2**19-1) && dut.addr_2 > (2**19-1) && dut.addr_3 < (2**19) && dut.rd_2 == 1'b0)) begin
            routing_mode1_count = routing_mode1_count + 1;
            if (routing_mode1_count < 20) begin
                $display("Time=%0t: ROUTING MODE 1 - datai_1=datao_2+si, datai_2=datao_1, datai_3=datao_1-datao_2", $time);
            end
        end else begin
            routing_mode2_count = routing_mode2_count + 1;
            if (routing_mode2_count < 20) begin
                $display("Time=%0t: ROUTING MODE 2 - datai_1=datao_2, datai_2=datao_1+si, datai_3=si", $time);
            end
        end
    end
    
    #100;
    $display("\n=== Data Routing Summary ===");
    $display("Routing Mode 1 (complex): %0d cycles", routing_mode1_count);
    $display("Routing Mode 2 (simple):  %0d cycles", routing_mode2_count);
end

// Targeted tests for address-based routing conditions
initial begin
    @(posedge rst_n);
    #1000;
    
    $display("\n=== Running targeted tests for complex routing conditions ===");
    
    // Test condition 1: addr_1 < 2^19 && addr_2 < 2^19 && addr_3 > 2^19-1
    $display("Test: Attempting to trigger routing mode 1 condition 1");
    repeat(100) begin
        @(posedge clk);
        si = 32'h00001000;
    end
    
    // Test condition 2: addr_1 > 2^19-1 && addr_2 > 2^19-1 && addr_3 < 2^19
    $display("Test: Attempting to trigger routing mode 1 condition 2");
    repeat(100) begin
        @(posedge clk);
        si = 32'hFFFF0000;
    end
    
    // Test with edge values
    repeat(100) begin
        @(posedge clk);
        si = 32'h00080000;  // 2^19
    end
    
    repeat(100) begin
        @(posedge clk);
        si = 32'h0007FFFF;  // 2^19 - 1
    end
end

// Monitor reg3 behavior differences (increment vs decrement)
reg [31:0] prev_p1_r3, prev_p3_r3;
integer p1_r3_increments, p3_r3_decrements;

initial begin
    @(posedge rst_n);
    prev_p1_r3 = dut.P1.reg3;
    prev_p3_r3 = dut.P3.reg3;
    p1_r3_increments = 0;
    p3_r3_decrements = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        // Track P1 reg3 increments
        if (dut.P1.reg3 > prev_p1_r3 && dut.P1.state == EXEC) begin
            p1_r3_increments = p1_r3_increments + 1;
        end
        prev_p1_r3 = dut.P1.reg3;
        
        // Track P3 reg3 decrements
        if (dut.P3.reg3 < prev_p3_r3 && dut.P3.state == EXEC) begin
            p3_r3_decrements = p3_r3_decrements + 1;
        end
        prev_p3_r3 = dut.P3.reg3;
    end
    
    #100;
    $display("\n=== reg3 Behavior Summary ===");
    $display("P1 reg3 increments (+8): %0d", p1_r3_increments);
    $display("P3 reg3 decrements (-8): %0d", p3_r3_decrements);
end

// Verify so calculation
integer so_calc_errors;
reg [19:0] expected_so;

initial begin
    @(posedge rst_n);
    so_calc_errors = 0;
    
    repeat(50000) begin
        @(posedge clk);
        #1; // Small delay to let signals settle
        
        expected_so = (dut.addr_1 + dut.addr_2 - dut.addr_3) % (2**20);
        if (so !== expected_so) begin
            so_calc_errors = so_calc_errors + 1;
            if (so_calc_errors < 10) begin
                $display("ERROR: so mismatch! Expected=%h Got=%h (addr_1=%h addr_2=%h addr_3=%h)",
                         expected_so, so, dut.addr_1, dut.addr_2, dut.addr_3);
            end
        end
    end
    
    #100;
    $display("\n=== Output Calculation Verification ===");
    $display("so calculation errors: %0d", so_calc_errors);
end

endmodule
