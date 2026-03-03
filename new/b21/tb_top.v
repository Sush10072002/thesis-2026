`timescale 1ns / 1ps

module tb_top;

// State parameters (must match b14 and b14_1)
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

// Input signals for b21
reg [31:0] si;

// Output signals from b21
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
b21 dut (
    .clock(clk),
    .reset(~rst_n),  // rst_n is active low, but b21 expects active high reset
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
    $fwrite(file, "Cycle\tsi\t\tso\t\trd\twr\tad1\t\tad2\t\tr1\tr2\tw1\tw2\tstate_1\tstate_2\treg3_1\t\treg3_2\t\tB_1\tB_2\tIR_1\t\tIR_2\n");
    $fwrite(file, "-----\t--------\t-----\t\t--\t--\t-----\t\t-----\t\t--\t--\t--\t--\t-------\t-------\t--------\t--------\t---\t---\t--------\t--------\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation for b21 with random inputs ===\n");
    
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
        
        // Log to file
        if (file) begin
            $fwrite(file, "%0d\t%h\t%h\t%b\t%b\t%h\t%h\t%b\t%b\t%b\t%b\t%0d\t%0d\t%h\t%h\t%b\t%b\t%h\t%h\n",
                    i, si, so, rd, wr,
                    dut.ad1, dut.ad2,
                    dut.r1, dut.r2,
                    dut.w1, dut.w2,
                    dut.P1.state, dut.P2.state,
                    dut.P1.reg3, dut.P2.reg3,
                    dut.P1.B, dut.P2.B,
                    dut.P1.IR, dut.P2.IR);
        end
        
        // Display P1 (b14) state transitions
        if (dut.P1.state == FETCH && i < 100) begin
            $display("Time=%0t: Cycle %0d - P1 FETCH | MAR=%0d di1=%h r1=%b", 
                     $time, i, dut.P1.MAR, dut.di1, dut.r1);
        end
        
        if (dut.P1.state == EXEC && i < 100) begin
            $display("Time=%0t: Cycle %0d - P1 EXEC | IR=%h mf=%0d df=%0d ff=%0d cf=%0d", 
                     $time, i, dut.P1.IR, dut.P1.mf, dut.P1.df, dut.P1.ff, dut.P1.cf);
        end
        
        // Display P2 (b14_1) state transitions
        if (dut.P2.state == FETCH && i < 100) begin
            $display("Time=%0t: Cycle %0d - P2 FETCH | MAR=%0d di2=%h r2=%b", 
                     $time, i, dut.P2.MAR, dut.di2, dut.r2);
        end
        
        if (dut.P2.state == EXEC && i < 100) begin
            $display("Time=%0t: Cycle %0d - P2 EXEC | IR=%h mf=%0d df=%0d ff=%0d cf=%0d", 
                     $time, i, dut.P2.IR, dut.P2.mf, dut.P2.df, dut.P2.ff, dut.P2.cf);
        end
        
        // Display combined outputs every 1000 cycles
        if (i % 1000 == 0) begin
            $display("\nTime=%0t: Cycle %0d | si=%h so=%h rd=%b wr=%b", 
                     $time, i, si, so, rd, wr);
            $display("  P1: state=%0d addr=%h reg3=%h B=%b IR=%h", 
                     dut.P1.state, dut.ad1, dut.P1.reg3, dut.P1.B, dut.P1.IR);
            $display("  P2: state=%0d addr=%h reg3=%h B=%b IR=%h", 
                     dut.P2.state, dut.ad2, dut.P2.reg3, dut.P2.B, dut.P2.IR);
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
    $display("=== b21 Circuit Testbench ===");
    $display("Time\t\trst_n\tsi\t\tso\t\trd\twr\tad1\t\tad2\t\tstate_1\tstate_2");
    $display("----\t\t-----\t--------\t-----\t\t--\t--\t-----\t\t-----\t\t-------\t-------");
    $monitor("%0t\t%b\t%h\t%h\t%b\t%b\t%h\t%h\t%0d\t%0d",
             $time, rst_n, si, so, rd, wr, dut.ad1, dut.ad2, dut.P1.state, dut.P2.state);
end

// Generate VCD file for waveform viewing
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    
    // Dump top-level DUT signals
    $dumpvars(0, dut.ad1);
    $dumpvars(0, dut.ad2);
    $dumpvars(0, dut.di1);
    $dumpvars(0, dut.di2);
    $dumpvars(0, dut.do1);
    $dumpvars(0, dut.do2);
    $dumpvars(0, dut.r1);
    $dumpvars(0, dut.r2);
    $dumpvars(0, dut.w1);
    $dumpvars(0, dut.w2);
    
    // Dump P1 (b14) signals
    $dumpvars(0, dut.P1.state);
    $dumpvars(0, dut.P1.reg0);
    $dumpvars(0, dut.P1.reg1);
    $dumpvars(0, dut.P1.reg2);
    $dumpvars(0, dut.P1.reg3);
    $dumpvars(0, dut.P1.B);
    $dumpvars(0, dut.P1.MAR);
    $dumpvars(0, dut.P1.MBR);
    $dumpvars(0, dut.P1.IR);
    $dumpvars(0, dut.P1.mf);
    $dumpvars(0, dut.P1.df);
    $dumpvars(0, dut.P1.cf);
    $dumpvars(0, dut.P1.ff);
    $dumpvars(0, dut.P1.r);
    $dumpvars(0, dut.P1.m);
    $dumpvars(0, dut.P1.d);
    $dumpvars(0, dut.P1.t);
    
    // Dump P2 (b14_1) signals
    $dumpvars(0, dut.P2.state);
    $dumpvars(0, dut.P2.reg0);
    $dumpvars(0, dut.P2.reg1);
    $dumpvars(0, dut.P2.reg2);
    $dumpvars(0, dut.P2.reg3);
    $dumpvars(0, dut.P2.B);
    $dumpvars(0, dut.P2.MAR);
    $dumpvars(0, dut.P2.MBR);
    $dumpvars(0, dut.P2.IR);
    $dumpvars(0, dut.P2.mf);
    $dumpvars(0, dut.P2.df);
    $dumpvars(0, dut.P2.cf);
    $dumpvars(0, dut.P2.ff);
    $dumpvars(0, dut.P2.r);
    $dumpvars(0, dut.P2.m);
    $dumpvars(0, dut.P2.d);
    $dumpvars(0, dut.P2.t);
end

// Detailed snapshot every 100 cycles
initial begin
    @(posedge rst_n);
    
    for (i=0; i<500; i=i+1) begin
        @(posedge clk);
        if (i % 100 == 0) begin
            $display("\n--- Cycle %0d Snapshot ---", i);
            $display("Inputs:");
            $display("  si=%h (%0d)", si, si);
            $display("Outputs:");
            $display("  so=%h (%0d)", so, so);
            $display("  rd=%b wr=%b", rd, wr);
            $display("Internal signals:");
            $display("  ad1=%h ad2=%h", dut.ad1, dut.ad2);
            $display("  di1=%h di2=%h", dut.di1, dut.di2);
            $display("  do1=%h do2=%h", dut.do1, dut.do2);
            $display("  r1=%b r2=%b w1=%b w2=%b", dut.r1, dut.r2, dut.w1, dut.w2);
            $display("P1 (b14) signals:");
            $display("  state=%0d IR=%h (signed=%0d)", dut.P1.state, dut.P1.IR, $signed(dut.P1.IR));
            $display("  MAR=%h MBR=%h", dut.P1.MAR, dut.P1.MBR);
            $display("  reg0=%h reg1=%h reg2=%h reg3=%h", 
                     dut.P1.reg0, dut.P1.reg1, dut.P1.reg2, dut.P1.reg3);
            $display("  mf=%0d df=%0d ff=%0d cf=%0d tail=%0d", 
                     dut.P1.mf, dut.P1.df, dut.P1.ff, dut.P1.cf, dut.P1.tail);
            $display("  r=%h m=%h d=%0d t=%h B=%b", 
                     dut.P1.r, dut.P1.m, dut.P1.d, dut.P1.t, dut.P1.B);
            $display("P2 (b14_1) signals:");
            $display("  state=%0d IR=%h (signed=%0d)", dut.P2.state, dut.P2.IR, $signed(dut.P2.IR));
            $display("  MAR=%h MBR=%h", dut.P2.MAR, dut.P2.MBR);
            $display("  reg0=%h reg1=%h reg2=%h reg3=%h", 
                     dut.P2.reg0, dut.P2.reg1, dut.P2.reg2, dut.P2.reg3);
            $display("  mf=%0d df=%0d ff=%0d cf=%0d tail=%0d", 
                     dut.P2.mf, dut.P2.df, dut.P2.ff, dut.P2.cf, dut.P2.tail);
            $display("  r=%h m=%h d=%0d t=%h B=%b", 
                     dut.P2.r, dut.P2.m, dut.P2.d, dut.P2.t, dut.P2.B);
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
            if (rd_transitions < 50) begin  // Display first 50 transitions
                $display("Time=%0t: Cycle %0d - rd changed: %b -> %b (r1=%b r2=%b)", 
                         $time, i, prev_rd, rd, dut.r1, dut.r2);
            end
            prev_rd = rd;
        end
        
        if (wr != prev_wr) begin
            wr_transitions = wr_transitions + 1;
            if (wr_transitions < 50) begin  // Display first 50 transitions
                $display("Time=%0t: Cycle %0d - wr changed: %b -> %b (w1=%b w2=%b)", 
                         $time, i, prev_wr, wr, dut.w1, dut.w2);
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
            if (so_changes < 30) begin  // Display first 30 changes
                $display("Time=%0t: so changed: %h -> %h (ad1=%h ad2=%h sum=%h)", 
                         $time, prev_so, so, dut.ad1, dut.ad2, (dut.ad1 + dut.ad2) % (2**20));
            end
            prev_so = so;
        end
    end
    
    #100;
    $display("Total so changes: %0d", so_changes);
end

// Track P1 register modifications
reg [31:0] prev_p1_reg0, prev_p1_reg1, prev_p1_reg2, prev_p1_reg3;
integer p1_reg0_changes, p1_reg1_changes, p1_reg2_changes, p1_reg3_changes;

initial begin
    @(posedge rst_n);
    prev_p1_reg0 = 0;
    prev_p1_reg1 = 0;
    prev_p1_reg2 = 0;
    prev_p1_reg3 = 0;
    p1_reg0_changes = 0;
    p1_reg1_changes = 0;
    p1_reg2_changes = 0;
    p1_reg3_changes = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.P1.reg0 != prev_p1_reg0) begin
            p1_reg0_changes = p1_reg0_changes + 1;
            if (i < 200) begin
                $display("Time=%0t: P1.reg0 changed: %h -> %h", $time, prev_p1_reg0, dut.P1.reg0);
            end
            prev_p1_reg0 = dut.P1.reg0;
        end
        if (dut.P1.reg1 != prev_p1_reg1) begin
            p1_reg1_changes = p1_reg1_changes + 1;
            if (i < 200) begin
                $display("Time=%0t: P1.reg1 changed: %h -> %h", $time, prev_p1_reg1, dut.P1.reg1);
            end
            prev_p1_reg1 = dut.P1.reg1;
        end
        if (dut.P1.reg2 != prev_p1_reg2) begin
            p1_reg2_changes = p1_reg2_changes + 1;
            if (i < 200) begin
                $display("Time=%0t: P1.reg2 changed: %h -> %h", $time, prev_p1_reg2, dut.P1.reg2);
            end
            prev_p1_reg2 = dut.P1.reg2;
        end
        if (dut.P1.reg3 != prev_p1_reg3) begin
            p1_reg3_changes = p1_reg3_changes + 1;
            if (i < 200) begin
                $display("Time=%0t: P1.reg3 changed: %h -> %h", $time, prev_p1_reg3, dut.P1.reg3);
            end
            prev_p1_reg3 = dut.P1.reg3;
        end
    end
    
    #100;
    $display("\n=== P1 Register Changes ===");
    $display("P1.reg0 changes: %0d", p1_reg0_changes);
    $display("P1.reg1 changes: %0d", p1_reg1_changes);
    $display("P1.reg2 changes: %0d", p1_reg2_changes);
    $display("P1.reg3 changes: %0d", p1_reg3_changes);
end

// Track P2 register modifications
reg [31:0] prev_p2_reg0, prev_p2_reg1, prev_p2_reg2, prev_p2_reg3;
integer p2_reg0_changes, p2_reg1_changes, p2_reg2_changes, p2_reg3_changes;

initial begin
    @(posedge rst_n);
    prev_p2_reg0 = 0;
    prev_p2_reg1 = 0;
    prev_p2_reg2 = 0;
    prev_p2_reg3 = 0;
    p2_reg0_changes = 0;
    p2_reg1_changes = 0;
    p2_reg2_changes = 0;
    p2_reg3_changes = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.P2.reg0 != prev_p2_reg0) begin
            p2_reg0_changes = p2_reg0_changes + 1;
            if (i < 200) begin
                $display("Time=%0t: P2.reg0 changed: %h -> %h", $time, prev_p2_reg0, dut.P2.reg0);
            end
            prev_p2_reg0 = dut.P2.reg0;
        end
        if (dut.P2.reg1 != prev_p2_reg1) begin
            p2_reg1_changes = p2_reg1_changes + 1;
            if (i < 200) begin
                $display("Time=%0t: P2.reg1 changed: %h -> %h", $time, prev_p2_reg1, dut.P2.reg1);
            end
            prev_p2_reg1 = dut.P2.reg1;
        end
        if (dut.P2.reg2 != prev_p2_reg2) begin
            p2_reg2_changes = p2_reg2_changes + 1;
            if (i < 200) begin
                $display("Time=%0t: P2.reg2 changed: %h -> %h", $time, prev_p2_reg2, dut.P2.reg2);
            end
            prev_p2_reg2 = dut.P2.reg2;
        end
        if (dut.P2.reg3 != prev_p2_reg3) begin
            p2_reg3_changes = p2_reg3_changes + 1;
            if (i < 200) begin
                $display("Time=%0t: P2.reg3 changed: %h -> %h", $time, prev_p2_reg3, dut.P2.reg3);
            end
            prev_p2_reg3 = dut.P2.reg3;
        end
    end
    
    #100;
    $display("\n=== P2 Register Changes ===");
    $display("P2.reg0 changes: %0d", p2_reg0_changes);
    $display("P2.reg1 changes: %0d", p2_reg1_changes);
    $display("P2.reg2 changes: %0d", p2_reg2_changes);
    $display("P2.reg3 changes: %0d", p2_reg3_changes);
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

// Track instruction execution patterns for both P1 and P2
integer fetch_count_p1, exec_count_p1;
integer fetch_count_p2, exec_count_p2;

initial begin
    @(posedge rst_n);
    fetch_count_p1 = 0;
    exec_count_p1 = 0;
    fetch_count_p2 = 0;
    exec_count_p2 = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.P1.state == FETCH) fetch_count_p1 = fetch_count_p1 + 1;
        if (dut.P1.state == EXEC) exec_count_p1 = exec_count_p1 + 1;
        if (dut.P2.state == FETCH) fetch_count_p2 = fetch_count_p2 + 1;
        if (dut.P2.state == EXEC) exec_count_p2 = exec_count_p2 + 1;
    end
    
    #100;
    $display("\n=== Instruction Cycle Summary ===");
    $display("P1 (b14):");
    $display("  FETCH cycles: %0d", fetch_count_p1);
    $display("  EXEC cycles: %0d", exec_count_p1);
    $display("P2 (b14_1):");
    $display("  FETCH cycles: %0d", fetch_count_p2);
    $display("  EXEC cycles: %0d", exec_count_p2);
end

// Coverage checker
integer max_so, min_so;
integer max_ad1, min_ad1;
integer max_ad2, min_ad2;
reg [31:0] max_do1, min_do1;
reg [31:0] max_do2, min_do2;

initial begin
    @(posedge rst_n);
    max_so = 0; min_so = 20'hFFFFF;
    max_ad1 = 0; min_ad1 = 20'hFFFFF;
    max_ad2 = 0; min_ad2 = 20'hFFFFF;
    max_do1 = 0; min_do1 = 32'hFFFFFFFF;
    max_do2 = 0; min_do2 = 32'hFFFFFFFF;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (so > max_so) max_so = so;
        if (so < min_so) min_so = so;
        
        if (dut.ad1 > max_ad1) max_ad1 = dut.ad1;
        if (dut.ad1 < min_ad1) min_ad1 = dut.ad1;
        
        if (dut.ad2 > max_ad2) max_ad2 = dut.ad2;
        if (dut.ad2 < min_ad2) min_ad2 = dut.ad2;
        
        if (dut.do1 > max_do1) max_do1 = dut.do1;
        if (dut.do1 < min_do1) min_do1 = dut.do1;
        
        if (dut.do2 > max_do2) max_do2 = dut.do2;
        if (dut.do2 < min_do2) min_do2 = dut.do2;
    end
    
    #100;
    $display("\n=== Coverage Summary ===");
    $display("so range: %h to %h (%0d to %0d)", min_so, max_so, min_so, max_so);
    $display("ad1 range: %h to %h (%0d to %0d)", min_ad1, max_ad1, min_ad1, max_ad1);
    $display("ad2 range: %h to %h (%0d to %0d)", min_ad2, max_ad2, min_ad2, max_ad2);
    $display("do1 range: %h to %h", min_do1, max_do1);
    $display("do2 range: %h to %h", min_do2, max_do2);
end

// Targeted tests for address-based conditions
initial begin
    @(posedge rst_n);
    #1000;
    
    $display("\n=== Running targeted tests for address-based conditions ===");
    
    // Test condition: ad1 < 2^19 && ad2 < 2^19 && r1 == 0
    $display("Testing: ad1 < 2^19 && ad2 < 2^19 (should route do2+si to di1, do1 to di2)");
    repeat(100) begin
        @(posedge clk);
        si = 32'h00000100;
    end
    
    // Test condition: ad1 > 2^19-1 && ad2 > 2^19-1 && r2 == 0
    $display("Testing: ad1 > 2^19-1 && ad2 > 2^19-1 (should route do2+si to di1, do1 to di2)");
    repeat(100) begin
        @(posedge clk);
        si = 32'hFFFFF000;
    end
    
    // Test with various si values
    repeat(100) begin
        @(posedge clk);
        si = $random % (2**16);
    end
    
    repeat(100) begin
        @(posedge clk);
        si = ($random % (2**16)) + (2**16);
    end
end

// Monitor B flag changes for both processors
integer b1_set_count, b1_clear_count;
integer b2_set_count, b2_clear_count;
reg prev_b1, prev_b2;

initial begin
    @(posedge rst_n);
    prev_b1 = dut.P1.B;
    prev_b2 = dut.P2.B;
    b1_set_count = 0;
    b1_clear_count = 0;
    b2_set_count = 0;
    b2_clear_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.P1.B != prev_b1) begin
            if (dut.P1.B == 1'b1) begin
                b1_set_count = b1_set_count + 1;
                if (b1_set_count < 20) begin
                    $display("Time=%0t: P1.B set to 1 (ff=%0d r=%h m=%h)", 
                             $time, dut.P1.ff, dut.P1.r, dut.P1.m);
                end
            end else begin
                b1_clear_count = b1_clear_count + 1;
            end
            prev_b1 = dut.P1.B;
        end
        
        if (dut.P2.B != prev_b2) begin
            if (dut.P2.B == 1'b1) begin
                b2_set_count = b2_set_count + 1;
                if (b2_set_count < 20) begin
                    $display("Time=%0t: P2.B set to 1 (ff=%0d r=%h m=%h)", 
                             $time, dut.P2.ff, dut.P2.r, dut.P2.m);
                end
            end else begin
                b2_clear_count = b2_clear_count + 1;
            end
            prev_b2 = dut.P2.B;
        end
    end
    
    #100;
    $display("\n=== B Flag Summary ===");
    $display("P1.B set count: %0d, clear count: %0d", b1_set_count, b1_clear_count);
    $display("P2.B set count: %0d, clear count: %0d", b2_set_count, b2_clear_count);
end

// Monitor data routing changes
integer di1_from_do2_si, di1_from_do2;
integer di2_from_do1, di2_from_do1_si;

initial begin
    @(posedge rst_n);
    di1_from_do2_si = 0;
    di1_from_do2 = 0;
    di2_from_do1 = 0;
    di2_from_do1_si = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        // Check routing condition
        if ((dut.ad1 < (2**19) && dut.ad2 < (2**19) && dut.r1 == 1'b0) || 
            (dut.ad1 > (2**19-1) && dut.ad2 > (2**19-1) && dut.r2 == 1'b0)) begin
            di1_from_do2_si = di1_from_do2_si + 1;
            di2_from_do1 = di2_from_do1 + 1;
        end else begin
            di1_from_do2 = di1_from_do2 + 1;
            di2_from_do1_si = di2_from_do1_si + 1;
        end
    end
    
    #100;
    $display("\n=== Data Routing Summary ===");
    $display("di1 <= do2 + si: %0d cycles", di1_from_do2_si);
    $display("di1 <= do2:      %0d cycles", di1_from_do2);
    $display("di2 <= do1:      %0d cycles", di2_from_do1);
    $display("di2 <= do1 + si: %0d cycles", di2_from_do1_si);
end

// Monitor MAR differences between P1 and P2 (main difference between b14 and b14_1)
integer mar_diff_count;

initial begin
    @(posedge rst_n);
    mar_diff_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        // b14 uses: MAR = reg3 % 2**20
        // b14_1 uses: MAR = reg3[19:0]
        // These should be equivalent for most values
        if (dut.P1.state == FETCH && dut.P2.state == FETCH) begin
            if (dut.P1.MAR != dut.P2.MAR && i < 100) begin
                mar_diff_count = mar_diff_count + 1;
                $display("Time=%0t: MAR difference - P1.MAR=%h P2.MAR=%h P1.reg3=%h P2.reg3=%h", 
                         $time, dut.P1.MAR, dut.P2.MAR, dut.P1.reg3, dut.P2.reg3);
            end
        end
    end
    
    #100;
    $display("\n=== MAR Difference Count ===");
    $display("MAR differences detected: %0d", mar_diff_count);
end

endmodule
