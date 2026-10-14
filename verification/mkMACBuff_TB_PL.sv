`timescale 1ns/1ps
module mkMACBuff_TB;

  localparam int  ADDR_DEPTH = 64;
  localparam int  ADDR_WIDTH = 6;
  localparam int  OUT_WIDTH  = 34;
  localparam int  N_ITERS    = 9;

  localparam real CLK_PERIOD = 2.0;   

  localparam real IO_DELAY   = CLK_PERIOD * 0.25;   //0.50 ns when CLK_PERIOD=2.0
  localparam real EPS = 0.0;  /* Further constrain */

  localparam real SAMPLE_DELAY = CLK_PERIOD * 0.20; 
  localparam bit  RESET_EACH_ITER = 1'b0; 
  localparam int  RESET_HOLD_CYC = 200;  
  localparam int  RESET_RELAX_CYC = 50;

  logic CLK;
  logic RESET;        
  wire  RST_N = ~RESET; 
  initial CLK = 1'b0;
  always #(CLK_PERIOD/2.0) CLK = ~CLK;


  logic EN_mac, EN_blockRead;
  logic [15:0] mac_vectA_0, mac_vectB_0;
  logic [15:0] mac_vectA_1, mac_vectB_1;
  logic [15:0] mac_vectA_2, mac_vectB_2;
  logic [15:0] mac_vectA_3, mac_vectB_3;
  // DUT <> memory
  logic         EN_writeMem;
  logic         EN_readMem;
  logic [5:0]   writeMem_addr, readMem_addr;
  logic [33:0]  writeMem_val;
  logic         RDY_blockRead;
  logic [33:0]  readMem_val;
  // DUT outputs
  logic         RDY_mac;
  logic         VALID_memVal;
  logic [33:0]  memVal_data;
  // DUT
  mkMACBuff dut (
    .CLK(CLK),
    .RST_N(RST_N),
    .EN_mac(EN_mac),
    .EN_blockRead(EN_blockRead),

    .mac_vectA_0(mac_vectA_0), .mac_vectB_0(mac_vectB_0),
    .mac_vectA_1(mac_vectA_1), .mac_vectB_1(mac_vectB_1),
    .mac_vectA_2(mac_vectA_2), .mac_vectB_2(mac_vectB_2),
    .mac_vectA_3(mac_vectA_3), .mac_vectB_3(mac_vectB_3),

    .EN_writeMem(EN_writeMem),
    .RDY_blockRead(RDY_blockRead),
    .EN_readMem(EN_readMem),
    .writeMem_addr(writeMem_addr),
    .readMem_addr(readMem_addr),
    .writeMem_val(writeMem_val),
    .readMem_val(readMem_val),

    .RDY_mac(RDY_mac),
    .VALID_memVal(VALID_memVal),
    .memVal_data(memVal_data)
  );

  int total_write_ok;
  int total_read_ok;

 
  memory_wrapper_2port #(
    .DEPTH(ADDR_DEPTH),
    .LOGDEPTH(ADDR_WIDTH),
    .WIDTH(OUT_WIDTH)
  ) mem (
    .clkA(CLK),
    .aA(readMem_addr),
    .cenA(~EN_readMem),
    .q(readMem_val),

    .clkB(CLK),
    .aB(writeMem_addr),
    .cenB(~EN_writeMem),
    .d(writeMem_val)
  );



  logic [33:0] expMAC [0:ADDR_DEPTH-1];

  int accepted_count;
  int read_count;

  bit wrote_addr [0:ADDR_DEPTH-1];
  int unique_writes;

function automatic [33:0] dot4(
  input logic [15:0] A0, B0, A1, B1, A2, B2, A3, B3
);
  logic [33:0] s0, s1, s2, s3;
  begin
    s0 = $unsigned(A0) * $unsigned(B0);
    s1 = $unsigned(A1) * $unsigned(B1);
    s2 = $unsigned(A2) * $unsigned(B2);
    s3 = $unsigned(A3) * $unsigned(B3);
    dot4 = s0 + s1 + s2 + s3;
  end
endfunction


  //WRITE monitor 
  always @(posedge CLK) begin
    if (RST_N !== 1'b1) begin
      unique_writes <= 0;
      for (int i = 0; i < ADDR_DEPTH; i++) wrote_addr[i] <= 1'b0;
    end else if (EN_writeMem === 1'b1) begin
      if ($isunknown(writeMem_addr) || $isunknown(writeMem_val)) begin
        $display("[%0t] ERROR: WRITE has X  addr=%h  data=%h", $time, writeMem_addr, writeMem_val);
      end else begin
        $display("[%0t] WRITE  addr=%0d  data=%0d", $time, writeMem_addr, writeMem_val);
        if (writeMem_val !== expMAC[writeMem_addr]) begin
          $display("  ERROR: write mismatch @addr %0d. expected %0d got %0d",
                   writeMem_addr, expMAC[writeMem_addr], writeMem_val);            
        end else total_write_ok++;
      end

      if (!wrote_addr[writeMem_addr]) begin
        wrote_addr[writeMem_addr] <= 1'b1;
        unique_writes <= unique_writes + 1;
      end
    end
  end

  //READ monitor
  mailbox #(int) rd_mbx;
  initial begin
    rd_mbx = new();
    forever begin
      int idx;
      rd_mbx.get(idx);
      #(SAMPLE_DELAY);
      if ($isunknown(memVal_data)) begin
        $display("[%0t] ERROR: READ has X idx=%0d data=%h", $time, idx, memVal_data);
      end else begin
        $display("[%0t] READ   idx=%0d  data=%0d", $time, idx, memVal_data);
        if (memVal_data !== expMAC[idx]) begin
          $display("  ERROR: read mismatch @%0d. expected %0d got %0d",
                   idx, expMAC[idx], memVal_data);
        end else total_read_ok++;
      end
    end
  end

  always @(posedge CLK) begin
    if (RST_N !== 1'b1) begin
      read_count <= 0;
    end else if (VALID_memVal === 1'b1) begin
      int idx_local;              
      idx_local = read_count;
      read_count <= read_count + 1;
      rd_mbx.put(idx_local);
    end
  end


  // Tasks
  task automatic drive_idle();
    begin
      EN_mac       = 1'b0;
      EN_blockRead = 1'b0;

      mac_vectA_0  = '0; mac_vectB_0 = '0;
      mac_vectA_1  = '0; mac_vectB_1 = '0;
      mac_vectA_2  = '0; mac_vectB_2 = '0;
      mac_vectA_3  = '0; mac_vectB_3 = '0;
    end
  endtask

  task automatic clear_write_tracking();
    begin
      unique_writes = 0;
      for (int i = 0; i < ADDR_DEPTH; i++) wrote_addr[i] = 1'b0;
    end
  endtask

  
  task automatic do_reset();
    begin
      drive_idle();
      RESET = 1'b1;
      repeat (RESET_HOLD_CYC) @(posedge CLK);

      @(negedge CLK);
      #(EPS);
      RESET = 1'b0;
      repeat (RESET_RELAX_CYC) @(posedge CLK);
      
      while (rd_mbx.num() > 0) begin
        int junk;
        rd_mbx.get(junk);
      end
    end
  endtask


  task automatic request_block_read();
    int timeout;
    begin
     
      @(posedge CLK); #(IO_DELAY + EPS);
      EN_blockRead = 1'b1;
      @(posedge CLK); #(IO_DELAY + EPS);
      EN_blockRead = 1'b0;
    end
  endtask

  task automatic run_one_iteration(input int iter);
    bit want_send;
    int timeout;


    bit        pending_valid;
    logic [33:0] pending_dot;

    begin
      $display("\n==============================");
      $display("ITERATION %0d START", iter);
      $display("==============================");

      if (RESET_EACH_ITER) do_reset();

      accepted_count = 0;
      read_count     = 0;
      clear_write_tracking();

      pending_valid = 1'b0;
      EN_mac        = 1'b0;

      timeout = 0;
      while (RDY_mac !== 1'b1) begin
        @(posedge CLK);
        timeout++;
        if (timeout > 20000) $fatal(1, "Timeout waiting for RDY_mac high at iter=%0d", iter);
      end

    
      while (accepted_count < ADDR_DEPTH) begin
        @(posedge CLK);

        if (pending_valid && (EN_mac === 1'b1) && (RDY_mac === 1'b1)) begin
          expMAC[accepted_count] = pending_dot;
          accepted_count++;
          pending_valid = 1'b0;
        end

 
        want_send = (iter == 0) ? 1'b1 : ($urandom_range(0,3) != 0);

        #(IO_DELAY + EPS);

        if (!pending_valid && want_send && (RDY_mac === 1'b1)) begin
          EN_mac = 1'b1;

        mac_vectA_0 = $urandom_range(0, 16'hFFFF);
        mac_vectB_0 = $urandom_range(0, 16'hFFFF);
        mac_vectA_1 = $urandom_range(0, 16'hFFFF);
        mac_vectB_1 = $urandom_range(0, 16'hFFFF);
        mac_vectA_2 = $urandom_range(0, 16'hFFFF);
        mac_vectB_2 = $urandom_range(0, 16'hFFFF);
        mac_vectA_3 = $urandom_range(0, 16'hFFFF);
        mac_vectB_3 = $urandom_range(0, 16'hFFFF);

          pending_dot = dot4(
            mac_vectA_0, mac_vectB_0,
            mac_vectA_1, mac_vectB_1,
            mac_vectA_2, mac_vectB_2,
            mac_vectA_3, mac_vectB_3
          );
          pending_valid = 1'b1;

          $display("[%0t] DRIVE input for idx=%0d (EN_mac=1, IO_DELAY=%0.3f ns)",
                   $time, accepted_count, IO_DELAY);
        end else begin
          EN_mac = 1'b0;
        end
      end


      @(posedge CLK); #(IO_DELAY + EPS);
      EN_mac = 1'b0;

      timeout = 0;
      while (unique_writes < ADDR_DEPTH) begin
        @(posedge CLK);
        timeout++;
        if (timeout > 60000)
          $fatal(1, "Timeout waiting for 64 unique writes (got %0d) iter=%0d",
                 unique_writes, iter);
      end
      $display("WRITE PHASE COMPLETE (64 unique addresses written).");


      timeout = 0;
      while (RDY_blockRead !== 1'b1) begin
        @(posedge CLK);
        timeout++;
        if (timeout > 20000) $fatal(1, "Timeout waiting for RDY_blockRead iter=%0d", iter);
      end


      request_block_read();


      timeout = 0;
      while (read_count < ADDR_DEPTH) begin
        @(posedge CLK);
        timeout++;
        if (timeout > 60000)
          $fatal(1, "Timeout waiting for 64 reads (got %0d) iter=%0d", read_count, iter);
      end

      $display("READ PHASE COMPLETE (64 outputs checked).");
      $display("ITERATION %0d DONE.\n", iter);

      repeat (10) @(posedge CLK);
    end
  endtask

  initial begin
    RESET = 1'b1;
    drive_idle();
    total_write_ok = 0;
    total_read_ok  = 0;
    do_reset();

    for (int it = 0; it < N_ITERS; it++) begin
      run_one_iteration(it);
    end

    $display("ALL ITERATIONS COMPLETE.");
    $display("TOTAL SUCCESSFUL WRITES: %0d", total_write_ok);
    $display("TOTAL SUCCESSFUL READS : %0d", total_read_ok);
    $display("TOTAL SUCCESSFUL R+W   : %0d", (total_write_ok + total_read_ok));
    $finish;
  end

endmodule

