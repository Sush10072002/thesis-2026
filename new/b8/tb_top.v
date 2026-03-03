`timescale 1ns / 1ps

module tb_top;

// State parameters (must match b08.v)
parameter start_st = 0;
parameter init = 1;
parameter loop_st = 2;
parameter the_end = 3;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg START;
reg [7:0] I;

// Output signals
wire [3:0] O;

// Loop counter
integer i;

// File for logging (optional)
integer file;

// Instantiate the DUT (Device Under Test)
b08 dut (
    .CLOCK(clk),
    .RESET(~rst_n),  // rst_n is active low, but b08 expects active high reset
    .START(START),
    .I(I),
    .O(O)
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
    I = 8'b00000000;
    
    // Open file for logging (optional - comment out if not needed)
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\tSTART\tI\t\tO\tSTATO\tMAR\tIN_R\t\tOUT_R\tROM_1\t\tROM_2\t\tROM_OR\n");
    $fwrite(file, "-----\t-----\t--------\t----\t-----\t---\t--------\t-----\t--------\t--------\t------\n");
    
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
        I <= $random;
        
        // Log internal signals to file
        if (file) begin
            $fwrite(file, "%0d\t%b\t%b\t%b\t%0d\t%0d\t%b\t%b\t%b\t%b\t%b\n", 
                    i, START, I, O, dut.STATO, dut.MAR, dut.IN_R, dut.OUT_R, 
                    dut.ROM_1, dut.ROM_2, dut.ROM_OR);
        end
        
        // Display state transitions
        if (dut.STATO == start_st && START == 1) begin
            $display("Time=%0t: Cycle %0d - START detected, I=%b", $time, i, I);
        end
        
        if (dut.STATO == init) begin
            $display("Time=%0t: Cycle %0d - State INIT | IN_R=%b", $time, i, dut.IN_R);
        end
        
        if (dut.STATO == loop_st) begin
            $display("Time=%0t: Cycle %0d - State LOOP_ST | MAR=%0d ROM_1=%b ROM_2=%b", 
                     $time, i, dut.MAR, dut.ROM_1, dut.ROM_2);
        end
        
        if (dut.STATO == the_end && dut.MAR == 7 && START == 0) begin
            $display("Time=%0t: Cycle %0d - Computation complete | O=%b OUT_R=%b", 
                     $time, i, O, dut.OUT_R);
        end
        
        // Display when output changes
        if (i > 0 && O != 4'b0000) begin
            $display("Time=%0t: Cycle %0d - Output O=%b | IN_R=%b STATO=%0d MAR=%0d", 
                     $time, i, O, dut.IN_R, dut.STATO, dut.MAR);
        end
        
        // Display calculation progress every 1000 cycles
        if (i % 1000 == 0) begin
            $display("Time=%0t: Cycle %0d | STATO=%0d MAR=%0d IN_R=%b OUT_R=%b O=%b", 
                     $time, i, dut.STATO, dut.MAR, dut.IN_R, dut.OUT_R, O);
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
    $display("=== b08 Testbench ===");
    $display("Time\t\trst_n\tSTART\tI\t\tO\tSTATO\tMAR\tOUT_R");
    $display("----\t\t-----\t-----\t--------\t----\t-----\t---\t-----");
    $monitor("%0t\t%b\t%b\t%b\t%b\t%0d\t%0d\t%b", 
             $time, rst_n, START, I, O, dut.STATO, dut.MAR, dut.OUT_R);
end

// Generate VCD file for waveform viewing (optional)
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    // Explicitly dump all internal signals
    $dumpvars(0, dut.STATO);
    $dumpvars(0, dut.MAR);
    $dumpvars(0, dut.IN_R);
    $dumpvars(0, dut.OUT_R);
    $dumpvars(0, dut.ROM_1);
    $dumpvars(0, dut.ROM_2);
    $dumpvars(0, dut.ROM_OR);
    // Dump ROM array
    for (i=0; i<8; i=i+1) begin
        $dumpvars(0, dut.ROM[i]);
    end
end

// ROM content display
initial begin
    // Wait for reset deassertion
    @(posedge rst_n);
    #10;
    
    $display("\n=== ROM Contents ===");
    for (i=0; i<8; i=i+1) begin
        $display("ROM[%0d] = %b (0x%h) | [19:12]=%b [11:4]=%b [3:0]=%b", 
                 i, dut.ROM[i], dut.ROM[i], 
                 dut.ROM[i][19:12], dut.ROM[i][11:4], dut.ROM[i][3:0]);
    end
    $display("");
end

// State name decoder for display
function [127:0] state_name;
    input [2:0] state;
    begin
        case(state)
            start_st: state_name = "start_st";
            init: state_name = "init";
            loop_st: state_name = "loop_st";
            the_end: state_name = "the_end";
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
            $display("Inputs: START=%b, I=%b", START, I);
            $display("MAR: %0d", dut.MAR);
            $display("IN_R: %b", dut.IN_R);
            $display("OUT_R: %b, O: %b", dut.OUT_R, O);
            $display("ROM_1: %b, ROM_2: %b, ROM_OR: %b", dut.ROM_1, dut.ROM_2, dut.ROM_OR);
            if (dut.STATO == loop_st) begin
                $display("ROM[%0d]: %b", dut.MAR, dut.ROM[dut.MAR]);
                $display("Condition: (ROM_2 & ~IN_R) | (ROM_1 & IN_R) | (ROM_2 & ROM_1)");
                $display("  ROM_2 & ~IN_R = %b", dut.ROM_2 & ~dut.IN_R);
                $display("  ROM_1 & IN_R  = %b", dut.ROM_1 & dut.IN_R);
                $display("  ROM_2 & ROM_1 = %b", dut.ROM_2 & dut.ROM_1);
                $display("  Result        = %b", (dut.ROM_2 & ~dut.IN_R) | (dut.ROM_1 & dut.IN_R) | (dut.ROM_2 & dut.ROM_1));
            end
        end
    end
end

// Track ROM access patterns
integer rom_access_count [0:7];
initial begin
    for (i=0; i<8; i=i+1) begin
        rom_access_count[i] = 0;
    end
    
    @(posedge rst_n);
    
    repeat(50000) begin
        @(posedge clk);
        if (dut.STATO == loop_st) begin
            rom_access_count[dut.MAR] = rom_access_count[dut.MAR] + 1;
        end
    end
    
    #100;
    $display("\n=== ROM Access Pattern ===");
    for (i=0; i<8; i=i+1) begin
        $display("ROM[%0d] accessed %0d times", i, rom_access_count[i]);
    end
end

endmodule