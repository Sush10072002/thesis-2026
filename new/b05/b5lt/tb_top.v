`timescale 1ns / 1ps

module tb_top;

// State parameters (must match b05.v)
parameter st0 = 0;
parameter st1 = 1;
parameter st2 = 2;
parameter st3 = 3;
parameter st4 = 4;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg START;
reg testmode;

// Output signals
wire SIGN;
wire [6:0] DISPMAX1;
wire [6:0] DISPMAX2;
wire [6:0] DISPMAX3;
wire [6:0] DISPNUM1;
wire [6:0] DISPNUM2;

// Loop counter
integer i;

// File for logging (optional)
integer file;

// Instantiate the DUT (Device Under Test)
b05 dut (
    .CLOCK(clk),
    .RESET(~rst_n),  // rst_n is active low, but b05 expects active high reset
    .START(START),
    .testmode(testmode),
    .SIGN(SIGN),
    .DISPMAX1(DISPMAX1),
    .DISPMAX2(DISPMAX2),
    .DISPMAX3(DISPMAX3),
    .DISPNUM1(DISPNUM1),
    .DISPNUM2(DISPNUM2)
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
    START = 0;
    testmode = 0;
    
    // Open file for logging (optional - comment out if not needed)
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\tSTART\ttestm\tSIGN\tDMAX1\tDMAX2\tDMAX3\tDNUM1\tDNUM2\tSTATO\tNUM\tMAR\tTEMP\tMAX\tFLAG\tMAG1\tMAG2\tMIN1\tEN_D\tRES_D\tTM\tTN_o\tTN_s\tTN\tTMN\tAC1\tAC2\n");
    $fwrite(file, "-----\t-----\t-----\t----\t-----\t-----\t-----\t-----\t-----\t-----\t---\t---\t----\t---\t----\t----\t----\t----\t----\t-----\t--\t----\t----\t--\t---\t---\t---\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation with random inputs ===\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        // Random input generation
        START <= $random;
        testmode <= $random;
        
        // Log internal signals to file
        if (file) begin
            $fwrite(file, "%0d\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%0d\t%0d\t%0d\t%0d\t%0d\t%b\t%b\t%b\t%b\t%b\t%b\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\n", 
                    i, START, testmode, SIGN, DISPMAX1, DISPMAX2, DISPMAX3, DISPNUM1, DISPNUM2,
                    dut.STATO, dut.NUM, dut.MAR, dut.TEMP, dut.MAX, dut.FLAG,
                    dut.MAG1, dut.MAG2, dut.MIN1, dut.EN_DISP, dut.RES_DISP,
                    dut.TM, dut.TN_original, dut.TN_scanFF, dut.TN, dut.TMN,
                    $signed(dut.AC1), $signed(dut.AC2));
        end
        
        // Display state transitions
        if (dut.STATO == st0) begin
            $display("Time=%0t: Cycle %0d - State st0", $time, i);
        end
        
        if (dut.STATO == st1 && START == 1) begin
            $display("Time=%0t: Cycle %0d - st1: START detected", $time, i);
        end
        
        if (dut.STATO == st2) begin
            $display("Time=%0t: Cycle %0d - st2: Initialize MAX=%0d TEMP=%0d from MEM[%0d]", 
                     $time, i, dut.MAX, dut.TEMP, dut.MAR);
        end
        
        if (dut.STATO == st3) begin
            $display("Time=%0t: Cycle %0d - st3: Processing MEM[%0d]=%0d | NUM=%0d MAX=%0d FLAG=%b", 
                     $time, i, dut.MAR, dut.MEM[dut.MAR], dut.NUM, dut.MAX, dut.FLAG);
        end
        
        if (dut.STATO == st4 && dut.MAR == 31) begin
            $display("Time=%0t: Cycle %0d - st4: Scan complete | NUM=%0d MAX=%0d", 
                     $time, i, dut.NUM, dut.MAX);
        end
        
        // Display testmode transitions
        if (testmode == 1) begin
            $display("Time=%0t: Cycle %0d - TESTMODE ACTIVE | TN_scanFF=%0d (TN=%0d)", 
                     $time, i, dut.TN_scanFF, dut.TN);
        end
        
        // Display peak detection
        if (dut.STATO == st3 && dut.FLAG == 1) begin
            $display("Time=%0t: Cycle %0d - FLAG SET (potential peak) | MEM[%0d]=%0d", 
                     $time, i, dut.MAR, dut.MEM[dut.MAR]);
        end
        
        if (dut.STATO == st3 && dut.MIN1 == 1 && dut.FLAG == 1) begin
            $display("Time=%0t: Cycle %0d - PEAK DETECTED | NUM incremented to %0d", 
                     $time, i, dut.NUM + 1);
        end
        
        // Display MAX updates
        if (dut.STATO == st3 && dut.MAG2 == 1 && dut.MAG1 == 1) begin
            $display("Time=%0t: Cycle %0d - NEW MAX | MEM[%0d]=%0d > MAX=%0d", 
                     $time, i, dut.MAR, dut.MEM[dut.MAR], dut.MAX);
        end
        
        // Display output when active
        if (dut.EN_DISP == 0 && dut.RES_DISP == 1) begin
            $display("Time=%0t: Cycle %0d - DISPLAY ACTIVE | SIGN=%b MAX=%b%b%b NUM=%b%b", 
                     $time, i, SIGN, DISPMAX1, DISPMAX2, DISPMAX3, DISPNUM1, DISPNUM2);
        end
        
        // Display calculation progress every 1000 cycles
        if (i % 1000 == 0) begin
            $display("Time=%0t: Cycle %0d | STATO=%0d MAR=%0d NUM=%0d MAX=%0d TN=%0d testmode=%b", 
                     $time, i, dut.STATO, dut.MAR, dut.NUM, dut.MAX, dut.TN, testmode);
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
    $display("=== b05 Peak Detector with Testmode Testbench ===");
    $display("Time\t\trst_n\tSTART\tSTATO\tMAR\tNUM\tMAX\tSIGN\ttestmode\tTN_o\tTN_s\tTN");
    $display("----\t\t-----\t-----\t-----\t---\t---\t---\t----\t--------\t----\t----\t--");
    $monitor("%0t\t%b\t%b\t%0d\t%0d\t%0d\t%0d\t%b\t%b\t\t%0d\t%0d\t%0d", 
             $time, rst_n, START, dut.STATO, dut.MAR, dut.NUM, dut.MAX, SIGN, 
             testmode, dut.TN_original, dut.TN_scanFF, dut.TN);
end

// Generate VCD file for waveform viewing (optional)
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    // Explicitly dump all internal signals
    $dumpvars(0, dut.STATO);
    $dumpvars(0, dut.NUM);
    $dumpvars(0, dut.MAR);
    $dumpvars(0, dut.TEMP);
    $dumpvars(0, dut.MAX);
    $dumpvars(0, dut.FLAG);
    $dumpvars(0, dut.MAG1);
    $dumpvars(0, dut.MAG2);
    $dumpvars(0, dut.MIN1);
    $dumpvars(0, dut.EN_DISP);
    $dumpvars(0, dut.RES_DISP);
    $dumpvars(0, dut.AC1);
    $dumpvars(0, dut.AC2);
    $dumpvars(0, dut.TM);
    $dumpvars(0, dut.TN_original);
    $dumpvars(0, dut.TN_scanFF);
    $dumpvars(0, dut.TN);
    $dumpvars(0, dut.TMN);
    // Dump memory array
    for (i=0; i<32; i=i+1) begin
        $dumpvars(0, dut.MEM[i]);
    end
end

// State name decoder for display
function [63:0] state_name;
    input [2:0] state;
    begin
        case(state)
            st0: state_name = "st0";
            st1: state_name = "st1";
            st2: state_name = "st2";
            st3: state_name = "st3";
            st4: state_name = "st4";
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
            $display("State: %0s (%0d)", state_name(dut.STATO), dut.STATO);
            $display("Inputs: START=%b testmode=%b", START, testmode);
            $display("Outputs: SIGN=%b DISPMAX=%b%b%b DISPNUM=%b%b", 
                     SIGN, DISPMAX1, DISPMAX2, DISPMAX3, DISPNUM1, DISPNUM2);
            
            $display("\nTN Register System:");
            $display("  TN_original=%0d", dut.TN_original);
            $display("  TN_scanFF=%0d", dut.TN_scanFF);
            $display("  TN (muxed)=%0d  [testmode=%b]", dut.TN, testmode);
            
            $display("\nProcessing Registers:");
            $display("  NUM=%0d MAR=%0d", dut.NUM, dut.MAR);
            $display("  MAX=%0d TEMP=%0d", dut.MAX, dut.TEMP);
            $display("  TM=%0d TMN=%0d", dut.TM, dut.TMN);
            
            $display("\nFlags:");
            $display("  FLAG=%b MAG1=%b MAG2=%b MIN1=%b", dut.FLAG, dut.MAG1, dut.MAG2, dut.MIN1);
            $display("  EN_DISP=%b RES_DISP=%b", dut.EN_DISP, dut.RES_DISP);
            
            $display("\nComparison Results:");
            $display("  AC1 (MEM[MAR]-TEMP)=%0d", $signed(dut.AC1));
            $display("  AC2 (MEM[MAR]-MAX)=%0d", $signed(dut.AC2));
            
            if (dut.MAR < 32) begin
                $display("\nCurrent Memory Value:");
                $display("  MEM[%0d]=%0d", dut.MAR, dut.MEM[dut.MAR]);
            end
            
            // State-specific information
            case(dut.STATO)
                st0: begin
                    $display("\nStatus: Reset/Initialization");
                end
                st1: begin
                    $display("\nStatus: Waiting for START signal");
                end
                st2: begin
                    $display("\nStatus: Loading initial MAX and TEMP");
                end
                st3: begin
                    $display("\nStatus: Processing memory array");
                    if (dut.MIN1) begin
                        $display("  MIN1 active: Current value < TEMP");
                    end
                    if (dut.MAG1) begin
                        $display("  MAG1 active: Current value > TEMP");
                    end
                    if (dut.MAG2) begin
                        $display("  MAG2 active: Current value < MAX (new max candidate)");
                    end
                end
                st4: begin
                    $display("\nStatus: End of scan or increment MAR");
                    if (dut.MAR == 31) begin
                        $display("  Scan complete, final NUM=%0d MAX=%0d", dut.NUM, dut.MAX);
                    end
                end
            endcase
        end
    end
end

// Memory content display
initial begin
    @(posedge rst_n);
    #10;
    
    $display("\n=== Memory Contents (MEM[31:0]) ===");
    for (i=31; i>=0; i=i-1) begin
        $display("MEM[%2d] = %4d", i, dut.MEM[i]);
    end
    $display("");
end

// Track peak detections
integer peak_count;

initial begin
    @(posedge rst_n);
    peak_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.STATO == st3 && dut.MIN1 == 1 && dut.FLAG == 1) begin
            peak_count = peak_count + 1;
            $display("Time=%0t: PEAK #%0d detected at MAR=%0d | NUM=%0d", 
                     $time, peak_count, dut.MAR, dut.NUM);
        end
    end
    
    #100;
    $display("\n=== Peak Detection Summary ===");
    $display("Total peaks detected: %0d", peak_count);
end

// Track testmode transitions and TN mux behavior
reg prev_testmode;

initial begin
    @(posedge rst_n);
    prev_testmode = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (testmode != prev_testmode) begin
            if (testmode) begin
                $display("Time=%0t: TESTMODE ENABLED - TN switches to TN_scanFF=%0d", 
                         $time, dut.TN_scanFF);
            end else begin
                $display("Time=%0t: TESTMODE DISABLED - TN switches to TN_original=%0d", 
                         $time, dut.TN_original);
            end
            prev_testmode = testmode;
        end
    end
end

// Track display output changes
reg prev_SIGN;
reg [6:0] prev_DISPMAX1, prev_DISPMAX2, prev_DISPMAX3;
reg [6:0] prev_DISPNUM1, prev_DISPNUM2;

initial begin
    @(posedge rst_n);
    prev_SIGN = 0;
    prev_DISPMAX1 = 0;
    prev_DISPMAX2 = 0;
    prev_DISPMAX3 = 0;
    prev_DISPNUM1 = 0;
    prev_DISPNUM2 = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (SIGN != prev_SIGN || 
            DISPMAX1 != prev_DISPMAX1 || DISPMAX2 != prev_DISPMAX2 || DISPMAX3 != prev_DISPMAX3 ||
            DISPNUM1 != prev_DISPNUM1 || DISPNUM2 != prev_DISPNUM2) begin
            
            $display("Time=%0t: DISPLAY UPDATE | SIGN=%b MAX=%b%b%b NUM=%b%b", 
                     $time, SIGN, DISPMAX1, DISPMAX2, DISPMAX3, DISPNUM1, DISPNUM2);
            
            prev_SIGN = SIGN;
            prev_DISPMAX1 = DISPMAX1;
            prev_DISPMAX2 = DISPMAX2;
            prev_DISPMAX3 = DISPMAX3;
            prev_DISPNUM1 = DISPNUM1;
            prev_DISPNUM2 = DISPNUM2;
        end
    end
end

endmodule
