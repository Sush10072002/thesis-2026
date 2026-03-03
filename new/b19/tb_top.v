`timescale 1ns / 1ps

module tb_top;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals for b19
reg bs;
reg na;
reg hold;
reg [10:0] in1;
reg [10:0] in2;
reg [19:0] in3;

// Output signals from b19
wire [29:0] ris;

// Loop counter
integer i;

// File for logging
integer file;

// Tracking variables
integer sel1_transitions;
integer sel2_transitions;
reg prev_sel1, prev_sel2;

// Instantiate the DUT (Device Under Test)
b19 dut (
    .clock(clk),
    .reset(~rst_n),  // rst_n is active low, but b19 expects active high reset
    .bs(bs),
    .na(na),
    .hold(hold),
    .in1(in1),
    .in2(in2),
    .in3(in3),
    .ris(ris)
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
    bs = 1;
    na = 1;
    hold = 0;
    in1 = 11'h000;
    in2 = 11'h000;
    in3 = 20'h00000;
    
    // Open file for logging
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\tbs\tna\thold\tin1\t\tin2\t\tin3\t\tris\t\tsel1\tsel2\tdo1\t\tdo2\t\tax1\tax2\n");
    $fwrite(file, "-----\t--\t--\t----\t---\t\t---\t\t-----\t\t--------\t----\t----\t-----\t\t-----\t\t---\t---\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation for b19 with random inputs ===\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        
        // Random input generation
        in1 <= $random % 2048;        // 11-bit random value (0-2047)
        in2 <= $random % 2048;        // 11-bit random value (0-2047)
        in3 <= $random % 1048576;     // 20-bit random value (0-1048575)
        
        // Randomly toggle control signals
        if (i % 100 == 0) begin
            bs <= $random % 2;
            na <= $random % 2;
            hold <= $random % 2;
        end
        
        // Generate specific test patterns every 1000 cycles
        if (i % 1000 == 0) begin
            in1 <= 11'h3FF;  // Max value
            in2 <= 11'h3FF;  // Max value
            in3 <= 20'hFFFFF; // Max value
        end
        else if (i % 1000 == 1) begin
            in1 <= 11'h000;  // Min value
            in2 <= 11'h000;  // Min value
            in3 <= 20'h00000; // Min value
        end
        else if (i % 1000 == 2) begin
            in1 <= 11'h2AA;  // Alternating pattern
            in2 <= 11'h555;  // Alternating pattern
            in3 <= 20'hAAAAA;
        end
        
        // Log to file
        if (file) begin
            $fwrite(file, "%0d\t%b\t%b\t%b\t%h\t%h\t%h\t%h\t%b\t%b\t%h\t%h\t%h\t%h\n",
                    i, bs, na, hold, in1, in2, in3, ris,
                    dut.sel1, dut.sel2, dut.do1, dut.do2, dut.ax1, dut.ax2);
        end
        
        // Display progress every 1000 cycles
        if (i % 1000 == 0) begin
            $display("Cycle %0d | in1=%h in2=%h in3=%h | ris=%h | sel1=%b sel2=%b | do1=%h do2=%h",
                     i, in1, in2, in3, ris, dut.sel1, dut.sel2, dut.do1, dut.do2);
        end
    end
    
    // Close file and finish simulation
    if (file) $fclose(file);
    
    $display("\n=== Simulation Complete ===");
    $display("Total cycles run: %0d", i);
    $display("sel1 transitions: %0d", sel1_transitions);
    $display("sel2 transitions: %0d", sel2_transitions);
    $display("Check 'simulation_log.txt' for detailed signal log");
    $finish;
end

// Monitor for debugging
initial begin
    $display("=== b19 Circuit Testbench ===");
    $display("Time\t\trst_n\tbs\tna\thold\tin1\tin2\tin3\t\tris\t\tsel1\tsel2");
    $display("----\t\t-----\t--\t--\t----\t---\t---\t-----\t\t--------\t----\t----");
    $monitor("%0t\t%b\t%b\t%b\t%b\t%h\t%h\t%h\t%h\t%b\t%b",
             $time, rst_n, bs, na, hold, in1, in2, in3, ris, dut.sel1, dut.sel2);
end

// Generate VCD file for waveform viewing
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    
    // Dump DUT signals
    $dumpvars(0, dut.sel1);
    $dumpvars(0, dut.sel2);
    $dumpvars(0, dut.do1);
    $dumpvars(0, dut.do2);
    $dumpvars(0, dut.ax1);
    $dumpvars(0, dut.ax2);
    $dumpvars(0, dut.di1);
    $dumpvars(0, dut.di2);
    
    // Dump b18 P1 signals
    $dumpvars(0, dut.P1.dout);
    $dumpvars(0, dut.P1.aux);
    $dumpvars(0, dut.P1.tad1);
    $dumpvars(0, dut.P1.tad2);
    $dumpvars(0, dut.P1.tad3);
    $dumpvars(0, dut.P1.tad4);
    
    // Dump b18 P2 signals
    $dumpvars(0, dut.P2.dout);
    $dumpvars(0, dut.P2.aux);
    $dumpvars(0, dut.P2.tad1);
    $dumpvars(0, dut.P2.tad2);
    $dumpvars(0, dut.P2.tad3);
    $dumpvars(0, dut.P2.tad4);
end

// Detailed snapshot every 100 cycles
initial begin
    @(posedge rst_n);
    
    for (i=0; i<500; i=i+1) begin
        @(posedge clk);
        if (i % 100 == 0) begin
            $display("\n--- Cycle %0d Snapshot ---", i);
            $display("Inputs:");
            $display("  bs=%b na=%b hold=%b", bs, na, hold);
            $display("  in1=%h (%0d)", in1, in1);
            $display("  in2=%h (%0d)", in2, in2);
            $display("  in3=%h (%0d)", in3, in3);
            $display("Outputs:");
            $display("  ris=%h (%0d)", ris, $signed(ris));
            $display("Internal signals:");
            $display("  sel1=%b sel2=%b", dut.sel1, dut.sel2);
            $display("  do1=%h (%0d) do2=%h (%0d)", dut.do1, dut.do1, dut.do2, dut.do2);
            $display("  ax1=%h ax2=%h", dut.ax1, dut.ax2);
            $display("  di1=%h di2=%h", dut.di1, dut.di2);
            $display("P1 (b18) signals:");
            $display("  dout=%h aux=%h", dut.P1.dout, dut.P1.aux);
            $display("  tad1=%h tad2=%h tad3=%h tad4=%h", 
                     dut.P1.tad1, dut.P1.tad2, dut.P1.tad3, dut.P1.tad4);
            $display("P2 (b18) signals:");
            $display("  dout=%h aux=%h", dut.P2.dout, dut.P2.aux);
            $display("  tad1=%h tad2=%h tad3=%h tad4=%h",
                     dut.P2.tad1, dut.P2.tad2, dut.P2.tad3, dut.P2.tad4);
        end
    end
end

// Track sel1 and sel2 transitions
initial begin
    @(posedge rst_n);
    prev_sel1 = dut.sel1;
    prev_sel2 = dut.sel2;
    sel1_transitions = 0;
    sel2_transitions = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.sel1 != prev_sel1) begin
            sel1_transitions = sel1_transitions + 1;
            $display("Time=%0t: Cycle %0d - sel1 changed: %b -> %b (do2=%0d)", 
                     $time, i, prev_sel1, dut.sel1, dut.do2);
            prev_sel1 = dut.sel1;
        end
        
        if (dut.sel2 != prev_sel2) begin
            sel2_transitions = sel2_transitions + 1;
            $display("Time=%0t: Cycle %0d - sel2 changed: %b -> %b (do1=%0d)", 
                     $time, i, prev_sel2, dut.sel2, dut.do1);
            prev_sel2 = dut.sel2;
        end
    end
    
    #100;
    $display("\n=== Transition Summary ===");
    $display("sel1 transitions: %0d", sel1_transitions);
    $display("sel2 transitions: %0d", sel2_transitions);
end

// Monitor output changes
reg [29:0] prev_ris;
integer ris_change_count;

initial begin
    @(posedge rst_n);
    prev_ris = ris;
    ris_change_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (ris != prev_ris) begin
            ris_change_count = ris_change_count + 1;
            if (ris_change_count < 20) begin  // Display first 20 changes
                $display("Time=%0t: ris changed: %h -> %h", $time, prev_ris, ris);
            end
            prev_ris = ris;
        end
    end
    
    #100;
    $display("Total ris changes: %0d", ris_change_count);
end

// Specific pattern tests to trigger sel transitions
initial begin
    @(posedge rst_n);
    #100;
    
    // Try to trigger sel2 = 1 (when do1 == 39)
    $display("\n=== Running targeted tests to trigger state changes ===");
    
    repeat(100) begin
        @(posedge clk);
        in1 = 78;   // Will divide by 2 to potentially get do1 = 39
        in2 = 256;
        in3 = 1000;
    end
    
    // Try to trigger sel2 = 0 (when do1 == 1735)
    repeat(100) begin
        @(posedge clk);
        in1 = 3470;  // Will divide by 2 to potentially get do1 = 1735
        in2 = 512;
        in3 = 2000;
    end
    
    // Try to trigger sel1 = 1 (when do2 == 398)
    repeat(100) begin
        @(posedge clk);
        in1 = 200;
        in2 = 6368;  // Will divide by 16 to potentially get do2 = 398
        in3 = 3000;
    end
    
    // Try to trigger sel1 = 0 (when do2 == 1013)
    repeat(100) begin
        @(posedge clk);
        in1 = 300;
        in2 = 16208; // Will divide by 16 to potentially get do2 = 1013
        in3 = 4000;
    end
end

// Coverage checker
integer max_ris, min_ris;
integer max_do1, min_do1;
integer max_do2, min_do2;

initial begin
    @(posedge rst_n);
    max_ris = 0; min_ris = 30'h3FFFFFFF;
    max_do1 = 0; min_do1 = 20'hFFFFF;
    max_do2 = 0; min_do2 = 20'hFFFFF;
    
    repeat(50000) begin
        @(posedge clk);
        
        if ($signed(ris) > $signed(max_ris)) max_ris = ris;
        if ($signed(ris) < $signed(min_ris)) min_ris = ris;
        
        if (dut.do1 > max_do1) max_do1 = dut.do1;
        if (dut.do1 < min_do1) min_do1 = dut.do1;
        
        if (dut.do2 > max_do2) max_do2 = dut.do2;
        if (dut.do2 < min_do2) min_do2 = dut.do2;
    end
    
    #100;
    $display("\n=== Coverage Summary ===");
    $display("ris range: %h to %h (%0d to %0d)", min_ris, max_ris, $signed(min_ris), $signed(max_ris));
    $display("do1 range: %h to %h (%0d to %0d)", min_do1, max_do1, min_do1, max_do1);
    $display("do2 range: %h to %h (%0d to %0d)", min_do2, max_do2, min_do2, max_do2);
end

endmodule
