`timescale 1ns / 1ps

module tb_top;

// Bus state parameters (from b15)
parameter StateInit = 0;
parameter StateTi = 1;
parameter StateT1 = 2;
parameter StateT2 = 3;
parameter StateT1P = 4;
parameter StateTh = 5;
parameter StateT2P = 6;
parameter StateT2I = 7;

// Instruction fetch state parameters
parameter Si = 0;
parameter S1 = 1;
parameter S2 = 2;
parameter S3 = 3;
parameter S4 = 4;
parameter S5 = 5;
parameter S6 = 6;
parameter S7 = 7;
parameter S8 = 8;
parameter S9 = 9;

// Instruction opcodes
parameter NOP = 'H90;
parameter MOV_eax_dw = 'HB8;
parameter MOV_ebx_dw = 'HBB;
parameter INC_eax = 'H40;
parameter INC_ebx = 'H43;
parameter JMP_rel_short = 'HEB;

// Address space boundary
parameter ADDR_BOUNDARY = 2 ** 29;  // 512M boundary

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg [31:0] datai;
reg hold;
reg na;
reg bs16;
reg ready1;
reg ready2;

// Output signals
wire [31:0] datao;
wire [30:0] address1;
wire [30:0] address2;
wire wr;
wire dc;
wire mio;
wire ast1;
wire ast2;

// Loop counter
integer i, j;

// File for logging
integer file;

// Memory models for two address spaces
reg [7:0] memory_low [0:1048575];   // 1MB for low address space (< 2^29)
reg [7:0] memory_high [0:1048575];  // 1MB for high address space (>= 2^29)

// Control variables
reg [7:0] ready1_delay, ready2_delay;
integer ready1_counter, ready2_counter;
reg addr1_active, addr2_active;

// Instantiate the DUT (Device Under Test)
b17 dut (
    .clock(clk),
    .reset(~rst_n),  // rst_n is active low, but b17 expects active high reset
    .datai(datai),
    .datao(datao),
    .hold(hold),
    .na(na),
    .bs16(bs16),
    .address1(address1),
    .address2(address2),
    .wr(wr),
    .dc(dc),
    .mio(mio),
    .ast1(ast1),
    .ast2(ast2),
    .ready1(ready1),
    .ready2(ready2)
);

// Clock generation - 10ns period (100MHz)
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// Initialize memory with instruction sequences
initial begin
    // Clear memory
    for (i=0; i<1048576; i=i+1) begin
        memory_low[i] = 8'h90;   // Fill with NOPs
        memory_high[i] = 8'h90;
    end
    
    // Program at reset vector 0xFFFF0 - Low address space
    memory_low['HFFFF0 & 'HFFFFF] = NOP;
    memory_low['HFFFF1 & 'HFFFFF] = NOP;
    memory_low['HFFFF2 & 'HFFFFF] = MOV_eax_dw;
    memory_low['HFFFF3 & 'HFFFFF] = 8'h11;
    memory_low['HFFFF4 & 'HFFFFF] = 8'h22;
    memory_low['HFFFF5 & 'HFFFFF] = 8'h33;
    memory_low['HFFFF6 & 'HFFFFF] = 8'h44;
    memory_low['HFFFF7 & 'HFFFFF] = INC_eax;
    memory_low['HFFFF8 & 'HFFFFF] = INC_eax;
    memory_low['HFFFF9 & 'HFFFFF] = MOV_ebx_dw;
    memory_low['HFFFFA & 'HFFFFF] = 8'hAA;
    memory_low['HFFFFB & 'HFFFFF] = 8'hBB;
    memory_low['HFFFFC & 'HFFFFF] = 8'hCC;
    memory_low['HFFFFD & 'HFFFFF] = 8'hDD;
    memory_low['HFFFFE & 'HFFFFF] = INC_ebx;
    memory_low['HFFFFF & 'HFFFFF] = NOP;
    
    // Program at reset vector 0xFFFF0 - High address space
    memory_high['HFFFF0 & 'HFFFFF] = NOP;
    memory_high['HFFFF1 & 'HFFFFF] = NOP;
    memory_high['HFFFF2 & 'HFFFFF] = MOV_eax_dw;
    memory_high['HFFFF3 & 'HFFFFF] = 8'hFF;
    memory_high['HFFFF4 & 'HFFFFF] = 8'hEE;
    memory_high['HFFFF5 & 'HFFFFF] = 8'hDD;
    memory_high['HFFFF6 & 'HFFFFF] = 8'hCC;
    memory_high['HFFFF7 & 'HFFFFF] = INC_eax;
    memory_high['HFFFF8 & 'HFFFFF] = INC_eax;
    memory_high['HFFFF9 & 'HFFFFF] = MOV_ebx_dw;
    memory_high['HFFFFA & 'HFFFFF] = 8'h55;
    memory_high['HFFFFB & 'HFFFFF] = 8'h66;
    memory_high['HFFFFC & 'HFFFFF] = 8'h77;
    memory_high['HFFFFD & 'HFFFFF] = 8'h88;
    memory_high['HFFFFE & 'HFFFFF] = INC_ebx;
    memory_high['HFFFFF & 'HFFFFF] = NOP;
    
    // Additional test patterns
    for (i=0; i<256; i=i+1) begin
        memory_low[i] = i[7:0];
        memory_high[i] = ~i[7:0];
    end
end

// Memory read/write response for ready1 (address1 port)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ready1 <= 1'b1;
        ready1_counter <= 0;
        addr1_active <= 0;
    end else begin
        // Default: not ready
        ready1 <= 1'b1;
        
        // When bus cycle starts on ast1
        if (ast1 == 1'b0 && !addr1_active) begin
            ready1_delay <= $random % 4;  // Random delay 0-3 cycles
            ready1_counter <= 0;
            addr1_active <= 1;
        end
        
        // Count cycles and assert ready when delay expires
        if (ast1 == 1'b1 && addr1_active) begin
            if (ready1_counter < ready1_delay) begin
                ready1_counter <= ready1_counter + 1;
                ready1 <= 1'b1;
            end else begin
                ready1 <= 1'b0;  // Assert READY (active low)
                
                // Handle memory access on address1 port (low address space)
                if (wr == 1'b0 && mio == 1'b1) begin
                    // Memory read from low address space
                    datai <= {memory_low[({address1, 2'b11}) & 'HFFFFF],
                             memory_low[({address1, 2'b10}) & 'HFFFFF],
                             memory_low[({address1, 2'b01}) & 'HFFFFF],
                             memory_low[({address1, 2'b00}) & 'HFFFFF]};
                end else if (wr == 1'b0 && mio == 1'b0) begin
                    // I/O read
                    datai <= $random;
                end
                
                // Reset active flag after ready is asserted
                if (ready1_counter >= ready1_delay) begin
                    addr1_active <= 0;
                end
            end
        end else if (ast1 == 1'b0) begin
            addr1_active <= 1;
        end
    end
end

// Memory write handling for address1 port
always @(posedge clk) begin
    if (rst_n && ready1 == 1'b0 && wr == 1'b1 && mio == 1'b1 && ast1 == 1'b1) begin
        // Memory write to low address space
        memory_low[({address1, 2'b00}) & 'HFFFFF] <= datao[7:0];
        memory_low[({address1, 2'b01}) & 'HFFFFF] <= datao[15:8];
        memory_low[({address1, 2'b10}) & 'HFFFFF] <= datao[23:16];
        memory_low[({address1, 2'b11}) & 'HFFFFF] <= datao[31:24];
    end
end

// Memory read/write response for ready2 (address2 port)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ready2 <= 1'b1;
        ready2_counter <= 0;
        addr2_active <= 0;
    end else begin
        // Default: not ready
        ready2 <= 1'b1;
        
        // When bus cycle starts on ast2
        if (ast2 == 1'b0 && !addr2_active) begin
            ready2_delay <= $random % 4;  // Random delay 0-3 cycles
            ready2_counter <= 0;
            addr2_active <= 1;
        end
        
        // Count cycles and assert ready when delay expires
        if (ast2 == 1'b1 && addr2_active) begin
            if (ready2_counter < ready2_delay) begin
                ready2_counter <= ready2_counter + 1;
                ready2 <= 1'b1;
            end else begin
                ready2 <= 1'b0;  // Assert READY (active low)
                
                // Handle memory access on address2 port
                if (wr == 1'b0 && mio == 1'b1) begin
                    // Determine which memory space based on address
                    if ({address2, 2'b00} >= ADDR_BOUNDARY) begin
                        // High address space
                        datai <= {memory_high[({address2, 2'b11}) & 'HFFFFF],
                                 memory_high[({address2, 2'b10}) & 'HFFFFF],
                                 memory_high[({address2, 2'b01}) & 'HFFFFF],
                                 memory_high[({address2, 2'b00}) & 'HFFFFF]};
                    end else begin
                        // Low address space
                        datai <= {memory_low[({address2, 2'b11}) & 'HFFFFF],
                                 memory_low[({address2, 2'b10}) & 'HFFFFF],
                                 memory_low[({address2, 2'b01}) & 'HFFFFF],
                                 memory_low[({address2, 2'b00}) & 'HFFFFF]};
                    end
                end else if (wr == 1'b0 && mio == 1'b0) begin
                    // I/O read
                    datai <= $random;
                end
                
                if (ready2_counter >= ready2_delay) begin
                    addr2_active <= 0;
                end
            end
        end else if (ast2 == 1'b0) begin
            addr2_active <= 1;
        end
    end
end

// Memory write handling for address2 port
always @(posedge clk) begin
    if (rst_n && ready2 == 1'b0 && wr == 1'b1 && mio == 1'b1 && ast2 == 1'b1) begin
        // Determine which address space to write
        if ({address2, 2'b00} >= ADDR_BOUNDARY) begin
            // High address space
            memory_high[({address2, 2'b00}) & 'HFFFFF] <= datao[7:0];
            memory_high[({address2, 2'b01}) & 'HFFFFF] <= datao[15:8];
            memory_high[({address2, 2'b10}) & 'HFFFFF] <= datao[23:16];
            memory_high[({address2, 2'b11}) & 'HFFFFF] <= datao[31:24];
        end else begin
            // Low address space
            memory_low[({address2, 2'b00}) & 'HFFFFF] <= datao[7:0];
            memory_low[({address2, 2'b01}) & 'HFFFFF] <= datao[15:8];
            memory_low[({address2, 2'b10}) & 'HFFFFF] <= datao[23:16];
            memory_low[({address2, 2'b11}) & 'HFFFFF] <= datao[31:24];
        end
    end
end

// Test stimulus
initial begin
    // Initialize signals
    rst_n = 0;
    datai = 32'h00000000;
    hold = 0;
    na = 1;
    bs16 = 1;  // 32-bit bus
    
    // Open file for logging
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\tna\tbs16\trdy1\trdy2\thold\tdatai\t\tdatao\t\taddr1\t\taddr2\t\twr\tdc\tmio\tast1\tast2\tbuf1\t\tbuf2\t\tP1_EAX\t\tP2_EAX\t\tP3_EAX\t\tP1_St2\tP2_St2\tP3_St2\n");
    $fwrite(file, "-----\t--\t----\t----\t----\t----\t--------\t--------\t--------\t--------\t--\t--\t---\t----\t----\t--------\t--------\t--------\t--------\t--------\t------\t------\t------\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation with random input ===\n");
    $display("This is a Triple-Processor System (b17) testbench");
    $display("Features: 3x b15 processors with shared buffers and dual address spaces");
    $display("Architecture:");
    $display("  - P1: Writes to buf1 when accessing high addresses (>= 2^29)");
    $display("  - P2: Can write to buf1 (high addr) and buf2 (low addr), reads from buf1");
    $display("  - P3: Reads from buf2, outputs via address2");
    $display("  - Address boundary: 0x%h (512MB)\n", ADDR_BOUNDARY);
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        
        // Random control signal generation
        // NA (mostly inactive)
        if ($random % 100 < 3) begin
            na <= 1'b0;
        end else begin
            na <= 1'b1;
        end
        
        // BS16 (mostly 32-bit)
        if ($random % 100 < 1) begin
            bs16 <= 1'b0;
        end else begin
            bs16 <= 1'b1;
        end
        
        // HOLD (very rare)
        if ($random % 2000 < 1) begin
            hold <= 1'b1;
        end else if ($random % 100 < 5) begin
            hold <= 1'b0;
        end
        
        // Log to file every 10 cycles
        if (file && i % 10 == 0) begin
            $fwrite(file, "%0d\t%b\t%b\t%b\t%b\t%b\t%h\t%h\t%h\t%h\t%b\t%b\t%b\t%b\t%b\t%h\t%h\t%h\t%h\t%h\t%0d\t%0d\t%0d\n",
                    i, na, bs16, ready1, ready2, hold, datai, datao,
                    address1, address2, wr, dc, mio, ast1, ast2,
                    dut.buf1, dut.buf2,
                    dut.P1.EAX, dut.P2.EAX, dut.P3.EAX,
                    dut.P1.State2, dut.P2.State2, dut.P3.State2);
        end
        
        // Display bus cycles
        if (ast1 == 1'b0) begin
            $display("Time=%0t: Cycle %0d - AST1 | Addr=%h W/R=%b D/C=%b M/IO=%b",
                     $time, i, {address1, 2'b00}, wr, dc, mio);
        end
        
        if (ast2 == 1'b0) begin
            $display("Time=%0t: Cycle %0d - AST2 | Addr=%h W/R=%b D/C=%b M/IO=%b Space=%s",
                     $time, i, {address2, 2'b00}, wr, dc, mio,
                     ({address2, 2'b00} >= ADDR_BOUNDARY) ? "HIGH" : "LOW");
        end
        
        // Display buffer activity
        if (i > 0 && dut.buf1 != 0 && i % 100 == 0) begin
            $display("Time=%0t: Cycle %0d - BUF1=%h (P1/P2 high addr buffer)",
                     $time, i, dut.buf1);
        end
        
        if (i > 0 && dut.buf2 != 0 && i % 100 == 0) begin
            $display("Time=%0t: Cycle %0d - BUF2=%h (P2/P3 low addr buffer)",
                     $time, i, dut.buf2);
        end
        
        // Display memory operations
        if (ready1 == 1'b0 && wr == 1'b0 && mio == 1'b1) begin
            $display("Time=%0t: Cycle %0d - MEM READ (addr1) | Addr=%h Data=%h",
                     $time, i, {address1, 2'b00}, datai);
        end
        
        if (ready2 == 1'b0 && wr == 1'b0 && mio == 1'b1) begin
            $display("Time=%0t: Cycle %0d - MEM READ (addr2) | Addr=%h Data=%h Space=%s",
                     $time, i, {address2, 2'b00}, datai,
                     ({address2, 2'b00} >= ADDR_BOUNDARY) ? "HIGH" : "LOW");
        end
        
        if (ready1 == 1'b0 && wr == 1'b1 && mio == 1'b1) begin
            $display("Time=%0t: Cycle %0d - MEM WRITE (addr1) | Addr=%h Data=%h",
                     $time, i, {address1, 2'b00}, datao);
        end
        
        if (ready2 == 1'b0 && wr == 1'b1 && mio == 1'b1) begin
            $display("Time=%0t: Cycle %0d - MEM WRITE (addr2) | Addr=%h Data=%h Space=%s",
                     $time, i, {address2, 2'b00}, datao,
                     ({address2, 2'b00} >= ADDR_BOUNDARY) ? "HIGH" : "LOW");
        end
        
        // Display processor registers periodically
        if (i > 100 && i % 500 == 0) begin
            $display("Time=%0t: Cycle %0d - PROCESSOR REGISTERS:", $time, i);
            $display("  P1: EAX=%h EBX=%h rEIP=%h State2=%0d",
                     dut.P1.EAX, dut.P1.EBX, dut.P1.rEIP, dut.P1.State2);
            $display("  P2: EAX=%h EBX=%h rEIP=%h State2=%0d",
                     dut.P2.EAX, dut.P2.EBX, dut.P2.rEIP, dut.P2.State2);
            $display("  P3: EAX=%h EBX=%h rEIP=%h State2=%0d",
                     dut.P3.EAX, dut.P3.EBX, dut.P3.rEIP, dut.P3.State2);
        end
        
        // Display ready coordination
        if (i % 1000 == 0) begin
            $display("Time=%0t: Cycle %0d - READY SIGNALS | rdy1=%b rdy2=%b rdy3=%b | r11=%b r12=%b r21=%b r22=%b",
                     $time, i, dut.rdy1, dut.rdy2, dut.rdy3,
                     dut.ready11, dut.ready12, dut.ready21, dut.ready22);
        end
        
        // Display progress
        if (i % 1000 == 0) begin
            $display("Time=%0t: Cycle %0d | Buffers: buf1=%h buf2=%h | Processors: P1=%0d P2=%0d P3=%0d",
                     $time, i, dut.buf1, dut.buf2,
                     dut.P1.State2, dut.P2.State2, dut.P3.State2);
        end
    end
    
    // Close file and finish
    if (file) $fclose(file);
    
    $display("\n=== Simulation Complete ===");
    $display("Total cycles run: %0d", i);
    $display("\nFinal Processor States:");
    $display("P1: EAX=%h EBX=%h rEIP=%h", dut.P1.EAX, dut.P1.EBX, dut.P1.rEIP);
    $display("P2: EAX=%h EBX=%h rEIP=%h", dut.P2.EAX, dut.P2.EBX, dut.P2.rEIP);
    $display("P3: EAX=%h EBX=%h rEIP=%h", dut.P3.EAX, dut.P3.EBX, dut.P3.rEIP);
    $display("\nFinal Buffer States:");
    $display("buf1 (P1/P2 shared): %h", dut.buf1);
    $display("buf2 (P2/P3 shared): %h", dut.buf2);
    $display("\nCheck 'simulation_log.txt' for detailed signal log");
    $finish;
end

// Monitor for debugging
initial begin
    $display("=== b17 Triple-Processor System Testbench ===");
    $display("Time\t\trst_n\tast1\tast2\taddr1\t\taddr2\t\twr\tbuf1\t\tbuf2");
    $display("----\t\t-----\t----\t----\t--------\t--------\t--\t--------\t--------");
    $monitor("%0t\t%b\t%b\t%b\t%h\t%h\t%b\t%h\t%h",
             $time, rst_n, ast1, ast2, address1, address2, wr, dut.buf1, dut.buf2);
end

// Generate VCD file
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    
    // Dump b17 signals
    $dumpvars(0, dut.buf1);
    $dumpvars(0, dut.buf2);
    $dumpvars(0, dut.ready11);
    $dumpvars(0, dut.ready12);
    $dumpvars(0, dut.ready21);
    $dumpvars(0, dut.ready22);
    
    // Dump P1 signals
    $dumpvars(0, dut.P1.State);
    $dumpvars(0, dut.P1.State2);
    $dumpvars(0, dut.P1.EAX);
    $dumpvars(0, dut.P1.EBX);
    $dumpvars(0, dut.P1.rEIP);
    
    // Dump P2 signals
    $dumpvars(0, dut.P2.State);
    $dumpvars(0, dut.P2.State2);
    $dumpvars(0, dut.P2.EAX);
    $dumpvars(0, dut.P2.EBX);
    $dumpvars(0, dut.P2.rEIP);
    
    // Dump P3 signals
    $dumpvars(0, dut.P3.State);
    $dumpvars(0, dut.P3.State2);
    $dumpvars(0, dut.P3.EAX);
    $dumpvars(0, dut.P3.EBX);
    $dumpvars(0, dut.P3.rEIP);
end

// State name decoder
function [79:0] fetch_state_name;
    input [3:0] state;
    begin
        case(state)
            Si: fetch_state_name = "Si_INIT";
            S1: fetch_state_name = "S1_FETCH_WAIT";
            S2: fetch_state_name = "S2_QUEUE_FILL";
            S3: fetch_state_name = "S3_FETCH2_WAIT";
            S4: fetch_state_name = "S4_QUEUE_FILL2";
            S5: fetch_state_name = "S5_DECODE_EXEC";
            S6: fetch_state_name = "S6_WRITE_WAIT";
            S7: fetch_state_name = "S7_QUEUE_MGMT";
            S8: fetch_state_name = "S8_QUEUE_SHIFT";
            S9: fetch_state_name = "S9_FETCH_RESTART";
            default: fetch_state_name = "UNKNOWN";
        endcase
    end
endfunction

// Detailed snapshots
initial begin
    @(posedge rst_n);
    
    for (i=0; i<500; i=i+1) begin
        @(posedge clk);
        if (i % 100 == 0) begin
            $display("\n========== Cycle %0d Snapshot ==========", i);
            $display("Control: na=%b bs16=%b hold=%b", na, bs16, hold);
            $display("Ready: ready1=%b ready2=%b", ready1, ready2);
            $display("Bus: ast1=%b ast2=%b wr=%b dc=%b mio=%b",
                     ast1, ast2, wr, dc, mio);
            $display("Addresses: addr1=%h addr2=%h", address1, address2);
            $display("Data: datai=%h datao=%h", datai, datao);
            
            $display("\nShared Buffers:");
            $display("  buf1=%h (P1/P2 high addr)", dut.buf1);
            $display("  buf2=%h (P2/P3 low addr)", dut.buf2);
            
            $display("\nReady Coordination:");
            $display("  ready11=%b ready12=%b", dut.ready11, dut.ready12);
            $display("  ready21=%b ready22=%b", dut.ready21, dut.ready22);
            $display("  rdy1=%b rdy2=%b rdy3=%b", dut.rdy1, dut.rdy2, dut.rdy3);
            
            $display("\nP1 (low space via addr1):");
            $display("  State2=%s(%0d)", fetch_state_name(dut.P1.State2), dut.P1.State2);
            $display("  EAX=%h EBX=%h rEIP=%h", dut.P1.EAX, dut.P1.EBX, dut.P1.rEIP);
            
            $display("\nP2 (dual access):");
            $display("  State2=%s(%0d)", fetch_state_name(dut.P2.State2), dut.P2.State2);
            $display("  EAX=%h EBX=%h rEIP=%h", dut.P2.EAX, dut.P2.EBX, dut.P2.rEIP);
            
            $display("\nP3 (via buf2/addr2):");
            $display("  State2=%s(%0d)", fetch_state_name(dut.P3.State2), dut.P3.State2);
            $display("  EAX=%h EBX=%h rEIP=%h", dut.P3.EAX, dut.P3.EBX, dut.P3.rEIP);
            $display("==========================================\n");
        end
    end
end

// Track buffer communication
integer buf1_writes, buf2_writes;
reg [31:0] prev_buf1, prev_buf2;

initial begin
    @(posedge rst_n);
    buf1_writes = 0;
    buf2_writes = 0;
    prev_buf1 = 0;
    prev_buf2 = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.buf1 != prev_buf1) begin
            buf1_writes = buf1_writes + 1;
            $display("Time=%0t: BUF1 WRITE #%0d | %h -> %h",
                     $time, buf1_writes, prev_buf1, dut.buf1);
            prev_buf1 = dut.buf1;
        end
        
        if (dut.buf2 != prev_buf2) begin
            buf2_writes = buf2_writes + 1;
            $display("Time=%0t: BUF2 WRITE #%0d | %h -> %h",
                     $time, buf2_writes, prev_buf2, dut.buf2);
            prev_buf2 = dut.buf2;
        end
    end
    
    #100;
    $display("\n=== Buffer Communication Summary ===");
    $display("buf1 writes: %0d", buf1_writes);
    $display("buf2 writes: %0d", buf2_writes);
end

// Track address space usage
integer low_addr_count, high_addr_count;
integer addr1_cycles, addr2_cycles;

initial begin
    @(posedge rst_n);
    low_addr_count = 0;
    high_addr_count = 0;
    addr1_cycles = 0;
    addr2_cycles = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (ast1 == 1'b0) begin
            addr1_cycles = addr1_cycles + 1;
            low_addr_count = low_addr_count + 1;
        end
        
        if (ast2 == 1'b0) begin
            addr2_cycles = addr2_cycles + 1;
            if ({address2, 2'b00} >= ADDR_BOUNDARY) begin
                high_addr_count = high_addr_count + 1;
            end else begin
                low_addr_count = low_addr_count + 1;
            end
        end
    end
    
    #100;
    $display("\n=== Address Space Usage ===");
    $display("address1 cycles: %0d", addr1_cycles);
    $display("address2 cycles: %0d", addr2_cycles);
    $display("Low space accesses: %0d", low_addr_count);
    $display("High space accesses: %0d", high_addr_count);
end

// Track per-processor activity
integer p1_instr, p2_instr, p3_instr;
reg [3:0] prev_p1_st, prev_p2_st, prev_p3_st;

initial begin
    @(posedge rst_n);
    p1_instr = 0;
    p2_instr = 0;
    p3_instr = 0;
    prev_p1_st = dut.P1.State2;
    prev_p2_st = dut.P2.State2;
    prev_p3_st = dut.P3.State2;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.P1.State2 == S5 && prev_p1_st != S5) p1_instr = p1_instr + 1;
        if (dut.P2.State2 == S5 && prev_p2_st != S5) p2_instr = p2_instr + 1;
        if (dut.P3.State2 == S5 && prev_p3_st != S5) p3_instr = p3_instr + 1;
        
        prev_p1_st = dut.P1.State2;
        prev_p2_st = dut.P2.State2;
        prev_p3_st = dut.P3.State2;
    end
    
    #100;
    $display("\n=== Instruction Count ===");
    $display("P1: %0d instructions", p1_instr);
    $display("P2: %0d instructions", p2_instr);
    $display("P3: %0d instructions", p3_instr);
    $display("Total: %0d instructions", p1_instr + p2_instr + p3_instr);
end

// Track register changes
reg [31:0] prev_p1_eax, prev_p2_eax, prev_p3_eax;
reg [31:0] prev_p1_ebx, prev_p2_ebx, prev_p3_ebx;

initial begin
    @(posedge rst_n);
    prev_p1_eax = 0; prev_p2_eax = 0; prev_p3_eax = 0;
    prev_p1_ebx = 0; prev_p2_ebx = 0; prev_p3_ebx = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.P1.EAX != prev_p1_eax) begin
            $display("Time=%0t: P1.EAX: %h -> %h", $time, prev_p1_eax, dut.P1.EAX);
            prev_p1_eax = dut.P1.EAX;
        end
        if (dut.P1.EBX != prev_p1_ebx) begin
            $display("Time=%0t: P1.EBX: %h -> %h", $time, prev_p1_ebx, dut.P1.EBX);
            prev_p1_ebx = dut.P1.EBX;
        end
        
        if (dut.P2.EAX != prev_p2_eax) begin
            $display("Time=%0t: P2.EAX: %h -> %h", $time, prev_p2_eax, dut.P2.EAX);
            prev_p2_eax = dut.P2.EAX;
        end
        if (dut.P2.EBX != prev_p2_ebx) begin
            $display("Time=%0t: P2.EBX: %h -> %h", $time, prev_p2_ebx, dut.P2.EBX);
            prev_p2_ebx = dut.P2.EBX;
        end
        
        if (dut.P3.EAX != prev_p3_eax) begin
            $display("Time=%0t: P3.EAX: %h -> %h", $time, prev_p3_eax, dut.P3.EAX);
            prev_p3_eax = dut.P3.EAX;
        end
        if (dut.P3.EBX != prev_p3_ebx) begin
            $display("Time=%0t: P3.EBX: %h -> %h", $time, prev_p3_ebx, dut.P3.EBX);
            prev_p3_ebx = dut.P3.EBX;
        end
    end
end

endmodule
