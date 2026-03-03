`timescale 1ns / 1ps

module tb_top;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg START;

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
    
    // Open file for logging (optional - comment out if not needed)
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\tSTART\tSIGN\tDISPMAX1\tDISPMAX2\tDISPMAX3\tDISPNUM1\tDISPNUM2\tSTATO\tNUM\tMAR\tMAX\tTEMP\tFLAG\tMAG1\tMAG2\tMIN1\tEN_DISP\tRES_DISP\n");
    $fwrite(file, "-----\t-----\t----\t--------\t--------\t--------\t--------\t--------\t-----\t---\t---\t---\t----\t----\t----\t----\t----\t-------\t--------\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation with random START input ===\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        // Random input generation for START signal
        START <= $random;
        
        // Log internal signals to file
        if (file) begin
            $fwrite(file, "%0d\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%0d\t%0d\t%0d\t%0d\t%0d\t%b\t%b\t%b\t%b\t%b\t%b\n", 
                    i, START, SIGN, DISPMAX1, DISPMAX2, DISPMAX3, DISPNUM1, DISPNUM2,
                    dut.STATO, dut.NUM, dut.MAR, dut.MAX, dut.TEMP, dut.FLAG,
                    dut.MAG1, dut.MAG2, dut.MIN1, dut.EN_DISP, dut.RES_DISP);
        end
        
        // Display state transitions
        if (dut.STATO == 0 && i > 0) begin
            $display("Time=%0t: Entered st0 at cycle %0d", $time, i);
        end
        if (dut.STATO == 2 && START == 1) begin
            $display("Time=%0t: START detected, entering st2 at cycle %0d", $time, i);
        end
        if (dut.STATO == 4 && dut.MAR == 31) begin
            $display("Time=%0t: Completed scan at cycle %0d | NUM=%0d MAX=%0d SIGN=%b", 
                     $time, i, dut.NUM, dut.MAX, SIGN);
        end
        
        // Display significant events
        if (dut.EN_DISP == 1 && i % 100 == 0) begin
            $display("Time=%0t: Cycle %0d Display enabled | DISPMAX=%b%b%b DISPNUM=%b%b SIGN=%b", 
                     $time, i, DISPMAX1, DISPMAX2, DISPMAX3, DISPNUM1, DISPNUM2, SIGN);
        end
        
        // Display when NUM changes (peak detection)
        if (i > 10 && dut.FLAG == 1) begin
            $display("Time=%0t: Cycle %0d FLAG set | NUM=%0d MAR=%0d MAX=%0d MEM[MAR]=%0d", 
                     $time, i, dut.NUM, dut.MAR, dut.MAX, dut.MEM[dut.MAR]);
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
    $display("=== b05 Peak Detector Testbench ===");
    $display("Time\t\trst_n\tSTART\tSTATO\tMAR\tNUM\tMAX\tSIGN\tDISPMAX1");
    $display("----\t\t-----\t-----\t-----\t---\t---\t---\t----\t--------");
    $monitor("%0t\t%b\t%b\t%0d\t%0d\t%0d\t%0d\t%b\t%b", 
             $time, rst_n, START, dut.STATO, dut.MAR, dut.NUM, dut.MAX, SIGN, DISPMAX1);
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
    $dumpvars(0, dut.TN);
    $dumpvars(0, dut.TMN);
    // Dump memory array
    for (i=0; i<32; i=i+1) begin
        $dumpvars(0, dut.MEM[i]);
    end
end


// Memory dump at end of simulation
initial begin
    #(50000 * 10 + 200);  // Wait until end of simulation
    $display("\n=== Complete Memory Dump ===");
    for (i=0; i<32; i=i+1) begin
        $display("MEM[%2d] = %4d (0x%h)", i, dut.MEM[i], dut.MEM[i]);
    end
end

endmodule
