`timescale 1ns / 1ps

module tb_top;

// Bus state parameters (must match b15.v)
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
parameter MOV_al_b = 'HB0;
parameter MOV_eax_dw = 'HB8;
parameter MOV_ebx_dw = 'HBB;
parameter MOV_ebx_eax = 'H89;
parameter MOV_eax_ebx = 'H8B;
parameter IN_al = 'HE4;
parameter OUT_al = 'HE6;
parameter ADD_al_b = 'H04;
parameter INC_eax = 'H40;
parameter INC_ebx = 'H43;
parameter JMP_rel_short = 'HEB;
parameter JMP_rel_near = 'HE9;
parameter HLT = 'HF4;

// Clock and reset signals
reg clk;
reg rst_n;

// Input signals
reg NA_n;
reg BS16_n;
reg READY_n;
reg HOLD;
reg [31:0] Datai;

// Output signals
wire [3:0] BE_n;
wire [31:0] Address;
wire W_R_n;
wire D_C_n;
wire M_IO_n;
wire ADS_n;
wire [31:0] Datao;

// Loop counter
integer i, j;

// File for logging
integer file;

// Memory model for instruction/data storage
reg [7:0] memory [0:1048575];  // 1MB memory

// Control variables
reg [7:0] ready_delay;
integer ready_counter;
reg hold_active;

// Instantiate the DUT (Device Under Test)
b15 dut (
    .CLOCK(clk),
    .RESET(~rst_n),  // rst_n is active low, but b15 expects active high reset
    .NA_n(NA_n),
    .BS16_n(BS16_n),
    .READY_n(READY_n),
    .HOLD(HOLD),
    .Datai(Datai),
    .BE_n(BE_n),
    .Address(Address),
    .W_R_n(W_R_n),
    .D_C_n(D_C_n),
    .M_IO_n(M_IO_n),
    .ADS_n(ADS_n),
    .Datao(Datao)
);

// Clock generation - 10ns period (100MHz)
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// Initialize memory with a simple instruction sequence
initial begin
    // Clear memory
    for (i=0; i<1048576; i=i+1) begin
        memory[i] = 8'h90;  // Fill with NOPs
    end
    
    // Program at reset vector 0xFFFF0
    memory['HFFFF0] = NOP;           // NOP
    memory['HFFFF1] = NOP;           // NOP
    memory['HFFFF2] = MOV_eax_dw;    // MOV EAX, dword
    memory['HFFFF3] = 8'h34;         // immediate low byte
    memory['HFFFF4] = 8'h12;         
    memory['HFFFF5] = 8'h00;
    memory['HFFFF6] = 8'h00;         // immediate = 0x00001234
    memory['HFFFF7] = INC_eax;       // INC EAX
    memory['HFFFF8] = INC_eax;       // INC EAX
    memory['HFFFF9] = MOV_ebx_dw;    // MOV EBX, dword
    memory['HFFFFA] = 8'h78;         // immediate low byte
    memory['HFFFFB] = 8'h56;
    memory['HFFFFC] = 8'h00;
    memory['HFFFFD] = 8'h00;         // immediate = 0x00005678
    memory['HFFFFE] = INC_ebx;       // INC EBX
    memory['HFFFFF] = NOP;           // NOP
    
    // More instructions at lower addresses
    for (i=0; i<100; i=i+1) begin
        memory[i] = NOP;
    end
    memory[100] = INC_eax;
    memory[101] = INC_ebx;
    memory[102] = NOP;
    memory[103] = JMP_rel_short;
    memory[104] = 8'h05;  // Jump +5 bytes
    memory[105] = NOP;
end

// Memory read/write response with READY control
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        READY_n <= 1'b1;
        Datai <= 32'h00000000;
        ready_counter <= 0;
    end else begin
        // Default: not ready
        READY_n <= 1'b1;
        
        // When bus cycle starts (ADS_n goes low)
        if (ADS_n == 1'b0) begin
            // Random ready delay (0-3 cycles)
            ready_delay <= $random % 4;
            ready_counter <= 0;
        end
        
        // Count cycles and assert READY when delay expires
        if (ADS_n == 1'b1 && ready_counter < ready_delay) begin
            ready_counter <= ready_counter + 1;
            READY_n <= 1'b1;
        end else if (ADS_n == 1'b1 && ready_counter >= ready_delay) begin
            READY_n <= 1'b0;  // Assert READY (active low)
            
            // Handle memory read
            if (W_R_n == 1'b0 && M_IO_n == 1'b1) begin
                // Memory read - construct 32-bit word from byte-addressed memory
                Datai <= {memory[{Address, 2'b11}], 
                         memory[{Address, 2'b10}], 
                         memory[{Address, 2'b01}], 
                         memory[{Address, 2'b00}]};
            end else if (W_R_n == 1'b0 && M_IO_n == 1'b0) begin
                // I/O read - return random data
                Datai <= $random;
            end else if (W_R_n == 1'b1) begin
                // Memory/IO write - store data
                if (M_IO_n == 1'b1) begin
                    // Memory write - store based on byte enables
                    if (BE_n[0] == 1'b0) memory[{Address, 2'b00}] <= Datao[7:0];
                    if (BE_n[1] == 1'b0) memory[{Address, 2'b01}] <= Datao[15:8];
                    if (BE_n[2] == 1'b0) memory[{Address, 2'b10}] <= Datao[23:16];
                    if (BE_n[3] == 1'b0) memory[{Address, 2'b11}] <= Datao[31:24];
                end
            end
        end
    end
end

// Test stimulus
initial begin
    // Initialize signals
    rst_n = 0;
    NA_n = 1;
    BS16_n = 1;  // 32-bit bus
    HOLD = 0;
    hold_active = 0;
    
    // Open file for logging
    file = $fopen("simulation_log.txt", "w");
    $fwrite(file, "Cycle\tNA_n\tBS16\tRDY_n\tHOLD\tDatai\t\tBE_n\tAddr\t\tW_R\tD_C\tM_IO\tADS\tDatao\t\tState\tState2\tEAX\t\tEBX\t\trEIP\t\tInstQRd\tInstQWr\n");
    $fwrite(file, "-----\t----\t----\t-----\t----\t--------\t----\t--------\t---\t---\t----\t---\t--------\t-----\t------\t--------\t--------\t--------\t-------\t-------\n");
    
    // Apply reset
    #20;
    rst_n = 1;
    #10;
    
    $display("\n=== Starting 50k cycle simulation ===\n");
    $display("This is a simplified i486-like Processor testbench");
    $display("Features: Bus controller, instruction fetch, basic instruction execution");
    $display("Reset vector: 0xFFFF0\n");
    
    // Run for 50k cycles with random inputs
    for (i=0; i<50000; i=i+1) begin
        @(posedge clk);
        
        // Random NA_n generation (mostly inactive)
        if ($random % 100 < 5) begin
            NA_n <= 1'b0;  // 5% chance of next address request
        end else begin
            NA_n <= 1'b1;
        end
        
        // Random bus width toggle (mostly 32-bit)
        if ($random % 100 < 2) begin
            BS16_n <= 1'b0;  // 2% chance of 16-bit bus
        end else begin
            BS16_n <= 1'b1;  // 32-bit bus
        end
        
        // Random HOLD generation (rare)
        if ($random % 1000 < 2 && !hold_active) begin
            HOLD <= 1'b1;
            hold_active <= 1;
        end else if (hold_active && $random % 10 < 3) begin
            HOLD <= 1'b0;
            hold_active <= 0;
        end
        
        // Log internal signals to file
        if (file && i % 10 == 0) begin  // Log every 10 cycles to reduce file size
            $fwrite(file, "%0d\t%b\t%b\t%b\t%b\t%h\t%b\t%h\t%b\t%b\t%b\t%b\t%h\t%0d\t%0d\t%h\t%h\t%h\t%0d\t%0d\n", 
                    i, NA_n, BS16_n, READY_n, HOLD, Datai, BE_n, Address,
                    W_R_n, D_C_n, M_IO_n, ADS_n, Datao, 
                    dut.State, dut.State2, dut.EAX, dut.EBX, dut.rEIP,
                    dut.InstQueueRd_Addr, dut.InstQueueWr_Addr);
        end
        
        // Display bus cycles
        if (ADS_n == 1'b0) begin
            $display("Time=%0t: Cycle %0d - BUS CYCLE START | Addr=%h BE=%b W/R=%b D/C=%b M/IO=%b", 
                     $time, i, Address, BE_n, W_R_n, D_C_n, M_IO_n);
        end
        
        // Display memory reads
        if (READY_n == 1'b0 && W_R_n == 1'b0 && M_IO_n == 1'b1) begin
            $display("Time=%0t: Cycle %0d - MEMORY READ | Addr=%h Data=%h", 
                     $time, i, Address, Datai);
        end
        
        // Display memory writes
        if (READY_n == 1'b0 && W_R_n == 1'b1 && M_IO_n == 1'b1) begin
            $display("Time=%0t: Cycle %0d - MEMORY WRITE | Addr=%h Data=%h BE=%b", 
                     $time, i, Address, Datao, BE_n);
        end
        
        // Display I/O operations
        if (READY_n == 1'b0 && M_IO_n == 1'b0) begin
            if (W_R_n == 1'b0) begin
                $display("Time=%0t: Cycle %0d - IO READ | Port=%h Data=%h", 
                         $time, i, Address, Datai);
            end else begin
                $display("Time=%0t: Cycle %0d - IO WRITE | Port=%h Data=%h", 
                         $time, i, Address, Datao);
            end
        end
        
        // Display register changes
        if (i > 100 && (dut.EAX != 0 || dut.EBX != 0)) begin
            if (i % 100 == 0) begin
                $display("Time=%0t: Cycle %0d - REGISTERS | EAX=%h EBX=%h rEIP=%h", 
                         $time, i, dut.EAX, dut.EBX, dut.rEIP);
            end
        end
        
        // Display instruction queue status
        if (dut.State2 == S2 || dut.State2 == S4) begin
            $display("Time=%0t: Cycle %0d - INST QUEUE | Rd=%0d Wr=%0d (filling)", 
                     $time, i, dut.InstQueueRd_Addr, dut.InstQueueWr_Addr);
        end
        
        // Display flush events
        if (dut.Flush == 1'b1) begin
            $display("Time=%0t: Cycle %0d - **FLUSH** instruction queue | InstAddrPtr=%h", 
                     $time, i, dut.InstAddrPointer);
        end
        
        // Display progress every 1000 cycles
        if (i % 1000 == 0) begin
            $display("Time=%0t: Cycle %0d | BusState=%s(%0d) FetchState=%s(%0d) EAX=%h EBX=%h", 
                     $time, i, bus_state_name(dut.State), dut.State,
                     fetch_state_name(dut.State2), dut.State2, dut.EAX, dut.EBX);
        end
    end
    
    // Close file and finish simulation
    if (file) $fclose(file);
    
    $display("\n=== Simulation Complete ===");
    $display("Total cycles run: %0d", i);
    $display("Final register state:");
    $display("  EAX = %h (%0d)", dut.EAX, dut.EAX);
    $display("  EBX = %h (%0d)", dut.EBX, dut.EBX);
    $display("  rEIP = %h", dut.rEIP);
    $display("Check 'simulation_log.txt' for detailed signal log");
    $finish;
end

// Monitor for debugging
initial begin
    $display("=== b15 i486-like Processor Testbench ===");
    $display("Time\t\trst_n\tADS\tRDY\tAddr\t\tDatai\t\tState\tState2\tEAX\t\tEBX");
    $display("----\t\t-----\t---\t---\t--------\t--------\t-----\t------\t--------\t--------");
    $monitor("%0t\t%b\t%b\t%b\t%h\t%h\t%0d\t%0d\t%h\t%h", 
             $time, rst_n, ADS_n, READY_n, Address, Datai, dut.State, dut.State2, dut.EAX, dut.EBX);
end

// Generate VCD file for waveform viewing
initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    // Explicitly dump all internal signals
    $dumpvars(0, dut.State);
    $dumpvars(0, dut.State2);
    $dumpvars(0, dut.EAX);
    $dumpvars(0, dut.EBX);
    $dumpvars(0, dut.rEIP);
    $dumpvars(0, dut.StateNA);
    $dumpvars(0, dut.StateBS16);
    $dumpvars(0, dut.RequestPending);
    $dumpvars(0, dut.NonAligned);
    $dumpvars(0, dut.ReadRequest);
    $dumpvars(0, dut.MemoryFetch);
    $dumpvars(0, dut.CodeFetch);
    $dumpvars(0, dut.ByteEnable);
    $dumpvars(0, dut.DataWidth);
    $dumpvars(0, dut.InstQueueRd_Addr);
    $dumpvars(0, dut.InstQueueWr_Addr);
    $dumpvars(0, dut.InstAddrPointer);
    $dumpvars(0, dut.PhyAddrPointer);
    $dumpvars(0, dut.Extended);
    $dumpvars(0, dut.More);
    $dumpvars(0, dut.Flush);
    // Dump instruction queue
    for (i=0; i<16; i=i+1) begin
        $dumpvars(0, dut.InstQueue[i]);
    end
end

// State name decoders
function [95:0] bus_state_name;
    input [3:0] state;
    begin
        case(state)
            StateInit: bus_state_name = "StateInit";
            StateTi: bus_state_name = "StateTi";
            StateT1: bus_state_name = "StateT1";
            StateT2: bus_state_name = "StateT2";
            StateT1P: bus_state_name = "StateT1P";
            StateTh: bus_state_name = "StateTh";
            StateT2P: bus_state_name = "StateT2P";
            StateT2I: bus_state_name = "StateT2I";
            default: bus_state_name = "UNKNOWN";
        endcase
    end
endfunction

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

function [95:0] opcode_name;
    input [7:0] opcode;
    begin
        case(opcode)
            NOP: opcode_name = "NOP";
            MOV_al_b: opcode_name = "MOV_al_b";
            MOV_eax_dw: opcode_name = "MOV_eax_dw";
            MOV_ebx_dw: opcode_name = "MOV_ebx_dw";
            MOV_ebx_eax: opcode_name = "MOV_ebx_eax";
            MOV_eax_ebx: opcode_name = "MOV_eax_ebx";
            IN_al: opcode_name = "IN_al";
            OUT_al: opcode_name = "OUT_al";
            ADD_al_b: opcode_name = "ADD_al_b";
            INC_eax: opcode_name = "INC_eax";
            INC_ebx: opcode_name = "INC_ebx";
            JMP_rel_short: opcode_name = "JMP_rel_short";
            JMP_rel_near: opcode_name = "JMP_rel_near";
            HLT: opcode_name = "HLT";
            default: opcode_name = "UNKNOWN";
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
            $display("Bus State Machine: %s (%0d)", bus_state_name(dut.State), dut.State);
            $display("Fetch State Machine: %s (%0d)", fetch_state_name(dut.State2), dut.State2);
            $display("Bus Control Inputs: NA_n=%b BS16_n=%b READY_n=%b HOLD=%b", 
                     NA_n, BS16_n, READY_n, HOLD);
            $display("Bus Outputs: ADS_n=%b W_R_n=%b D_C_n=%b M_IO_n=%b", 
                     ADS_n, W_R_n, D_C_n, M_IO_n);
            $display("Address/Data: Addr=%h BE_n=%b", Address, BE_n);
            $display("  Datai=%h Datao=%h", Datai, Datao);
            $display("Processor Registers:");
            $display("  EAX=%h (%0d)", dut.EAX, dut.EAX);
            $display("  EBX=%h (%0d)", dut.EBX, dut.EBX);
            $display("  rEIP=%h", dut.rEIP);
            $display("Instruction Queue:");
            $display("  Rd_Addr=%0d Wr_Addr=%0d", dut.InstQueueRd_Addr, dut.InstQueueWr_Addr);
            $display("  InstAddrPtr=%h PhyAddrPtr=%h", dut.InstAddrPointer, dut.PhyAddrPointer);
            $display("  Extended=%b More=%b Flush=%b", dut.Extended, dut.More, dut.Flush);
            $display("Queue Contents [0-7]: %h %h %h %h %h %h %h %h",
                     dut.InstQueue[0], dut.InstQueue[1], dut.InstQueue[2], dut.InstQueue[3],
                     dut.InstQueue[4], dut.InstQueue[5], dut.InstQueue[6], dut.InstQueue[7]);
            $display("Current Opcode: %h (%s)", 
                     dut.InstQueue[dut.InstQueueRd_Addr], 
                     opcode_name(dut.InstQueue[dut.InstQueueRd_Addr]));
        end
    end
end

// Track bus state transitions
reg [3:0] prev_bus_state;
integer bus_transition_count;

initial begin
    @(posedge rst_n);
    prev_bus_state = dut.State;
    bus_transition_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.State != prev_bus_state) begin
            bus_transition_count = bus_transition_count + 1;
            $display("Time=%0t: BUS STATE TRANSITION #%0d | %s(%0d) -> %s(%0d)", 
                     $time, bus_transition_count,
                     bus_state_name(prev_bus_state), prev_bus_state,
                     bus_state_name(dut.State), dut.State);
            prev_bus_state = dut.State;
        end
    end
    
    #100;
    $display("\n=== Bus State Machine Summary ===");
    $display("Total bus state transitions: %0d", bus_transition_count);
end

// Track fetch state transitions
reg [3:0] prev_fetch_state;
integer fetch_transition_count;

initial begin
    @(posedge rst_n);
    prev_fetch_state = dut.State2;
    fetch_transition_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.State2 != prev_fetch_state) begin
            fetch_transition_count = fetch_transition_count + 1;
            $display("Time=%0t: FETCH STATE TRANSITION #%0d | %s(%0d) -> %s(%0d)", 
                     $time, fetch_transition_count,
                     fetch_state_name(prev_fetch_state), prev_fetch_state,
                     fetch_state_name(dut.State2), dut.State2);
            prev_fetch_state = dut.State2;
        end
    end
    
    #100;
    $display("\n=== Fetch State Machine Summary ===");
    $display("Total fetch state transitions: %0d", fetch_transition_count);
end

// Track bus cycles
integer read_cycles, write_cycles, code_fetches, data_accesses, io_accesses;

initial begin
    @(posedge rst_n);
    read_cycles = 0;
    write_cycles = 0;
    code_fetches = 0;
    data_accesses = 0;
    io_accesses = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (READY_n == 1'b0) begin
            if (W_R_n == 1'b0) begin
                read_cycles = read_cycles + 1;
            end else begin
                write_cycles = write_cycles + 1;
            end
            
            if (D_C_n == 1'b0) begin
                code_fetches = code_fetches + 1;
            end else begin
                data_accesses = data_accesses + 1;
            end
            
            if (M_IO_n == 1'b0) begin
                io_accesses = io_accesses + 1;
            end
        end
    end
    
    #100;
    $display("\n=== Bus Cycle Summary ===");
    $display("Total read cycles: %0d", read_cycles);
    $display("Total write cycles: %0d", write_cycles);
    $display("Code fetches: %0d", code_fetches);
    $display("Data accesses: %0d", data_accesses);
    $display("I/O accesses: %0d", io_accesses);
end

// Track instruction execution
integer nop_count, mov_count, inc_count, jmp_count, other_inst_count;
reg [7:0] current_opcode;

initial begin
    @(posedge rst_n);
    nop_count = 0;
    mov_count = 0;
    inc_count = 0;
    jmp_count = 0;
    other_inst_count = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        // Detect instruction execution in S5 state
        if (dut.State2 == S5 && prev_fetch_state != S5) begin
            current_opcode = dut.InstQueue[dut.InstQueueRd_Addr];
            
            case(current_opcode)
                NOP: begin
                    nop_count = nop_count + 1;
                    $display("Time=%0t: EXECUTE NOP #%0d", $time, nop_count);
                end
                MOV_eax_dw, MOV_ebx_dw, MOV_eax_ebx, MOV_ebx_eax: begin
                    mov_count = mov_count + 1;
                    $display("Time=%0t: EXECUTE MOV #%0d | opcode=%h", $time, mov_count, current_opcode);
                end
                INC_eax, INC_ebx: begin
                    inc_count = inc_count + 1;
                    $display("Time=%0t: EXECUTE INC #%0d | opcode=%h", $time, inc_count, current_opcode);
                end
                JMP_rel_short, JMP_rel_near: begin
                    jmp_count = jmp_count + 1;
                    $display("Time=%0t: EXECUTE JMP #%0d | opcode=%h", $time, jmp_count, current_opcode);
                end
                default: begin
                    other_inst_count = other_inst_count + 1;
                    $display("Time=%0t: EXECUTE OTHER #%0d | opcode=%h (%s)", 
                             $time, other_inst_count, current_opcode, opcode_name(current_opcode));
                end
            endcase
        end
    end
    
    #100;
    $display("\n=== Instruction Execution Summary ===");
    $display("NOP instructions: %0d", nop_count);
    $display("MOV instructions: %0d", mov_count);
    $display("INC instructions: %0d", inc_count);
    $display("JMP instructions: %0d", jmp_count);
    $display("Other instructions: %0d", other_inst_count);
    $display("Total instructions: %0d", nop_count + mov_count + inc_count + jmp_count + other_inst_count);
end

// Track register changes
reg [31:0] prev_eax, prev_ebx, prev_reip;

initial begin
    @(posedge rst_n);
    prev_eax = dut.EAX;
    prev_ebx = dut.EBX;
    prev_reip = dut.rEIP;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.EAX != prev_eax) begin
            $display("Time=%0t: EAX changed: %h -> %h (diff=%0d)", 
                     $time, prev_eax, dut.EAX, $signed(dut.EAX - prev_eax));
            prev_eax = dut.EAX;
        end
        
        if (dut.EBX != prev_ebx) begin
            $display("Time=%0t: EBX changed: %h -> %h (diff=%0d)", 
                     $time, prev_ebx, dut.EBX, $signed(dut.EBX - prev_ebx));
            prev_ebx = dut.EBX;
        end
        
        if (dut.rEIP != prev_reip) begin
            if (i % 10 == 0) begin  // Only log every 10th change to reduce output
                $display("Time=%0t: rEIP changed: %h -> %h", 
                         $time, prev_reip, dut.rEIP);
            end
            prev_reip = dut.rEIP;
        end
    end
end

// Queue occupancy tracking
integer max_queue_depth;
integer current_queue_depth;

initial begin
    @(posedge rst_n);
    max_queue_depth = 0;
    
    repeat(50000) begin
        @(posedge clk);
        
        if (dut.InstQueueWr_Addr >= dut.InstQueueRd_Addr) begin
            current_queue_depth = dut.InstQueueWr_Addr - dut.InstQueueRd_Addr;
        end else begin
            current_queue_depth = 16 + dut.InstQueueWr_Addr - dut.InstQueueRd_Addr;
        end
        
        if (current_queue_depth > max_queue_depth) begin
            max_queue_depth = current_queue_depth;
            $display("Time=%0t: New max queue depth: %0d", $time, max_queue_depth);
        end
    end
    
    #100;
    $display("\n=== Instruction Queue Statistics ===");
    $display("Maximum queue depth reached: %0d / 16", max_queue_depth);
end

endmodule
