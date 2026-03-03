`timescale 1ns / 1ps

module tb_top;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg START;
reg [7:0] I;

// Output signals
wire [3:0] O;

// Loop counter
integer i, j;

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
    $fwrite(file, "Cycle\tSTART\tI\tO\tSTATO\tMAR\tIN_R\tOUT_R\tROM_1\tROM_2\tROM_OR\n");
    $fwrite(file, "-----\t-----\t--\t-\t-----\t---\t----\t-----\t-----\t-----\t------\n");
    
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
        if (dut.STATO == 0 && START == 1) begin
            $display("Time=%0t: START detected at cycle %0d, entering init state", $time, i);
        end
        
        if (dut.STATO == 1) begin
            $display("Time=%0t: INIT at cycle %0d | I=%b (0x%02h)", $time, i, I, I);
        end
        
        if (dut.STATO == 2) begin
            $display("Time=%0t: LOOP at cycle %0d | MAR=%0d ROM_1=%b ROM_2=%b condition=%b OUT_R=%b", 
                     $time, i, dut.MAR, dut.ROM_1, dut.ROM_2, 
                     ((dut.ROM_2 & ~dut.IN_R) | (dut.ROM_1 & dut.IN_R) | (dut.ROM_2 & dut.ROM_1)),
                     dut.OUT_R);
        end
        
        // Display when output is generated
        if (dut.STATO == 3 && dut.MAR == 7 && START == 0) begin
            $display("Time=%0t: OUTPUT at cycle %0d | I=%b O=%b (IN_R=%b OUT_R=%b)", 
                     $time, i, I, O, dut.IN_R, dut.OUT_R);
        end
        
        // Display ROM OR operation when condition is met
        if (dut.STATO == 2 && ((dut.ROM_2 & ~dut.IN_R) | (dut.ROM_1 & dut.IN_R) | (dut.ROM_2 & dut.ROM_1)) == 8'b11111111) begin
            $display("Time=%0t: Cycle %0d ROM[%0d] matched! ROM_OR=%b accumulated to OUT_R=%b", 
                     $time, i, dut.MAR, dut.ROM_OR, dut.OUT_R | dut.ROM_OR);
        end
        
        // Periodic status display
        if (i % 5000 == 0 && i > 0) begin
            $display("Time=%0t: Progress - Cycle %0d | STATO=%0d MAR=%0d O=%b", 
                     $time, i, dut.STATO, dut.MAR, O);
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
    $display("=== b08 ROM Lookup Testbench ===");
    $display("Time\t\trst_n\tSTART\tI\tO\tSTATO\tMAR\tOUT_R");
    $display("----\t\t-----\t-----\t--\t-\t-----\t---\t-----");
    $monitor("%0t\t%b\t%b\t%h\t%h\t%0d\t%0d\t%b", 
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
    for (j=0; j<8; j=j+1) begin
        $dumpvars(0, dut.ROM[j]);
    end
end

// Statistics tracking (optional)
integer start_count;
integer state_start_st_count, state_init_count, state_loop_st_count, state_end_count;
integer rom_match_count;
integer output_generated_count;
integer total_calculations;
reg [7:0] rom_hit_count [0:7];
integer nonzero_output_count;
reg [3:0] prev_O;

initial begin
    start_count = 0;
    state_start_st_count = 0;
    state_init_count = 0;
    state_loop_st_count = 0;
    state_end_count = 0;
    rom_match_count = 0;
    output_generated_count = 0;
    total_calculations = 0;
    nonzero_output_count = 0;
    prev_O = 0;
    
    // Initialize ROM hit counters
    for (j=0; j<8; j=j+1) begin
        rom_hit_count[j] = 0;
    end
    
    // Wait for reset deassertion
    @(posedge rst_n);
    
    // Count statistics during simulation
    repeat(50000) begin
        @(posedge clk);
        
        // Count START assertions
        if (START) start_count = start_count + 1;
        
        // Count state visits
        case(dut.STATO)
            0: state_start_st_count = state_start_st_count + 1;
            1: state_init_count = state_init_count + 1;
            2: state_loop_st_count = state_loop_st_count + 1;
            3: state_end_count = state_end_count + 1;
        endcase
        
        // Count ROM matches
        if (dut.STATO == 2 && ((dut.ROM_2 & ~dut.IN_R) | (dut.ROM_1 & dut.IN_R) | (dut.ROM_2 & dut.ROM_1)) == 8'b11111111) begin
            rom_match_count = rom_match_count + 1;
            rom_hit_count[dut.MAR] = rom_hit_count[dut.MAR] + 1;
        end
        
        // Count calculations completed
        if (dut.STATO == 3 && dut.MAR == 7 && START == 0) begin
            total_calculations = total_calculations + 1;
        end
        
        // Count output generations
        if (O != prev_O) begin
            output_generated_count = output_generated_count + 1;
            if (O != 4'b0000) begin
                nonzero_output_count = nonzero_output_count + 1;
            end
            prev_O = O;
        end
    end
    
    // Display statistics
    #100;
    $display("\n=== Simulation Statistics ===");
    $display("\nInput Statistics:");
    $display("  START assertions: %0d", start_count);
    
    $display("\nState Visit Counts:");
    $display("  start_st (0): %0d", state_start_st_count);
    $display("  init (1):     %0d", state_init_count);
    $display("  loop_st (2):  %0d", state_loop_st_count);
    $display("  the_end (3):  %0d", state_end_count);
    
    $display("\nProcessing Statistics:");
    $display("  ROM matches (condition met): %0d", rom_match_count);
    $display("  Total calculations completed: %0d", total_calculations);
    $display("  Output changes: %0d", output_generated_count);
    $display("  Non-zero outputs: %0d", nonzero_output_count);
    
    $display("\nROM Hit Distribution:");
    for (j=0; j<8; j=j+1) begin
        $display("  ROM[%0d] hits: %0d", j, rom_hit_count[j]);
    end
    
    $display("\nFinal State:");
    $display("  STATO: %0d", dut.STATO);
    $display("  MAR: %0d", dut.MAR);
    $display("  IN_R: %b (0x%02h)", dut.IN_R, dut.IN_R);
    $display("  OUT_R: %b", dut.OUT_R);
    $display("  O: %b", O);
end

// ROM content display
initial begin
    #100;  // Wait for initialization
    $display("\n=== ROM Contents ===");
    for (j=0; j<8; j=j+1) begin
        $display("ROM[%0d] = %b (ROM_1=%b ROM_2=%b ROM_OR=%b)", 
                 j, dut.ROM[j], dut.ROM[j][19:12], dut.ROM[j][11:4], dut.ROM[j][3:0]);
    end
end

// Detailed calculation tracker
integer calc_id;
reg [7:0] calc_input;
reg [3:0] calc_output;

initial begin
    calc_id = 0;
    
    @(posedge rst_n);
    
    forever begin
        @(posedge clk);
        // Detect calculation start
        if (dut.STATO == 1) begin
            calc_id = calc_id + 1;
            calc_input = I;
            $display("\n=== Calculation #%0d Started at time %0t ===", calc_id, $time);
            $display("  Input I = %b (0x%02h)", calc_input, calc_input);
        end
        
        // Detect calculation complete
        if (dut.STATO == 3 && dut.MAR == 7 && START == 0) begin
            calc_output = dut.OUT_R;
            $display("=== Calculation #%0d Complete at time %0t ===", calc_id, $time);
            $display("  Input:  %b (0x%02h)", dut.IN_R, dut.IN_R);
            $display("  Output: %b", calc_output);
            $display("  ROM matches in this calculation:");
            // This is logged during the loop iterations above
        end
    end
end

// Input pattern analysis
integer input_ff_count, input_00_count;

initial begin
    input_ff_count = 0;
    input_00_count = 0;
    
    @(posedge rst_n);
    
    repeat(50000) begin
        @(posedge clk);
        if (I == 8'hFF) input_ff_count = input_ff_count + 1;
        if (I == 8'h00) input_00_count = input_00_count + 1;
    end
    
    #100;
    $display("\nInput Pattern Statistics:");
    $display("  I = 0xFF count: %0d", input_ff_count);
    $display("  I = 0x00 count: %0d", input_00_count);
end

endmodule