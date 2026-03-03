`timescale 1ns / 1ps

module tb_top;

// State parameters (must match b14.v)
parameter FETCH = 0;
parameter EXEC = 1;

// Value parameters (must match b14.v and b15.v)
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

// b15 State parameters
parameter StateInit = 0;
parameter StateTi = 1;
parameter StateT1 = 2;
parameter StateT2 = 3;
parameter StateT1P = 4;
parameter StateTh = 5;
parameter StateT2P = 6;
parameter StateT2I = 7;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals for b18
reg hold;
reg na;
reg bs;
reg sel;
reg [31:0] din;

// Output signals from b18
wire [19:0] dout;
wire [3:0] aux;

// Loop counter
integer i;

// File for logging
integer file;
integer summary_file;

// Statistics counters
integer hold_transitions;
integer na_transitions;
integer bs_transitions;
integer sel_transitions;
integer dout_changes;
integer aux_changes;

// Previous values for change detection
reg prev_hold, prev_na, prev_bs, prev_sel;
reg [19:0] prev_dout;
reg [3:0] prev_aux;

// Instantiate the DUT (Device Under Test) - b18 module
b18 dut (
    .clock(clk),
    .reset(~rst_n),  // rst_n is active low, but b18 expects active high reset
    .hold(hold),
    .na(na),
    .bs(bs),
    .sel(sel),
    .din(din),
    .dout(dout),
    .aux(aux)
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
    hold = 0;
    na = 1;
    bs = 1;
    sel = 0;
    din = 32'h00000000;
    
    // Initialize statistics
    hold_transitions = 0;
    na_transitions = 0;
    bs_transitions = 0;
    sel_transitions = 0;
    dout_changes = 0;
    aux_changes = 0;
    
    prev_hold = 0;
    prev_na = 1;
    prev_bs = 1;
    prev_sel = 0;
    prev_dout = 0;
    prev_aux = 0;
    
    // Open files for logging
    file = $fopen("b18_simulation_log.txt", "w");
    summary_file = $fopen("b18_summary.txt", "w");
    
    $fwrite(file, "=== B18 Module Simulation Log ===\n");
    $fwrite(file, "Cycle\tdin\t\thold\tna\tbs\tsel\tdout\t\taux\n");
    $fwrite(file, "-----\t--------\t----\t--\t--\t---\t-----\t\t---\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation for b18 module ===\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        
        // Random input generation
        din <= $random;
        
        // Randomize control signals with some constraints
        // Hold is asserted less frequently
        if ($random % 100 < 10) hold <= $random;
        
        // NA (Next Address) randomly toggled
        if ($random % 10 < 3) na <= $random;
        
        // BS (Bus Size) randomly toggled
        if ($random % 20 < 5) bs <= $random;
        
        // SEL randomly toggled
        if ($random % 5 < 2) sel <= $random;
        
        // Log to file
        if (file) begin
            $fwrite(file, "%0d\t%h\t%b\t%b\t%b\t%b\t%h\t%h\n", 
                    i, din, hold, na, bs, sel, dout, aux);
        end
        
        // Track input transitions
        if (hold != prev_hold) begin
            hold_transitions = hold_transitions + 1;
            $display("Time=%0t: Cycle %0d - HOLD changed: %b -> %b", 
                     $time, i, prev_hold, hold);
            prev_hold = hold;
        end
        
        if (na != prev_na) begin
            na_transitions = na_transitions + 1;
            $display("Time=%0t: Cycle %0d - NA changed: %b -> %b", 
                     $time, i, prev_na, na);
            prev_na = na;
        end
        
        if (bs != prev_bs) begin
            bs_transitions = bs_transitions + 1;
            $display("Time=%0t: Cycle %0d - BS changed: %b -> %b", 
                     $time, i, prev_bs, bs);
            prev_bs = bs;
        end
        
        if (sel != prev_sel) begin
            sel_transitions = sel_transitions + 1;
            $display("Time=%0t: Cycle %0d - SEL changed: %b -> %b", 
                     $time, i, prev_sel, sel);
            prev_sel = sel;
        end
        
        // Track output changes
        if (dout != prev_dout) begin
            dout_changes = dout_changes + 1;
            $display("Time=%0t: Cycle %0d - DOUT changed: %h -> %h", 
                     $time, i, prev_dout, dout);
            prev_dout = dout;
        end
        
        if (aux != prev_aux) begin
            aux_changes = aux_changes + 1;
            $display("Time=%0t: Cycle %0d - AUX changed: %h -> %h", 
                     $time, i, prev_aux, aux);
            prev_aux = aux;
        end
        
        // Display progress every 1000 cycles
        if (i % 1000 == 0) begin
            $display("Time=%0t: Cycle %0d | din=%h hold=%b na=%b bs=%b sel=%b | dout=%h aux=%h", 
                     $time, i, din, hold, na, bs, sel, dout, aux);
        end
    end
    
    // Write summary statistics
    $fwrite(summary_file, "=== B18 Module Simulation Summary ===\n");
    $fwrite(summary_file, "Total Cycles: %0d\n", i);
    $fwrite(summary_file, "\nInput Transitions:\n");
    $fwrite(summary_file, "  HOLD transitions: %0d\n", hold_transitions);
    $fwrite(summary_file, "  NA transitions: %0d\n", na_transitions);
    $fwrite(summary_file, "  BS transitions: %0d\n", bs_transitions);
    $fwrite(summary_file, "  SEL transitions: %0d\n", sel_transitions);
    $fwrite(summary_file, "\nOutput Changes:\n");
    $fwrite(summary_file, "  DOUT changes: %0d\n", dout_changes);
    $fwrite(summary_file, "  AUX changes: %0d\n", aux_changes);
    
    // Close files and finish simulation
    if (file) $fclose(file);
    if (summary_file) $fclose(summary_file);
    
    $display("\n=== Simulation Complete ===");
    $display("Total cycles run: %0d", i);
    $display("HOLD transitions: %0d", hold_transitions);
    $display("NA transitions: %0d", na_transitions);
    $display("BS transitions: %0d", bs_transitions);
    $display("SEL transitions: %0d", sel_transitions);
    $display("DOUT changes: %0d", dout_changes);
    $display("AUX changes: %0d", aux_changes);
    $display("\nCheck 'b18_simulation_log.txt' for detailed signal log");
    $display("Check 'b18_summary.txt' for summary statistics");
    $finish;
end

// Monitor for debugging
initial begin
    $display("=== b18 Top-Level Module Testbench ===");
    $display("Time\t\trst_n\thold\tna\tbs\tsel\tdin\t\tdout\t\taux");
    $display("----\t\t-----\t----\t--\t--\t---\t--------\t-----\t\t---");
    $monitor("%0t\t%b\t%b\t%b\t%b\t%b\t%h\t%h\t%h", 
             $time, rst_n, hold, na, bs, sel, din, dout, aux);
end

// Generate VCD file for waveform viewing
initial begin
    $dumpfile("tb_b18.vcd");
    $dumpvars(0, tb_top);
    
    // Dump b18 top-level signals
    $dumpvars(0, dut.di1);
    $dumpvars(0, dut.di2);
    $dumpvars(0, dut.do1);
    $dumpvars(0, dut.do2);
    $dumpvars(0, dut.di3);
    $dumpvars(0, dut.di4);
    $dumpvars(0, dut.do3);
    $dumpvars(0, dut.do4);
    $dumpvars(0, dut.td1);
    $dumpvars(0, dut.td2);
    $dumpvars(0, dut.tad1);
    $dumpvars(0, dut.tad2);
    $dumpvars(0, dut.tad3);
    $dumpvars(0, dut.tad4);
    $dumpvars(0, dut.ad11);
    $dumpvars(0, dut.ad12);
    $dumpvars(0, dut.ad21);
    $dumpvars(0, dut.ad22);
    $dumpvars(0, dut.ad31);
    $dumpvars(0, dut.ad41);
    $dumpvars(0, dut.wr1);
    $dumpvars(0, dut.wr2);
    $dumpvars(0, dut.wr3);
    $dumpvars(0, dut.wr4);
    $dumpvars(0, dut.rd3);
    $dumpvars(0, dut.rd4);
    
    // Dump P1 (b17) signals
    $dumpvars(0, dut.P1.buf1);
    $dumpvars(0, dut.P1.buf2);
    $dumpvars(0, dut.P1.address1);
    $dumpvars(0, dut.P1.address2);
    $dumpvars(0, dut.P1.wr);
    $dumpvars(0, dut.P1.dc);
    $dumpvars(0, dut.P1.mio);
    $dumpvars(0, dut.P1.ast1);
    $dumpvars(0, dut.P1.ast2);
    
    // Dump P2 (b17) signals
    $dumpvars(0, dut.P2.buf1);
    $dumpvars(0, dut.P2.buf2);
    $dumpvars(0, dut.P2.address1);
    $dumpvars(0, dut.P2.address2);
    $dumpvars(0, dut.P2.wr);
    $dumpvars(0, dut.P2.dc);
    $dumpvars(0, dut.P2.mio);
    
    // Dump P3 (b14) signals
    $dumpvars(0, dut.P3.state);
    $dumpvars(0, dut.P3.reg0);
    $dumpvars(0, dut.P3.reg1);
    $dumpvars(0, dut.P3.reg2);
    $dumpvars(0, dut.P3.reg3);
    $dumpvars(0, dut.P3.B);
    $dumpvars(0, dut.P3.IR);
    $dumpvars(0, dut.P3.MAR);
    $dumpvars(0, dut.P3.MBR);
    
    // Dump P4 (b14) signals
    $dumpvars(0, dut.P4.state);
    $dumpvars(0, dut.P4.reg0);
    $dumpvars(0, dut.P4.reg1);
    $dumpvars(0, dut.P4.reg2);
    $dumpvars(0, dut.P4.reg3);
    $dumpvars(0, dut.P4.B);
    $dumpvars(0, dut.P4.IR);
    $dumpvars(0, dut.P4.MAR);
    $dumpvars(0, dut.P4.MBR);
end

// Detailed logging every 100 cycles
initial begin
    @(posedge rst_n);
    
    for (i=0; i<500; i=i+1) begin
        @(posedge clk);
        if (i % 100 == 0) begin
            $display("\n--- Cycle %0d Snapshot ---", i);
            $display("Inputs: din=%h hold=%b na=%b bs=%b sel=%b", din, hold, na, bs, sel);
            $display("Outputs: dout=%h aux=%h", dout, aux);
            $display("\nP1 (b17) Status:");
            $display("  buf1=%h buf2=%h", dut.P1.buf1, dut.P1.buf2);
            $display("  address1=%h address2=%h", dut.P1.address1, dut.P1.address2);
            $display("  wr=%b dc=%b mio=%b", dut.P1.wr, dut.P1.dc, dut.P1.mio);
            $display("\nP2 (b17) Status:");
            $display("  buf1=%h buf2=%h", dut.P2.buf1, dut.P2.buf2);
            $display("  address1=%h address2=%h", dut.P2.address1, dut.P2.address2);
            $display("  wr=%b dc=%b mio=%b", dut.P2.wr, dut.P2.dc, dut.P2.mio);
            $display("\nP3 (b14) Status:");
            $display("  state=%0d IR=%h", dut.P3.state, dut.P3.IR);
            $display("  reg0=%h reg1=%h reg2=%h reg3=%h B=%b", 
                     dut.P3.reg0, dut.P3.reg1, dut.P3.reg2, dut.P3.reg3, dut.P3.B);
            $display("\nP4 (b14) Status:");
            $display("  state=%0d IR=%h", dut.P4.state, dut.P4.IR);
            $display("  reg0=%h reg1=%h reg2=%h reg3=%h B=%b", 
                     dut.P4.reg0, dut.P4.reg1, dut.P4.reg2, dut.P4.reg3, dut.P4.B);
            $display("\nIntermediate signals:");
            $display("  tad1=%h tad2=%h tad3=%h tad4=%h", 
                     dut.tad1, dut.tad2, dut.tad3, dut.tad4);
            $display("  td1=%h td2=%h", dut.td1, dut.td2);
        end
    end
end

// Track b14 P3 state transitions
integer p3_fetch_count, p3_exec_count;
reg prev_p3_state;

initial begin
    @(posedge rst_n);
    p3_fetch_count = 0;
    p3_exec_count = 0;
    prev_p3_state = FETCH;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.P3.state == FETCH && prev_p3_state != FETCH) begin
            p3_fetch_count = p3_fetch_count + 1;
            $display("Time=%0t: P3 -> FETCH state | IR=%h", $time, dut.P3.IR);
        end
        
        if (dut.P3.state == EXEC && prev_p3_state != EXEC) begin
            p3_exec_count = p3_exec_count + 1;
            $display("Time=%0t: P3 -> EXEC state | IR=%h", $time, dut.P3.IR);
        end
        
        prev_p3_state = dut.P3.state;
    end
    
    #100;
    $display("\n=== P3 (b14) State Summary ===");
    $display("FETCH state entries: %0d", p3_fetch_count);
    $display("EXEC state entries: %0d", p3_exec_count);
end

// Track b14 P4 state transitions
integer p4_fetch_count, p4_exec_count;
reg prev_p4_state;

initial begin
    @(posedge rst_n);
    p4_fetch_count = 0;
    p4_exec_count = 0;
    prev_p4_state = FETCH;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.P4.state == FETCH && prev_p4_state != FETCH) begin
            p4_fetch_count = p4_fetch_count + 1;
            $display("Time=%0t: P4 -> FETCH state | IR=%h", $time, dut.P4.IR);
        end
        
        if (dut.P4.state == EXEC && prev_p4_state != EXEC) begin
            p4_exec_count = p4_exec_count + 1;
            $display("Time=%0t: P4 -> EXEC state | IR=%h", $time, dut.P4.IR);
        end
        
        prev_p4_state = dut.P4.state;
    end
    
    #100;
    $display("\n=== P4 (b14) State Summary ===");
    $display("FETCH state entries: %0d", p4_fetch_count);
    $display("EXEC state entries: %0d", p4_exec_count);
end

// Track memory read/write operations for P3 and P4
integer p3_read_count, p3_write_count;
integer p4_read_count, p4_write_count;

initial begin
    @(posedge rst_n);
    p3_read_count = 0;
    p3_write_count = 0;
    p4_read_count = 0;
    p4_write_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        // Track P3 operations
        if (dut.rd3 == 1) begin
            p3_read_count = p3_read_count + 1;
            if (p3_read_count < 20) // Limit output
                $display("Time=%0t: P3 READ | addr=%h", $time, dut.ad31);
        end
        
        if (dut.wr3 == 1) begin
            p3_write_count = p3_write_count + 1;
            if (p3_write_count < 20) // Limit output
                $display("Time=%0t: P3 WRITE | addr=%h data=%h", $time, dut.ad31, dut.do3);
        end
        
        // Track P4 operations
        if (dut.rd4 == 1) begin
            p4_read_count = p4_read_count + 1;
            if (p4_read_count < 20) // Limit output
                $display("Time=%0t: P4 READ | addr=%h", $time, dut.ad41);
        end
        
        if (dut.wr4 == 1) begin
            p4_write_count = p4_write_count + 1;
            if (p4_write_count < 20) // Limit output
                $display("Time=%0t: P4 WRITE | addr=%h data=%h", $time, dut.ad41, dut.do4);
        end
    end
    
    #100;
    $display("\n=== Memory Operations Summary ===");
    $display("P3 (b14) reads: %0d, writes: %0d", p3_read_count, p3_write_count);
    $display("P4 (b14) reads: %0d, writes: %0d", p4_read_count, p4_write_count);
end

// Track register modifications in P3
reg [31:0] p3_prev_reg0, p3_prev_reg1, p3_prev_reg2, p3_prev_reg3;
integer p3_reg_changes;

initial begin
    @(posedge rst_n);
    p3_prev_reg0 = 0;
    p3_prev_reg1 = 0;
    p3_prev_reg2 = 0;
    p3_prev_reg3 = 0;
    p3_reg_changes = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.P3.reg0 != p3_prev_reg0) begin
            p3_reg_changes = p3_reg_changes + 1;
            if (p3_reg_changes < 30) // Limit output
                $display("Time=%0t: P3.reg0 changed: %h -> %h", $time, p3_prev_reg0, dut.P3.reg0);
            p3_prev_reg0 = dut.P3.reg0;
        end
        if (dut.P3.reg1 != p3_prev_reg1) begin
            p3_reg_changes = p3_reg_changes + 1;
            if (p3_reg_changes < 30) // Limit output
                $display("Time=%0t: P3.reg1 changed: %h -> %h", $time, p3_prev_reg1, dut.P3.reg1);
            p3_prev_reg1 = dut.P3.reg1;
        end
        if (dut.P3.reg2 != p3_prev_reg2) begin
            p3_reg_changes = p3_reg_changes + 1;
            if (p3_reg_changes < 30) // Limit output
                $display("Time=%0t: P3.reg2 changed: %h -> %h", $time, p3_prev_reg2, dut.P3.reg2);
            p3_prev_reg2 = dut.P3.reg2;
        end
        if (dut.P3.reg3 != p3_prev_reg3) begin
            p3_reg_changes = p3_reg_changes + 1;
            if (p3_reg_changes < 30) // Limit output
                $display("Time=%0t: P3.reg3 changed: %h -> %h", $time, p3_prev_reg3, dut.P3.reg3);
            p3_prev_reg3 = dut.P3.reg3;
        end
    end
    
    #100;
    $display("\n=== P3 Register Changes: %0d ===", p3_reg_changes);
end

// Track register modifications in P4
reg [31:0] p4_prev_reg0, p4_prev_reg1, p4_prev_reg2, p4_prev_reg3;
integer p4_reg_changes;

initial begin
    @(posedge rst_n);
    p4_prev_reg0 = 0;
    p4_prev_reg1 = 0;
    p4_prev_reg2 = 0;
    p4_prev_reg3 = 0;
    p4_reg_changes = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.P4.reg0 != p4_prev_reg0) begin
            p4_reg_changes = p4_reg_changes + 1;
            if (p4_reg_changes < 30) // Limit output
                $display("Time=%0t: P4.reg0 changed: %h -> %h", $time, p4_prev_reg0, dut.P4.reg0);
            p4_prev_reg0 = dut.P4.reg0;
        end
        if (dut.P4.reg1 != p4_prev_reg1) begin
            p4_reg_changes = p4_reg_changes + 1;
            if (p4_reg_changes < 30) // Limit output
                $display("Time=%0t: P4.reg1 changed: %h -> %h", $time, p4_prev_reg1, dut.P4.reg1);
            p4_prev_reg1 = dut.P4.reg1;
        end
        if (dut.P4.reg2 != p4_prev_reg2) begin
            p4_reg_changes = p4_reg_changes + 1;
            if (p4_reg_changes < 30) // Limit output
                $display("Time=%0t: P4.reg2 changed: %h -> %h", $time, p4_prev_reg2, dut.P4.reg2);
            p4_prev_reg2 = dut.P4.reg2;
        end
        if (dut.P4.reg3 != p4_prev_reg3) begin
            p4_reg_changes = p4_reg_changes + 1;
            if (p4_reg_changes < 30) // Limit output
                $display("Time=%0t: P4.reg3 changed: %h -> %h", $time, p4_prev_reg3, dut.P4.reg3);
            p4_prev_reg3 = dut.P4.reg3;
        end
    end
    
    #100;
    $display("\n=== P4 Register Changes: %0d ===", p4_reg_changes);
end

// Track b17 buffer operations
integer p1_buf1_changes, p1_buf2_changes;
integer p2_buf1_changes, p2_buf2_changes;
reg [31:0] p1_prev_buf1, p1_prev_buf2;
reg [31:0] p2_prev_buf1, p2_prev_buf2;

initial begin
    @(posedge rst_n);
    p1_buf1_changes = 0;
    p1_buf2_changes = 0;
    p2_buf1_changes = 0;
    p2_buf2_changes = 0;
    p1_prev_buf1 = 0;
    p1_prev_buf2 = 0;
    p2_prev_buf1 = 0;
    p2_prev_buf2 = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.P1.buf1 != p1_prev_buf1) begin
            p1_buf1_changes = p1_buf1_changes + 1;
            if (p1_buf1_changes < 20)
                $display("Time=%0t: P1.buf1 changed: %h -> %h", $time, p1_prev_buf1, dut.P1.buf1);
            p1_prev_buf1 = dut.P1.buf1;
        end
        
        if (dut.P1.buf2 != p1_prev_buf2) begin
            p1_buf2_changes = p1_buf2_changes + 1;
            if (p1_buf2_changes < 20)
                $display("Time=%0t: P1.buf2 changed: %h -> %h", $time, p1_prev_buf2, dut.P1.buf2);
            p1_prev_buf2 = dut.P1.buf2;
        end
        
        if (dut.P2.buf1 != p2_prev_buf1) begin
            p2_buf1_changes = p2_buf1_changes + 1;
            if (p2_buf1_changes < 20)
                $display("Time=%0t: P2.buf1 changed: %h -> %h", $time, p2_prev_buf1, dut.P2.buf1);
            p2_prev_buf1 = dut.P2.buf1;
        end
        
        if (dut.P2.buf2 != p2_prev_buf2) begin
            p2_buf2_changes = p2_buf2_changes + 1;
            if (p2_buf2_changes < 20)
                $display("Time=%0t: P2.buf2 changed: %h -> %h", $time, p2_prev_buf2, dut.P2.buf2);
            p2_prev_buf2 = dut.P2.buf2;
        end
    end
    
    #100;
    $display("\n=== b17 Buffer Activity Summary ===");
    $display("P1.buf1 changes: %0d", p1_buf1_changes);
    $display("P1.buf2 changes: %0d", p1_buf2_changes);
    $display("P2.buf1 changes: %0d", p2_buf1_changes);
    $display("P2.buf2 changes: %0d", p2_buf2_changes);
end

// Timeout watchdog
initial begin
    #5000000; // 5ms timeout
    $display("\n*** TIMEOUT: Simulation exceeded 5ms ***");
    $finish;
end

endmodule
