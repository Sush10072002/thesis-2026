`timescale 1ns / 1ps

module tb_top;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg start;

// Output signals
wire [7:0] punti_retta;

// Loop counter
integer i;

// File for logging (optional)
integer file;

// Instantiate the DUT (Device Under Test)
b07 dut (
    .clock(clk),
    .reset(~rst_n),  // rst_n is active low, but b07 expects active high reset
    .start(start),
    .punti_retta(punti_retta)
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
    start = 0;
    
    // Open file for logging (optional - comment out if not needed)
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\tstart\tpunti_retta\tstato\tmar\tcont\tx\ty\tt\n");
    $fwrite(file, "-----\t-----\t-----------\t-----\t---\t----\t-\t-\t-\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation with random start input ===\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        // Random input generation for start signal
        start <= $random;
        
        // Log internal signals to file
        if (file) begin
            $fwrite(file, "%0d\t%b\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\n", 
                    i, start, punti_retta, dut.stato, dut.mar, dut.cont, 
                    dut.x, dut.y, dut.t);
        end
        
        // Display state transitions
        if (dut.stato == 1 && start == 1) begin
            $display("Time=%0t: START detected at cycle %0d, beginning calculation", $time, i);
        end
        
        if (dut.stato == 6 && dut.mar == 15) begin
            $display("Time=%0t: Reached end of memory at cycle %0d | mar=%0d cont=%0d x=%0d", 
                     $time, i, dut.mar, dut.cont, dut.x);
        end
        
        // Display when punti_retta output changes (result ready)
        if (punti_retta != 0 && dut.stato == 1) begin
            $display("Time=%0t: OUTPUT at cycle %0d | punti_retta=%0d", 
                     $time, i, punti_retta);
        end
        
        // Display when a point on the line is detected (x == 2)
        if (dut.stato == 6 && dut.x == 2) begin
            $display("Time=%0t: Point detected at cycle %0d | x=%0d cont=%0d mar=%0d", 
                     $time, i, dut.x, dut.cont, dut.mar);
        end
        
        // Periodic status display
        if (i % 5000 == 0 && i > 0) begin
            $display("Time=%0t: Progress - Cycle %0d | stato=%0d mar=%0d cont=%0d punti_retta=%0d", 
                     $time, i, dut.stato, dut.mar, dut.cont, punti_retta);
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
    $display("=== b07 Line Point Counter Testbench ===");
    $display("Time\t\trst_n\tstart\tstato\tmar\tcont\tx\ty\tpunti_retta");
    $display("----\t\t-----\t-----\t-----\t---\t----\t-\t-\t-----------");
    $monitor("%0t\t%b\t%b\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d", 
             $time, rst_n, start, dut.stato, dut.mar, dut.cont, 
             dut.x, dut.y, punti_retta);
end

// Generate VCD file for waveform viewing (optional)
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    // Explicitly dump all internal signals
    $dumpvars(0, dut.stato);
    $dumpvars(0, dut.cont);
    $dumpvars(0, dut.x);
    $dumpvars(0, dut.y);
    $dumpvars(0, dut.t);
    $dumpvars(0, dut.mar);
    // Dump memory array
    for (i=0; i<16; i=i+1) begin
        $dumpvars(0, dut.mem[i]);
    end
end

// Statistics tracking (optional)
integer start_count;
integer state_reset_count, state_start_count, state_load_x_count;
integer state_update_mar_count, state_load_y_count, state_calc_retta_count;
integer state_incrementa_count;
integer point_detected_count;
integer calculation_complete_count;
integer final_punti_retta;
integer max_cont_value;

initial begin
    start_count = 0;
    state_reset_count = 0;
    state_start_count = 0;
    state_load_x_count = 0;
    state_update_mar_count = 0;
    state_load_y_count = 0;
    state_calc_retta_count = 0;
    state_incrementa_count = 0;
    point_detected_count = 0;
    calculation_complete_count = 0;
    final_punti_retta = 0;
    max_cont_value = 0;
    
    // Wait for reset deassertion
    @(posedge rst_n);
    
    // Count statistics during simulation
    repeat(50000) begin
        @(posedge clk);
        
        // Count start assertions
        if (start) start_count = start_count + 1;
        
        // Count state visits
        case(dut.stato)
            0: state_reset_count = state_reset_count + 1;
            1: state_start_count = state_start_count + 1;
            2: state_load_x_count = state_load_x_count + 1;
            3: state_update_mar_count = state_update_mar_count + 1;
            4: state_load_y_count = state_load_y_count + 1;
            5: state_calc_retta_count = state_calc_retta_count + 1;
            6: state_incrementa_count = state_incrementa_count + 1;
        endcase
        
        // Count point detections (when x == 2)
        if (dut.stato == 6 && dut.x == 2) begin
            point_detected_count = point_detected_count + 1;
        end
        
        // Count calculation completions
        if (dut.stato == 6 && dut.mar == 15 && start == 0) begin
            calculation_complete_count = calculation_complete_count + 1;
            final_punti_retta = punti_retta;
        end
        
        // Track max cont value
        if (dut.cont > max_cont_value) begin
            max_cont_value = dut.cont;
        end
    end
    
    // Display statistics
    #100;
    $display("\n=== Simulation Statistics ===");
    $display("\nInput Statistics:");
    $display("  start assertions: %0d", start_count);
    
    $display("\nState Visit Counts:");
    $display("  S_RESET (0):      %0d", state_reset_count);
    $display("  S_START (1):      %0d", state_start_count);
    $display("  S_LOAD_X (2):     %0d", state_load_x_count);
    $display("  S_UPDATE_MAR (3): %0d", state_update_mar_count);
    $display("  S_LOAD_Y (4):     %0d", state_load_y_count);
    $display("  S_CALC_RETTA (5): %0d", state_calc_retta_count);
    $display("  S_INCREMENTA (6): %0d", state_incrementa_count);
    
    $display("\nProcessing Statistics:");
    $display("  Points detected (x==2): %0d", point_detected_count);
    $display("  Calculations completed: %0d", calculation_complete_count);
    $display("  Max cont value: %0d", max_cont_value);
    
    $display("\nFinal Results:");
    $display("  Final punti_retta: %0d", final_punti_retta);
    $display("  Current stato: %0d", dut.stato);
    $display("  Current mar: %0d", dut.mar);
    $display("  Current cont: %0d", dut.cont);
    $display("  Current x: %0d", dut.x);
    $display("  Current y: %0d", dut.y);
    
    $display("\nMemory Contents:");
    for (i=0; i<16; i=i+1) begin
        $display("  mem[%2d] = %3d (0x%02h)", i, dut.mem[i], dut.mem[i]);
    end
end

// Calculation sequence tracker
integer calc_sequence_count;
reg [7:0] prev_punti_retta;

initial begin
    calc_sequence_count = 0;
    prev_punti_retta = 0;
    
    @(posedge rst_n);
    
    forever begin
        @(posedge clk);
        // Detect when a new calculation sequence starts
        if (dut.stato == 2 && start == 1) begin
            calc_sequence_count = calc_sequence_count + 1;
            $display("\n--- Calculation Sequence #%0d started at time %0t ---", 
                     calc_sequence_count, $time);
        end
        
        // Detect when output changes
        if (punti_retta != prev_punti_retta) begin
            $display("Output changed from %0d to %0d at time %0t", 
                     prev_punti_retta, punti_retta, $time);
            prev_punti_retta = punti_retta;
        end
    end
end

// Memory content verification
initial begin
    #100;  // Wait for initialization
    $display("\n=== Initial Memory Verification ===");
    $display("Expected memory pattern loaded:");
    for (i=0; i<16; i=i+1) begin
        $display("  mem[%2d] = %3d", i, dut.mem[i]);
    end
end

endmodule