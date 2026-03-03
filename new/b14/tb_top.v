`timescale 1ns / 1ps

module tb_top;

// State parameters (must match b14.v)
parameter FETCH = 0;
parameter EXEC = 1;

// Value parameters (must match b14.v)
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

// Input signals
reg [31:0] datai;

// Output signals
wire [19:0] addr;
wire [31:0] datao;
wire rd;
wire wr;

// Loop counter
integer i;

// File for logging (optional)
integer file;

// Instantiate the DUT (Device Under Test)
b14 dut (
    .clock(clk),
    .reset(~rst_n),  // rst_n is active low, but b14 expects active high reset
    .datai(datai),
    .addr(addr),
    .datao(datao),
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
    datai = 32'h00000000;
    
    // Open file for logging (optional - comment out if not needed)
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\tdatai\t\taddr\t\tdatao\t\trd\twr\tstate\tIR\t\tMAR\tMBR\t\treg0\t\treg1\t\treg2\t\treg3\t\tB\tmf\tdf\tff\tcf\ttail\ts\tr\t\tm\t\td\tt\t\ttemp\n");
    $fwrite(file, "-----\t--------\t-----\t\t--------\t--\t--\t-----\t--------\t---\t--------\t--------\t--------\t--------\t--------\t-\t--\t--\t--\t--\t-----\t-\t--------\t--------\t-\t--------\t--------\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation with random input ===\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        // Random input generation
        datai <= $random;
        
        // Log internal signals to file
        if (file) begin
            $fwrite(file, "%0d\t%h\t%h\t%h\t%b\t%b\t%0d\t%h\t%0d\t%h\t%h\t%h\t%h\t%h\t%b\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\t%h\t%h\t%0d\t%h\t%h\n", 
                    i, datai, addr, datao, rd, wr, dut.state, dut.IR, dut.MAR, dut.MBR,
                    dut.reg0, dut.reg1, dut.reg2, dut.reg3, dut.B,
                    dut.mf, dut.df, dut.ff, dut.cf, dut.tail, dut.s,
                    dut.r, dut.m, dut.d, dut.t, dut.temp);
        end
        
        // Display state transitions
        if (dut.state == FETCH) begin
            $display("Time=%0t: Cycle %0d - FETCH | MAR=%0d datai=%h rd=%b", 
                     $time, i, dut.MAR, datai, rd);
        end
        
        if (dut.state == EXEC) begin
            $display("Time=%0t: Cycle %0d - EXEC | IR=%h mf=%0d df=%0d ff=%0d cf=%0d tail=%0d", 
                     $time, i, dut.IR, dut.mf, dut.df, dut.ff, dut.cf, dut.tail);
        end
        
        // Display register updates
        if (i > 0 && (dut.reg0 != 0 || dut.reg1 != 0 || dut.reg2 != 0)) begin
            $display("Time=%0t: Cycle %0d - Registers | reg0=%h reg1=%h reg2=%h reg3=%h", 
                     $time, i, dut.reg0, dut.reg1, dut.reg2, dut.reg3);
        end
        
        // Display memory operations
        if (rd == 1) begin
            $display("Time=%0t: Cycle %0d - READ | addr=%h datai=%h", 
                     $time, i, addr, datai);
        end
        
        if (wr == 1) begin
            $display("Time=%0t: Cycle %0d - WRITE | addr=%h datao=%h", 
                     $time, i, addr, datao);
        end
        
        // Display B flag changes
        if (dut.B == 1) begin
            $display("Time=%0t: Cycle %0d - B flag SET | r=%h m=%h ff=%0d", 
                     $time, i, dut.r, dut.m, dut.ff);
        end
        
        // Display calculation progress every 1000 cycles
        if (i % 1000 == 0) begin
            $display("Time=%0t: Cycle %0d | state=%0d IR=%h reg0=%h reg1=%h reg2=%h reg3=%h B=%b", 
                     $time, i, dut.state, dut.IR, dut.reg0, dut.reg1, dut.reg2, dut.reg3, dut.B);
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
    $display("=== b14 Processor Testbench ===");
    $display("Time\t\trst_n\tstate\taddr\t\trd\twr\tIR\t\treg3\t\tB");
    $display("----\t\t-----\t-----\t-----\t\t--\t--\t--------\t--------\t-");
    $monitor("%0t\t%b\t%0d\t%h\t%b\t%b\t%h\t%h\t%b", 
             $time, rst_n, dut.state, addr, rd, wr, dut.IR, dut.reg3, dut.B);
end

// Generate VCD file for waveform viewing (optional)
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    // Explicitly dump all internal signals
    $dumpvars(0, dut.state);
    $dumpvars(0, dut.reg0);
    $dumpvars(0, dut.reg1);
    $dumpvars(0, dut.reg2);
    $dumpvars(0, dut.reg3);
    $dumpvars(0, dut.B);
    $dumpvars(0, dut.MAR);
    $dumpvars(0, dut.MBR);
    $dumpvars(0, dut.mf);
    $dumpvars(0, dut.df);
    $dumpvars(0, dut.cf);
    $dumpvars(0, dut.ff);
    $dumpvars(0, dut.tail);
    $dumpvars(0, dut.IR);
    $dumpvars(0, dut.r);
    $dumpvars(0, dut.m);
    $dumpvars(0, dut.d);
    $dumpvars(0, dut.t);
    $dumpvars(0, dut.temp);
    $dumpvars(0, dut.s);
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

// Additional detailed logging every 100 cycles
initial begin
    @(posedge rst_n);
    
    for (i=0; i<500; i=i+1) begin
        @(posedge clk);
        if (i % 100 == 0) begin
            $display("\n--- Cycle %0d Snapshot ---", i);
            $display("State: %0s (%0d)", state_name(dut.state), dut.state);
            $display("Input: datai=%h", datai);
            $display("Outputs: addr=%h datao=%h rd=%b wr=%b", addr, datao, rd, wr);
            $display("Instruction: IR=%h (signed=%0d)", dut.IR, $signed(dut.IR));
            $display("  mf=%0d df=%0d ff=%0d cf=%0d tail=%0d s=%0d", 
                     dut.mf, dut.df, dut.ff, dut.cf, dut.tail, dut.s);
            $display("Registers:");
            $display("  reg0=%h (%0d)", dut.reg0, dut.reg0);
            $display("  reg1=%h (%0d)", dut.reg1, dut.reg1);
            $display("  reg2=%h (%0d)", dut.reg2, dut.reg2);
            $display("  reg3=%h (%0d)", dut.reg3, dut.reg3);
            $display("Memory registers: MAR=%h MBR=%h", dut.MAR, dut.MBR);
            $display("Arithmetic: r=%h m=%h d=%0d t=%h temp=%h", 
                     dut.r, dut.m, dut.d, dut.t, dut.temp);
            $display("Flag: B=%b", dut.B);
            
            // State-specific information
            if (dut.state == EXEC) begin
                $display("EXEC State Details:");
                $display("  Source register (s=%0d): r=%h", dut.s, dut.r);
                $display("  Memory mode (mf=%0d): m=%h", dut.mf, dut.m);
                $display("  Destination (d=%0d)", dut.d);
                $display("  Function (ff=%0d)", dut.ff);
                $display("  Condition (cf=%0d)", dut.cf);
            end
        end
    end
end

// Track memory operations
integer read_count, write_count;
reg [19:0] last_read_addr, last_write_addr;
reg [31:0] last_read_data, last_write_data;

initial begin
    @(posedge rst_n);
    read_count = 0;
    write_count = 0;
    last_read_addr = 0;
    last_write_addr = 0;
    last_read_data = 0;
    last_write_data = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        // Track reads
        if (rd == 1) begin
            read_count = read_count + 1;
            last_read_addr = addr;
            last_read_data = datai;
            $display("Time=%0t: READ #%0d | addr=%h data=%h", $time, read_count, addr, datai);
        end
        
        // Track writes
        if (wr == 1) begin
            write_count = write_count + 1;
            last_write_addr = addr;
            last_write_data = datao;
            $display("Time=%0t: WRITE #%0d | addr=%h data=%h", $time, write_count, addr, datao);
        end
    end
    
    #100;
    $display("\n=== Memory Operations Summary ===");
    $display("Total reads: %0d", read_count);
    $display("Total writes: %0d", write_count);
    $display("Last read: addr=%h data=%h", last_read_addr, last_read_data);
    $display("Last write: addr=%h data=%h", last_write_addr, last_write_data);
end

// Track instruction execution patterns
integer fetch_count, exec_count;

initial begin
    @(posedge rst_n);
    fetch_count = 0;
    exec_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.state == FETCH) fetch_count = fetch_count + 1;
        if (dut.state == EXEC) exec_count = exec_count + 1;
    end
    
    #100;
    $display("\n=== Instruction Cycle Summary ===");
    $display("FETCH cycles: %0d", fetch_count);
    $display("EXEC cycles: %0d", exec_count);
    $display("Total instructions: ~%0d", fetch_count);
end

// Track register modifications
reg [31:0] prev_reg0, prev_reg1, prev_reg2, prev_reg3;

initial begin
    @(posedge rst_n);
    prev_reg0 = 0;
    prev_reg1 = 0;
    prev_reg2 = 0;
    prev_reg3 = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.reg0 != prev_reg0) begin
            $display("Time=%0t: reg0 changed: %h -> %h", $time, prev_reg0, dut.reg0);
            prev_reg0 = dut.reg0;
        end
        if (dut.reg1 != prev_reg1) begin
            $display("Time=%0t: reg1 changed: %h -> %h", $time, prev_reg1, dut.reg1);
            prev_reg1 = dut.reg1;
        end
        if (dut.reg2 != prev_reg2) begin
            $display("Time=%0t: reg2 changed: %h -> %h", $time, prev_reg2, dut.reg2);
            prev_reg2 = dut.reg2;
        end
        if (dut.reg3 != prev_reg3) begin
            $display("Time=%0t: reg3 changed: %h -> %h", $time, prev_reg3, dut.reg3);
            prev_reg3 = dut.reg3;
        end
    end
end

endmodule