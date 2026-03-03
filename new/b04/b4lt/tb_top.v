`timescale 1ns / 1ps

module tb_top;

// State parameters (must match b04.v)
parameter sA = 0;
parameter sB = 1;
parameter sC = 2;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg RESTART;
reg AVERAGE;
reg ENABLE;
reg signed [7:0] DATA_IN;
reg testmode;

// Output signals
wire [7:0] DATA_OUT;

// Loop counter
integer i;

// File for logging (optional)
integer file;

// Instantiate the DUT (Device Under Test)
b04 dut (
    .CLOCK(clk),
    .RESET(~rst_n),  // rst_n is active low, but b04 expects active high reset
    .RESTART(RESTART),
    .AVERAGE(AVERAGE),
    .ENABLE(ENABLE),
    .DATA_IN(DATA_IN),
    .DATA_OUT(DATA_OUT),
    .testmode(testmode)
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
    RESTART = 0;
    AVERAGE = 0;
    ENABLE = 0;
    DATA_IN = 8'h00;
    testmode = 0;
    
    // Open file for logging (optional - comment out if not needed)
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\tREST\tAVG\tENA\tDATA_IN\t\tDATA_OUT\ttest\tstat_o\tstat_s\tRMAX_o\t\tRMAX_s\t\tRMIN_o\t\tRMIN_s\t\tREGD_o\t\tREGD_s\t\tRLAST\t\tREG1\t\tREG2\t\tREG3\t\tREG4\t\ttemp\t\tRES\tAVE\tENA_r\n");
    $fwrite(file, "-----\t----\t---\t---\t--------\t--------\t----\t------\t------\t----------\t----------\t----------\t----------\t----------\t----------\t----------\t----------\t----------\t----------\t----------\t----------\t---\t---\t-----\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation with random inputs ===\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        // Random input generation
        RESTART <= $random;
        AVERAGE <= $random;
        ENABLE <= $random;
        DATA_IN <= $random;
        testmode <= $random;
        
        // Log internal signals to file
        if (file) begin
            $fwrite(file, "%0d\t%b\t%b\t%b\t%d\t\t%d\t\t%b\t%0d\t%0d\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%b\t%b\t%b\n", 
                    i, RESTART, AVERAGE, ENABLE, $signed(DATA_IN), $signed(DATA_OUT), testmode,
                    dut.stato_original, dut.stato_scanFF,
                    $signed(dut.RMAX_original), $signed(dut.RMAX_scanFF),
                    $signed(dut.RMIN_original), $signed(dut.RMIN_scanFF),
                    $signed(dut.REGD_original), $signed(dut.REGD_scanFF),
                    $signed(dut.RLAST), $signed(dut.REG1), $signed(dut.REG2), 
                    $signed(dut.REG3), $signed(dut.REG4), $signed(dut.temp),
                    dut.RES, dut.AVE, dut.ENA);
        end
        
        // Display state transitions
        if (dut.stato_original == sA) begin
            $display("Time=%0t: Cycle %0d - State sA (ORIGINAL)", $time, i);
        end
        
        if (dut.stato_original == sB) begin
            $display("Time=%0t: Cycle %0d - State sB (ORIGINAL) | Initializing RMAX=%d RMIN=%d", 
                     $time, i, $signed(dut.RMAX_original), $signed(dut.RMIN_original));
        end
        
        if (dut.stato_original == sC) begin
            $display("Time=%0t: Cycle %0d - State sC (ORIGINAL) | DATA_IN=%d DATA_OUT=%d ENABLE=%b RESTART=%b AVERAGE=%b", 
                     $time, i, $signed(DATA_IN), $signed(DATA_OUT), ENABLE, RESTART, AVERAGE);
        end
        
        // Display testmode changes
        if (testmode == 1) begin
            $display("Time=%0t: Cycle %0d - TESTMODE ACTIVE | stato_scanFF=%0d RMAX_scanFF=%d RMIN_scanFF=%d REGD_scanFF=%d", 
                     $time, i, dut.stato_scanFF, $signed(dut.RMAX_scanFF), 
                     $signed(dut.RMIN_scanFF), $signed(dut.REGD_scanFF));
        end
        
        // Display MAX/MIN updates
        if (i > 10 && dut.stato_original == sC) begin
            if ($signed(DATA_IN) > $signed(dut.RMAX)) begin
                $display("Time=%0t: Cycle %0d - NEW MAX | DATA_IN=%d > RMAX=%d", 
                         $time, i, $signed(DATA_IN), $signed(dut.RMAX));
            end
            if ($signed(DATA_IN) < $signed(dut.RMIN)) begin
                $display("Time=%0t: Cycle %0d - NEW MIN | DATA_IN=%d < RMIN=%d", 
                         $time, i, $signed(DATA_IN), $signed(dut.RMIN));
            end
        end
        
        // Display RESTART operation
        if (RESTART == 1 && dut.stato_original == sC) begin
            $display("Time=%0t: Cycle %0d - RESTART | RMAX=%d RMIN=%d REGD=%d DATA_OUT=%d", 
                     $time, i, $signed(dut.RMAX), $signed(dut.RMIN), 
                     $signed(dut.REGD), $signed(DATA_OUT));
        end
        
        // Display AVERAGE operation
        if (AVERAGE == 1 && ENABLE == 1 && dut.stato_original == sC) begin
            $display("Time=%0t: Cycle %0d - AVERAGE | DATA_OUT=%d (REG4=%d)", 
                     $time, i, $signed(DATA_OUT), $signed(dut.REG4));
        end
        
        // Display calculation progress every 1000 cycles
        if (i % 1000 == 0) begin
            $display("Time=%0t: Cycle %0d | stato=%0d RMAX=%d RMIN=%d DATA_OUT=%d REG1=%d REG4=%d", 
                     $time, i, dut.stato, $signed(dut.RMAX), $signed(dut.RMIN), 
                     $signed(DATA_OUT), $signed(dut.REG1), $signed(dut.REG4));
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
    $display("=== b04 Data Processing Testbench ===");
    $display("Time\t\trst_n\tENA\tDATA_IN\t\tDATA_OUT\tstato_o\tRMAX_o\t\tRMIN_o\t\ttestmode");
    $display("----\t\t-----\t---\t--------\t--------\t-------\t----------\t----------\t--------");
    $monitor("%0t\t%b\t%b\t%d\t\t%d\t\t%0d\t%d\t\t%d\t\t%b", 
             $time, rst_n, ENABLE, $signed(DATA_IN), $signed(DATA_OUT), 
             dut.stato_original, $signed(dut.RMAX_original), $signed(dut.RMIN_original), testmode);
end

// Generate VCD file for waveform viewing (optional)
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    // Explicitly dump all internal signals - ORIGINAL registers
    $dumpvars(0, dut.stato_original);
    $dumpvars(0, dut.RMAX_original);
    $dumpvars(0, dut.RMIN_original);
    $dumpvars(0, dut.REGD_original);
    // Scan FF registers
    $dumpvars(0, dut.stato_scanFF);
    $dumpvars(0, dut.RMAX_scanFF);
    $dumpvars(0, dut.RMIN_scanFF);
    $dumpvars(0, dut.REGD_scanFF);
    // Muxed wires
    $dumpvars(0, dut.stato);
    $dumpvars(0, dut.RMAX);
    $dumpvars(0, dut.RMIN);
    $dumpvars(0, dut.REGD);
    // Other registers
    $dumpvars(0, dut.RLAST);
    $dumpvars(0, dut.REG1);
    $dumpvars(0, dut.REG2);
    $dumpvars(0, dut.REG3);
    $dumpvars(0, dut.REG4);
    $dumpvars(0, dut.test);
    $dumpvars(0, dut.temp);
    $dumpvars(0, dut.RES);
    $dumpvars(0, dut.AVE);
    $dumpvars(0, dut.ENA);
end

// State name decoder for display
function [63:0] state_name;
    input [1:0] state;
    begin
        case(state)
            sA: state_name = "sA";
            sB: state_name = "sB";
            sC: state_name = "sC";
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
            $display("State: %0s (%0d) [Original]", state_name(dut.stato_original), dut.stato_original);
            $display("State: %0s (%0d) [ScanFF]", state_name(dut.stato_scanFF), dut.stato_scanFF);
            $display("Inputs: RESTART=%b AVERAGE=%b ENABLE=%b DATA_IN=%d testmode=%b", 
                     RESTART, AVERAGE, ENABLE, $signed(DATA_IN), testmode);
            $display("Output: DATA_OUT=%d", $signed(DATA_OUT));
            
            $display("\nOriginal Registers:");
            $display("  RMAX_original=%d RMIN_original=%d REGD_original=%d", 
                     $signed(dut.RMAX_original), $signed(dut.RMIN_original), $signed(dut.REGD_original));
            
            $display("\nScanFF Registers:");
            $display("  RMAX_scanFF=%d RMIN_scanFF=%d REGD_scanFF=%d", 
                     $signed(dut.RMAX_scanFF), $signed(dut.RMIN_scanFF), $signed(dut.REGD_scanFF));
            
            $display("\nMuxed Values (active):");
            $display("  RMAX=%d RMIN=%d REGD=%d stato=%0d", 
                     $signed(dut.RMAX), $signed(dut.RMIN), $signed(dut.REGD), dut.stato);
            
            $display("\nShift Register Chain:");
            $display("  REG1=%d REG2=%d REG3=%d REG4=%d", 
                     $signed(dut.REG1), $signed(dut.REG2), $signed(dut.REG3), $signed(dut.REG4));
            $display("  RLAST=%d", $signed(dut.RLAST));
            
            $display("\nTemporary Values:");
            $display("  test=%d temp=%d", $signed(dut.test), $signed(dut.temp));
            $display("  RES=%b AVE=%b ENA=%b", dut.RES, dut.AVE, dut.ENA);
            
            // State-specific information
            case(dut.stato_original)
                sA: begin
                    $display("\nStatus: Initialization state, moving to sB");
                end
                sB: begin
                    $display("\nStatus: Setting initial MAX/MIN from DATA_IN");
                end
                sC: begin
                    $display("\nStatus: Processing data");
                    if (RESTART) begin
                        $display("  RESTART active: Computing (RMAX+RMIN)/2");
                    end else if (ENABLE) begin
                        if (AVERAGE) begin
                            $display("  AVERAGE mode: Output REG4");
                        end else begin
                            $display("  Normal mode: Computing (DATA_IN+REG4)/2");
                        end
                    end else begin
                        $display("  Output RLAST (hold mode)");
                    end
                end
            endcase
        end
    end
end

// Track register updates
reg signed [31:0] prev_RMAX, prev_RMIN;
reg signed [7:0] prev_DATA_OUT;

initial begin
    @(posedge rst_n);
    prev_RMAX = 0;
    prev_RMIN = 0;
    prev_DATA_OUT = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        // Track RMAX changes
        if (dut.RMAX != prev_RMAX) begin
            $display("Time=%0t: RMAX changed: %d -> %d", $time, $signed(prev_RMAX), $signed(dut.RMAX));
            prev_RMAX = dut.RMAX;
        end
        
        // Track RMIN changes
        if (dut.RMIN != prev_RMIN) begin
            $display("Time=%0t: RMIN changed: %d -> %d", $time, $signed(prev_RMIN), $signed(dut.RMIN));
            prev_RMIN = dut.RMIN;
        end
        
        // Track DATA_OUT changes
        if (DATA_OUT != prev_DATA_OUT) begin
            $display("Time=%0t: DATA_OUT changed: %d -> %d", $time, $signed(prev_DATA_OUT), $signed(DATA_OUT));
            prev_DATA_OUT = DATA_OUT;
        end
    end
end

// Track testmode transitions
reg prev_testmode;

initial begin
    @(posedge rst_n);
    prev_testmode = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (testmode != prev_testmode) begin
            if (testmode) begin
                $display("Time=%0t: TESTMODE ENABLED - Using ScanFF registers", $time);
            end else begin
                $display("Time=%0t: TESTMODE DISABLED - Using Original registers", $time);
            end
            prev_testmode = testmode;
        end
    end
end

endmodule
