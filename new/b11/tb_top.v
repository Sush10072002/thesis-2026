`timescale 1ns/1ps

module tb_top;

  // Clock / reset
  reg clk;
  reg rst_n;

  // DUT inputs
  reg        stbi;
  reg [5:0]  x_in;

  // DUT outputs
  wire [5:0] x_out;

  // Loop counter
  integer i;

  // Optional log file
  integer file;

  // Instantiate DUT
  // NOTE: b11 expects ACTIVE-HIGH reset, but tb uses ACTIVE-LOW rst_n
  b11 dut (
    .x_in   (x_in),
    .stbi   (stbi),
    .clock  (clk),
    .reset  (~rst_n),
    .x_out  (x_out)
  );

  // Clock generation: 10ns period
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // ----------------------------
  // Simple "coverage" counters
  // ----------------------------
  integer st_cnt [0:8];
  integer hit_spazio_0_63, hit_spazio_le26, hit_spazio_gt26;
  integer hit_mul_odd, hit_mul_even;
  integer hit_somma_add, hit_somma_sub;
  integer hit_rsum_loop, hit_rsum_exit;
  integer hit_rsot_loop, hit_rsot_exit;
  integer hit_compl_sel [0:3];
  integer hit_dataout_neg, hit_dataout_pos;

  task bump_state;
    input [3:0] s;
    begin
      if (s <= 8) st_cnt[s] = st_cnt[s] + 1;
    end
  endtask

  // Watch internal behavior each cycle (hierarchical refs)
  always @(posedge clk) begin
    bump_state(dut.stato);

    // Branch tracking (best-effort "cover all parts")
    if (dut.stato == dut.s_spazio) begin
      if (dut.r_in == 0 || dut.r_in == 63) hit_spazio_0_63 = hit_spazio_0_63 + 1;
      else if (dut.r_in <= 26)            hit_spazio_le26 = hit_spazio_le26 + 1;
      else                                 hit_spazio_gt26 = hit_spazio_gt26 + 1;
    end

    if (dut.stato == dut.s_mul) begin
      if ((dut.r_in % 2) == 1) hit_mul_odd  = hit_mul_odd + 1;
      else                      hit_mul_even = hit_mul_even + 1;
    end

    if (dut.stato == dut.s_somma) begin
      if (((dut.r_in % 4) / 2) == 1) hit_somma_add = hit_somma_add + 1;
      else                           hit_somma_sub = hit_somma_sub + 1;
    end

    if (dut.stato == dut.s_rsum) begin
      if (dut.cont1 > 26) hit_rsum_loop = hit_rsum_loop + 1;
      else                hit_rsum_exit = hit_rsum_exit + 1;
    end

    if (dut.stato == dut.s_rsot) begin
      if (dut.cont1 > 63) hit_rsot_loop = hit_rsot_loop + 1;
      else                hit_rsot_exit = hit_rsot_exit + 1;
    end

    if (dut.stato == dut.s_compl) begin
      hit_compl_sel[((dut.r_in / 4) % 4)] = hit_compl_sel[((dut.r_in / 4) % 4)] + 1;
    end

    if (dut.stato == dut.s_dataout) begin
      if (dut.cont1 < 0) hit_dataout_neg = hit_dataout_neg + 1;
      else               hit_dataout_pos = hit_dataout_pos + 1;
    end
  end

  // Random stimulus helper:
  // force values that exercise all branches frequently
  function [5:0] pick_x_in;
    input integer cyc;
    integer r;
    begin
      r = $random;

      // Periodically force corner/branch-driving values
      if (cyc % 97  == 0)       pick_x_in = 6'd0;      // triggers spazio special (0)
      else if (cyc % 101 == 0)  pick_x_in = 6'd63;     // triggers spazio special (63)
      else if (cyc % 89  == 0)  pick_x_in = 6'd26;     // <=26 path
      else if (cyc % 113 == 0)  pick_x_in = 6'd27;     // >26 path
      else                      pick_x_in = r[5:0];    // general random
    end
  endfunction

  // Main test
  initial begin
    // init counters
    for (i = 0; i <= 8; i = i + 1) st_cnt[i] = 0;
    hit_spazio_0_63 = 0; hit_spazio_le26 = 0; hit_spazio_gt26 = 0;
    hit_mul_odd = 0; hit_mul_even = 0;
    hit_somma_add = 0; hit_somma_sub = 0;
    hit_rsum_loop = 0; hit_rsum_exit = 0;
    hit_rsot_loop = 0; hit_rsot_exit = 0;
    hit_compl_sel[0] = 0; hit_compl_sel[1] = 0; hit_compl_sel[2] = 0; hit_compl_sel[3] = 0;
    hit_dataout_neg = 0; hit_dataout_pos = 0;

    // init signals
    rst_n = 1'b0;
    stbi  = 1'b1;
    x_in  = 6'd0;

    // optional logging
    file = $fopen("b11_simulation_log.txt", "w");
    if (file) begin
      $fwrite(file, "cycle\tstbi\tx_in\tx_out\tstato\tr_in\tcont\tcont1\n");
    end

    // Apply reset
    #20;
    rst_n = 1'b1;
    #10;

    $display("\n=== Starting b11: 50k cycle simulation w/ constrained random inputs ===\n");

    for (i = 0; i < 50000; i = i + 1) begin
      @(posedge clk);

      // Occasionally pulse reset mid-run to re-hit reset behavior
      if (i != 0 && (i % 12000 == 0)) begin
        rst_n <= 1'b0;
      end else if (i != 0 && (i % 12000 == 2)) begin
        rst_n <= 1'b1;
      end

      // Drive x_in with targeted random
      x_in <= pick_x_in(i);

      // Drive stbi to ensure we both "hold" in s_datain and advance to s_spazio
      // Mostly 1, sometimes 0 to push state machine forward.
      if (i % 7 == 0)       stbi <= 1'b0;          // regularly allow transition out of s_datain
      else if (i % 23 == 0) stbi <= 1'b0;          // extra chances
      else                  stbi <= $random[0];    // randomize too

      // Log a compact snapshot
      if (file) begin
        $fwrite(file, "%0d\t%b\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\n",
                i, stbi, x_in, x_out, dut.stato, dut.r_in, dut.cont, dut.cont1);
      end

      // Periodic progress print
      if (i % 2000 == 0) begin
        $display("T=%0t | cycle=%0d | stato=%0d | stbi=%b x_in=%0d x_out=%0d cont=%0d cont1=%0d",
                 $time, i, dut.stato, stbi, x_in, x_out, dut.cont, dut.cont1);
      end
    end

    if (file) $fclose(file);

    $display("\n=== Simulation Complete ===");
    $display("Total cycles run: %0d", i);

    // Coverage summary (did we hit everything?)
    $display("\n--- State visit counts ---");
    $display("s_reset  : %0d", st_cnt[dut.s_reset]);
    $display("s_datain : %0d", st_cnt[dut.s_datain]);
    $display("s_spazio : %0d", st_cnt[dut.s_spazio]);
    $display("s_mul    : %0d", st_cnt[dut.s_mul]);
    $display("s_somma  : %0d", st_cnt[dut.s_somma]);
    $display("s_rsum   : %0d", st_cnt[dut.s_rsum]);
    $display("s_rsot   : %0d", st_cnt[dut.s_rsot]);
    $display("s_compl  : %0d", st_cnt[dut.s_compl]);
    $display("s_dataout: %0d", st_cnt[dut.s_dataout]);

    $display("\n--- Branch hits (best effort) ---");
    $display("spazio: r_in==0 or 63 : %0d", hit_spazio_0_63);
    $display("spazio: r_in<=26      : %0d", hit_spazio_le26);
    $display("spazio: r_in>26       : %0d", hit_spazio_gt26);

    $display("mul: odd  : %0d | even : %0d", hit_mul_odd, hit_mul_even);
    $display("somma: add: %0d | sub  : %0d", hit_somma_add, hit_somma_sub);

    $display("rsum: loop: %0d | exit : %0d", hit_rsum_loop, hit_rsum_exit);
    $display("rsot: loop: %0d | exit : %0d", hit_rsot_loop, hit_rsot_exit);

    $display("compl sel ( (r_in/4)%%4 ): 0:%0d 1:%0d 2:%0d 3:%0d",
             hit_compl_sel[0], hit_compl_sel[1], hit_compl_sel[2], hit_compl_sel[3]);

    $display("dataout: cont1<0:%0d | cont1>=0:%0d", hit_dataout_neg, hit_dataout_pos);

    $display("\nCheck 'b11_simulation_log.txt' and 'tb_top.vcd' for debug.\n");
    $finish;
  end

  // Waveform dump
  initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
    // dump DUT internals too
    $dumpvars(0, dut.stato);
    $dumpvars(0, dut.r_in);
    $dumpvars(0, dut.cont);
    $dumpvars(0, dut.cont1);
    $dumpvars(0, dut.x_out);
  end

endmodule

