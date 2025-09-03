`timescale 1ns/1ps
//golden model self checking testbench

module fifo_sync_tb;
  parameter DSIZE = 8;
  parameter ASIZE = 4; // depth = 16 (4^2)
  parameter DEPTH  = (1 << ASIZE); //depth = 2^ASIZE

  // Testbench signals
  reg clk, rst_n;
  reg winc, rinc;
  reg [DSIZE-1:0] wdata;
  wire [DSIZE-1:0] rdata;
  wire wfull, rempty;

  // golden reference model (software FIFO)
  //software FIFO implemented as an array + two pointers + an occupancy count. essentially “another FIFO,” but purely behavioral, used to compute the expected behavior
  
  reg [DSIZE-1:0] golden_mem [0:DEPTH-1]; //array with size depth thcan hold size per slot
  integer write_ptr, read_ptr, count; //full when count == DEPTH

  // FIFO instantiation
  fifo_sync #(.DSIZE(DSIZE), .ASIZE(ASIZE)) dut (
    .clk(clk), //On the left is port name in  DUT.On the right is signal in testbench.
    .rst_n(rst_n),
    .winc(winc),
    .rinc(rinc),
    .wdata(wdata),
    .rdata(rdata),
    .wfull(wfull),
    .rempty(rempty)
  );

  // Clock 
  always #5 clk = ~clk;

  // initialize signals
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, fifo_sync_tb);

    clk = 0;
    rst_n = 0;
    winc = 0;
    rinc = 0;
    wdata = 0;
    write_ptr = 0;
    read_ptr = 0;
    count = 0;

    #20 rst_n = 1; // release reset, #20 (with a 10 ns clock period) gives ~2 cycles of clean reset

    // Run test cases
    test_fifo();

    #200 $finish;
  end

  // Golden reference tasks
  task golden_write(input [DSIZE-1:0] data);
    begin
      if (count < DEPTH) begin
        golden_mem[write_ptr] = data;
        write_ptr = (write_ptr + 1) % DEPTH; //since we are mimicing a circley fifo implmentaion, % DEPTH allows the pointer to wrap back to the beginning (eg. depth 4 after index 3 would go back to 0)
        count = count + 1;
      end
    end
  endtask

  task golden_read(output [DSIZE-1:0] data);
    begin
      if (count > 0) begin
        data = golden_mem[read_ptr];
        read_ptr = (read_ptr + 1) % DEPTH; 
        count = count - 1;
      end
      // if empty, 'data' is left unchanged 
    end
  endtask

  // test procedure
  task test_fifo;
    integer i;
    integer extra_writes, extra_reads;
    reg [DSIZE-1:0] expected;
    reg [DSIZE-1:0] last_rdata;
    begin
      $display("Starting FIFO test...");

      // 1) write 10 values
      
      for (i = 0; i < 10; i = i + 1) begin
        @(negedge clk);  //The TB sets requests at negedge so they are stable for the DUT sampling on posedge
        if (!wfull) begin
          wdata = ($random & 8'hFF); //$random returns a 32-bit value; mask to 8 bits to match DSIZE
          winc = 1;
          golden_write(wdata);
        end
        @(negedge clk) winc = 0;
      end

      // 2) Read 5 values 
 for (i = 0; i < 5; i = i + 1) begin
        @(negedge clk);
        if (!rempty) begin
          rinc = 1;
          golden_read(expected);
          @(posedge clk);  // DUT registers rdata here
          #1;              // sample after the DUT updated internal registers
          if (rdata !== expected) begin //!== instead of != , since checks for X or Z as wel
            $display("ERROR: Expected %0d, got %0d at time %0t", expected, rdata, $time);
          end else begin
            $display("PASS: Read %0d correctly at time %0t", rdata, $time);
          end
        end
        @(negedge clk) rinc = 0;
      end

      // 3) Fill until full

      while (!wfull) begin
        @(negedge clk);
        wdata = ($random & 8'hFF);
        winc = 1;
        golden_write(wdata);
        @(negedge clk) winc = 0;
      end
      $display("FIFO is full at time %0t (golden count = %0d)", $time, count);

      // 4) overflow: try extra writes
 
      extra_writes = 3;
      for (i = 0; i < extra_writes; i = i + 1) begin
        @(negedge clk);
        wdata = ($random & 8'hFF);
        winc = 1;            // attempt write regardless of wfull
        @(negedge clk) winc = 0;
      end
      $display("Attempted %0d extra writes at time %0t (golden count should still be %0d)", extra_writes, $time, count);

      // 5) Drain FIFO to verify matches golden model 
  
      while (!rempty) begin
        @(negedge clk);
        rinc = 1;
        golden_read(expected);
        @(posedge clk); #1;
        if (rdata !== expected) begin
          $display("ERROR: Expected %0d, got %0d at time %0t", expected, rdata, $time);
        end else begin
          $display("PASS: Read %0d correctly at time %0t", rdata, $time);
        end
        @(negedge clk) rinc = 0;
      end
      $display("FIFO drained; golden count = %0d; DUT rempty=%0b at time %0t", count, rempty, $time);


      // 6) underflow: try to read when empty
      // ensure rempty stays asserted
      // ensure rdata does not change by comparing to capture last_rdata
      // capture last_rdata (stable at negedge)
      @(negedge clk);
      last_rdata = rdata;

      extra_reads = 3;
      for (i = 0; i < extra_reads; i = i + 1) begin
        @(negedge clk);
        rinc = 1;
        @(posedge clk); #1;     
        if (!rempty) begin
          $display("ERROR: Underflow - rempty deasserted during extra read attempt at time %0t", $time);
        end
        if (rdata !== last_rdata) begin
          $display("ERROR: Underflow - rdata changed unexpectedly (was %0d now %0d) at time %0t", last_rdata, rdata, $time);
        end else begin
          $display("PASS: Underflow attempt %0d did not change rdata/rempty at time %0t", i, $time);
        end
        @(negedge clk) rinc = 0;
      end
      $display("Underflow attempts completed; golden count = %0d at time %0t", count, $time);

      
      // 7) Sanity check
      @(negedge clk);
      wdata = 8'hA5;
      winc = 1;
      golden_write(wdata);
      @(negedge clk) winc = 0;

      @(negedge clk);
      if (!rempty) begin
        rinc = 1;
        golden_read(expected);
        @(posedge clk); #1;
        if (rdata !== expected) begin
          $display("ERROR: Sanity check failed. Expected %0d, got %0d at %0t", expected, rdata, $time);
        end else begin
          $display("PASS: Sanity write/read OK (%0d) at %0t", rdata, $time);
        end
        @(negedge clk) rinc = 0;
      end else begin
        $display("ERROR: Sanity check - FIFO unexpectedly empty at time %0t", $time);
      end

      $display("All tests complete.");
    end
  endtask

endmodule
