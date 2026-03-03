`timescale 1ns / 1ps

module tb_top;

// State parameters (must match b14 and b14rev)
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

// Input signals for b20
reg [31:0] si;

// Output signals from b20
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
b20 dut (
    .clock(clk),
    .reset(~rst_n),  // rst_n is active low, but b20 expects active high reset
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
    $fwrite(file, "Cycle\tsi\t\tso\t\trd\twr\taddr_1\t\taddr_2\t\trd_1\trd_2\twr_1\twr_2\tstate_1\tstate_2\treg3_1\t\treg3_2\t\tB_1\tB_2\n");
    $fwrite(file, "-----\t--------\t-----\t\t--\t--\t-----\t\t-----\t\t----\t----\t----\t----\t-------\t-------\t--------\t--------\t---\t---\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation for b20 with random inputs ===\n");
    
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
        
        // Log to file
        if (file) begin
            $fwrite(file, "%0d\t%h\t%h\t%b\t%b\t%h\t%h\t%b\t%b\t%b\t%b\t%0d\t%0d\t%h\t%h\t%b\t%b\n",
                    i, si, so, rd, wr,
                    dut.addr_1, dut.addr_2,
                    dut.rd_1, dut.rd_2,
                    dut.wr_1, dut.wr_2,
                    dut.P1.state, dut.P2.state,
                    dut.P1.reg3, dut.P2.reg3,
                    dut.P1.B, dut.P2.B);
        end
        
        // Display P1 (b14) state transitions
        if (dut.P1.state == FETCH) begin
            if (i < 100 || i % 5000 == 0) begin
                $display("Time=%0t: Cycle %0d - P1 FETCH | MAR=%0d datai_1=%h rd_1=%b", 
                         $time, i, dut.P1.MAR, dut.datai_1, dut.rd_1);
            end
        end
        
        if (dut.P1.state == EXEC) begin
            if (i < 100 || i % 5000 == 0) begin
                $display("Time=%0t: Cycle %0d - P1 EXEC | IR=%h mf=%0d df=%0d ff=%0d cf=%0d", 
                         $time, i, dut.P1.IR, dut.P1.mf, dut.P1.df, dut.P1.ff, dut.P1.cf);
            end
        end
        
        // Display P2 (b14rev) state transitions
        if (dut.P2.state == FETCH) begin
            if (i < 100 || i % 5000 == 0) begin
                $display("Time=%0t: Cycle %0d - P2 FETCH | MAR=%0d datai_2=%h rd_2=%b", 
                         $time, i, dut.P2.MAR, dut.datai_2, dut.rd_2);
            end
        end
        
        if (dut.P2.state == EXEC) begin
            if (i < 100 || i % 5000 == 0) begin
                $display("Time=%0t: Cycle %0d - P2 EXEC | IR=%h mf=%0d df=%0d ff=%0d cf=%0d", 
                         $time, i, dut.P2.IR, dut.P2.mf, dut.P2.df, dut.P2.ff, dut.P2.cf);
            end
        end
        
        // Display combined outputs
        if (i % 1000 == 0) begin
            $display("\nTime=%0t: Cycle %0d | si=%h so=%h rd=%b wr=%b", 
                     $time, i, si, so, rd, wr);
            $display("  P1: state=%0d addr=%h reg3=%h B=%b", 
                     dut.P1.state, dut.addr_1, dut.P1.reg3, dut.P1.B);
            $display("  P2: state=%0d addr=%h reg3=%h B=%b", 
                     dut.P2.state, dut.addr_2, dut.P2.reg3, dut.P2.B);
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
    $display("=== b20 Circuit Testbench ===");
    $display("Time\t\trst_n\tsi\t\tso\t\trd\twr\taddr_1\t\taddr_2\t\tstate_1\tstate_2");
    $display("----\t\t-----\t--------\t-----\t\t--\t--\t-----\t\t-----\t\t-------\t-------");
    $monitor("%0t\t%b\t%h\t%h\t%b\t%b\t%h\t%h\t%0d\t%0d",
             $time, rst_n, si, so, rd, wr, dut.addr_1, dut.addr_2, dut.P1.state, dut.P2.state);
end

// Generate VCD file for waveform viewing
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    
    // Dump top-level DUT signals
    $dumpvars(0, dut.addr_1);
    $dumpvars(0, dut.addr_2);
    $dumpvars(0, dut.datai_1);
    $dumpvars(0, dut.datai_2);
    $dumpvars(0, dut.datao_1);
    $dumpvars(0, dut.datao_2);
    $dumpvars(0, dut.rd_1);
    $dumpvars(0, dut.rd_2);
    $dumpvars(0, dut.wr_1);
    $dumpvars(0, dut.wr_2);
    
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
    
    // Dump P2 (b14rev) signals
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
            $display("  addr_1=%h addr_2=%h", dut.addr_1, dut.addr_2);
            $display("  datai_1=%h datai_2=%h", dut.datai_1, dut.datai_2);
            $display("  datao_1=%h datao_2=%h", dut.datao_1, dut.datao_2);
            $display("  rd_1=%b rd_2=%b wr_1=%b wr_2=%b", dut.rd_1, dut.rd_2, dut.wr_1, dut.wr_2);
            $display("P1 (b14) signals:");
            $display("  state=%0d IR=%h", dut.P1.state, dut.P1.IR);
            $display("  reg0=%h reg1=%h reg2=%h reg3=%h", 
                     dut.P1.reg0, dut.P1.reg1, dut.P1.reg2, dut.P1.reg3);
            $display("  mf=%0d df=%0d ff=%0d cf=%0d B=%b", 
                     dut.P1.mf, dut.P1.df, dut.P1.ff, dut.P1.cf, dut.P1.B);
            $display("  r=%h m=%h", dut.P1.r, dut.P1.m);
            $display("P2 (b14rev) signals:");
            $display("  state=%0d IR=%h", dut.P2.state, dut.P2.IR);
            $display("  reg0=%h reg1=%h reg2=%h reg3=%h", 
                     dut.P2.reg0, dut.P2.reg1, dut.P2.reg2, dut.P2.reg3);
            $display("  mf=%0d df=%0d ff=%0d cf=%0d B=%b", 
                     dut.P2.mf, dut.P2.df, dut.P2.ff, dut.P2.cf, dut.P2.B);
            $display("  r=%h m=%h", dut.P2.r, dut.P2.m);
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
                $display("Time=%0t: Cycle %0d - rd changed: %b -> %b (rd_1=%b rd_2=%b)", 
                         $time, i, prev_rd, rd, dut.rd_1, dut.rd_2);
            end
            prev_rd = rd;
        end
        
        if (wr != prev_wr) begin
            wr_transitions = wr_transitions + 1;
            if (wr_transitions < 50) begin  // Display first 50 transitions
                $display("Time=%0t: Cycle %0d - wr changed: %b -> %b (wr_1=%b wr_2=%b)", 
                         $time, i, prev_wr, wr, dut.wr_1, dut.wr_2);
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
                $display("Time=%0t: so changed: %h -> %h (addr_1=%h addr_2=%h)", 
                         $time, prev_so, so, dut.addr_1, dut.addr_2);
            end
            prev_so = so;
        end
    end
    
    #100;
    $display("Total so changes: %0d", so_changes);
end

// Track P1 register modifications
reg [31:0] prev_p1_reg0, prev_p1_reg1, prev_p1_reg2, prev_p1_reg3;

initial begin
    @(posedge rst_n);
    prev_p1_reg0 = 0;
    prev_p1_reg1 = 0;
    prev_p1_reg2 = 0;
    prev_p1_reg3 = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.P1.reg0 != prev_p1_reg0 && i < 200) begin
            $display("Time=%0t: P1.reg0 changed: %h -> %h", $time, prev_p1_reg0, dut.P1.reg0);
            prev_p1_reg0 = dut.P1.reg0;
        end
        if (dut.P1.reg1 != prev_p1_reg1 && i < 200) begin
            $display("Time=%0t: P1.reg1 changed: %h -> %h", $time, prev_p1_reg1, dut.P1.reg1);
            prev_p1_reg1 = dut.P1.reg1;
        end
        if (dut.P1.reg2 != prev_p1_reg2 && i < 200) begin
            $display("Time=%0t: P1.reg2 changed: %h -> %h", $time, prev_p1_reg2, dut.P1.reg2);
            prev_p1_reg2 = dut.P1.reg2;
        end
        if (dut.P1.reg3 != prev_p1_reg3 && i < 200) begin
            $display("Time=%0t: P1.reg3 changed: %h -> %h", $time, prev_p1_reg3, dut.P1.reg3);
            prev_p1_reg3 = dut.P1.reg3;
        end
    end
end

// Track P2 register modifications
reg [31:0] prev_p2_reg0, prev_p2_reg1, prev_p2_reg2, prev_p2_reg3;

initial begin
    @(posedge rst_n);
    prev_p2_reg0 = 0;
    prev_p2_reg1 = 0;
    prev_p2_reg2 = 0;
    prev_p2_reg3 = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.P2.reg0 != prev_p2_reg0 && i < 200) begin
            $display("Time=%0t: P2.reg0 changed: %h -> %h", $time, prev_p2_reg0, dut.P2.reg0);
            prev_p2_reg0 = dut.P2.reg0;
        end
        if (dut.P2.reg1 != prev_p2_reg1 && i < 200) begin
            $display("Time=%0t: P2.reg1 changed: %h -> %h", $time, prev_p2_reg1, dut.P2.reg1);
            prev_p2_reg1 = dut.P2.reg1;
        end
        if (dut.P2.reg2 != prev_p2_reg2 && i < 200) begin
            $display("Time=%0t: P2.reg2 changed: %h -> %h", $time, prev_p2_reg2, dut.P2.reg2);
            prev_p2_reg2 = dut.P2.reg2;
        end
        if (dut.P2.reg3 != prev_p2_reg3 && i < 200) begin
            $display("Time=%0t: P2.reg3 changed: %h -> %h", $time, prev_p2_reg3, dut.P2.reg3);
            prev_p2_reg3 = dut.P2.reg3;
        end
    end
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
    $display("P2 (b14rev):");
    $display("  FETCH cycles: %0d", fetch_count_p2);
    $display("  EXEC cycles: %0d", exec_count_p2);
end

// Coverage checker
integer max_so, min_so;
integer max_addr1, min_addr1;
integer max_addr2, min_addr2;
reg [31:0] max_datao1, min_datao1;
reg [31:0] max_datao2, min_datao2;

initial begin
    @(posedge rst_n);
    max_so = 0; min_so = 20'hFFFFF;
    max_addr1 = 0; min_addr1 = 20'hFFFFF;
    max_addr2 = 0; min_addr2 = 20'hFFFFF;
    max_datao1 = 0; min_datao1 = 32'hFFFFFFFF;
    max_datao2 = 0; min_datao2 = 32'hFFFFFFFF;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (so > max_so) max_so = so;
        if (so < min_so) min_so = so;
        
        if (dut.addr_1 > max_addr1) max_addr1 = dut.addr_1;
        if (dut.addr_1 < min_addr1) min_addr1 = dut.addr_1;
        
        if (dut.addr_2 > max_addr2) max_addr2 = dut.addr_2;
        if (dut.addr_2 < min_addr2) min_addr2 = dut.addr_2;
        
        if (dut.datao_1 > max_datao1) max_datao1 = dut.datao_1;
        if (dut.datao_1 < min_datao1) min_datao1 = dut.datao_1;
        
        if (dut.datao_2 > max_datao2) max_datao2 = dut.datao_2;
        if (dut.datao_2 < min_datao2) min_datao2 = dut.datao_2;
    end
    
    #100;
    $display("\n=== Coverage Summary ===");
    $display("so range: %h to %h (%0d to %0d)", min_so, max_so, min_so, max_so);
    $display("addr_1 range: %h to %h (%0d to %0d)", min_addr1, max_addr1, min_addr1, max_addr1);
    $display("addr_2 range: %h to %h (%0d to %0d)", min_addr2, max_addr2, min_addr2, max_addr2);
    $display("datao_1 range: %h to %h", min_datao1, max_datao1);
    $display("datao_2 range: %h to %h", min_datao2, max_datao2);
end

// Targeted tests for address conditions
initial begin
    @(posedge rst_n);
    #1000;
    
    $display("\n=== Running targeted tests for address-based conditions ===");
    
    // Test condition: addr_1 < 2^19 && addr_2 < 2^19
    repeat(100) begin
        @(posedge clk);
        si = 32'h00000100;
    end
    
    // Test condition: addr_1 > 2^19-1 && addr_2 > 2^19-1
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

endmodule
