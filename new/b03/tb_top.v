`timescale 1ns / 1ps

module tb_top;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg request1;
reg request2;
reg request3;
reg request4;

// Output signals
wire [3:0] grant_o;

// Loop counter
integer i;

// File for logging (optional)
integer file;

// Instantiate the DUT (Device Under Test)
b03 dut (
    .clock(clk),
    .reset(~rst_n),  // rst_n is active low, but b03 expects active high reset
    .request1(request1),
    .request2(request2),
    .request3(request3),
    .request4(request4),
    .grant_o(grant_o)
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
    request1 = 0;
    request2 = 0;
    request3 = 0;
    request4 = 0;
    
    // Open file for logging (optional - comment out if not needed)
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\treq1\treq2\treq3\treq4\tgrant_o\tstato\tcoda0\tcoda1\tcoda2\tcoda3\tru1\tru2\tru3\tru4\tfu1\tfu2\tfu3\tfu4\tgrant\n");
    $fwrite(file, "-----\t----\t----\t----\t----\t-------\t-----\t-----\t-----\t-----\t-----\t---\t---\t---\t---\t---\t---\t---\t---\t-----\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation with random inputs ===\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        // Random input generation
        request1 <= $random;
        request2 <= $random;
        request3 <= $random;
        request4 <= $random;
        
        // Log internal signals to file
        if (file) begin
            $fwrite(file, "%0d\t%b\t%b\t%b\t%b\t%b\t%0d\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t%b\n", 
                    i, request1, request2, request3, request4, grant_o, 
                    dut.stato, dut.coda0, dut.coda1, dut.coda2, dut.coda3,
                    dut.ru1, dut.ru2, dut.ru3, dut.ru4,
                    dut.fu1, dut.fu2, dut.fu3, dut.fu4, dut.grant);
        end
        
        // Display grant events
        if (grant_o != 4'b0000) begin
            $display("Time=%0t: GRANT at cycle %0d | grant_o=%b (req1=%b req2=%b req3=%b req4=%b) stato=%0d coda0=%b", 
                     $time, i, grant_o, request1, request2, request3, request4, dut.stato, dut.coda0);
        end
        
        // Display queue state when non-empty
        if (dut.coda0 != 3'b000 || dut.coda1 != 3'b000 || dut.coda2 != 3'b000 || dut.coda3 != 3'b000) begin
            if (i % 1000 == 0) begin  // Print every 1000 cycles to avoid too much output
                $display("Time=%0t: Cycle %0d Queue state: [%b %b %b %b]", 
                         $time, i, dut.coda0, dut.coda1, dut.coda2, dut.coda3);
            end
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
    $display("=== b03 Arbiter Testbench ===");
    $display("Time\t\trst_n\treq1\treq2\treq3\treq4\tgrant_o\tstato\tcoda0");
    $display("----\t\t-----\t----\t----\t----\t----\t-------\t-----\t-----");
    $monitor("%0t\t%b\t%b\t%b\t%b\t%b\t%b\t%0d\t%b", 
             $time, rst_n, request1, request2, request3, request4, grant_o, dut.stato, dut.coda0);
end

// Generate VCD file for waveform viewing (optional)
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    // Explicitly dump all internal signals
    $dumpvars(0, dut.stato);
    $dumpvars(0, dut.coda0);
    $dumpvars(0, dut.coda1);
    $dumpvars(0, dut.coda2);
    $dumpvars(0, dut.coda3);
    $dumpvars(0, dut.grant);
    $dumpvars(0, dut.ru1);
    $dumpvars(0, dut.ru2);
    $dumpvars(0, dut.ru3);
    $dumpvars(0, dut.ru4);
    $dumpvars(0, dut.fu1);
    $dumpvars(0, dut.fu2);
    $dumpvars(0, dut.fu3);
    $dumpvars(0, dut.fu4);
end

// Statistics tracking (optional)
integer grant1_count, grant2_count, grant3_count, grant4_count;
integer request1_count, request2_count, request3_count, request4_count;
integer state_init_count, state_analisi_count, state_assign_count;
integer queue_full_count;
integer total_grants;

initial begin
    grant1_count = 0;
    grant2_count = 0;
    grant3_count = 0;
    grant4_count = 0;
    request1_count = 0;
    request2_count = 0;
    request3_count = 0;
    request4_count = 0;
    state_init_count = 0;
    state_analisi_count = 0;
    state_assign_count = 0;
    queue_full_count = 0;
    total_grants = 0;
    
    // Wait for reset deassertion
    @(posedge rst_n);
    
    // Count statistics during simulation
    repeat(50000) begin
        @(posedge clk);
        
        // Count requests
        if (request1) request1_count = request1_count + 1;
        if (request2) request2_count = request2_count + 1;
        if (request3) request3_count = request3_count + 1;
        if (request4) request4_count = request4_count + 1;
        
        // Count grants
        if (grant_o == 4'b1000) begin
            grant1_count = grant1_count + 1;
            total_grants = total_grants + 1;
        end
        if (grant_o == 4'b0100) begin
            grant2_count = grant2_count + 1;
            total_grants = total_grants + 1;
        end
        if (grant_o == 4'b0010) begin
            grant3_count = grant3_count + 1;
            total_grants = total_grants + 1;
        end
        if (grant_o == 4'b0001) begin
            grant4_count = grant4_count + 1;
            total_grants = total_grants + 1;
        end
        
        // Count state visits
        case(dut.stato)
            0: state_init_count = state_init_count + 1;
            1: state_analisi_count = state_analisi_count + 1;
            2: state_assign_count = state_assign_count + 1;
        endcase
        
        // Check if queue is full
        if (dut.coda0 != 3'b000 && dut.coda1 != 3'b000 && 
            dut.coda2 != 3'b000 && dut.coda3 != 3'b000) begin
            queue_full_count = queue_full_count + 1;
        end
    end
    
    // Display statistics
    #100;
    $display("\n=== Simulation Statistics ===");
    $display("\nRequest Counts:");
    $display("  request1: %0d", request1_count);
    $display("  request2: %0d", request2_count);
    $display("  request3: %0d", request3_count);
    $display("  request4: %0d", request4_count);
    $display("  Total requests: %0d", request1_count + request2_count + request3_count + request4_count);
    
    $display("\nGrant Counts:");
    $display("  grant1 (1000): %0d", grant1_count);
    $display("  grant2 (0100): %0d", grant2_count);
    $display("  grant3 (0010): %0d", grant3_count);
    $display("  grant4 (0001): %0d", grant4_count);
    $display("  Total grants: %0d", total_grants);
    
    $display("\nState Visit Counts:");
    $display("  INIT (0):        %0d", state_init_count);
    $display("  ANALISI_REQ (1): %0d", state_analisi_count);
    $display("  ASSIGN (2):      %0d", state_assign_count);
    
    $display("\nQueue Statistics:");
    $display("  Queue full cycles: %0d", queue_full_count);
    
    if (request1_count + request2_count + request3_count + request4_count > 0) begin
        $display("\nArbiter Efficiency:");
        $display("  Grant rate: %0.2f%%", 
                 (total_grants * 100.0) / (request1_count + request2_count + request3_count + request4_count));
    end
end

endmodule