`timescale 1ns/1ps

//this module takes in the read and write enable signals and incriments the read next and write next pointers to their next slot, as well read and write pointers by setting it equal to read and write next in an alwaysblock, then outputs the address of the read and write pointers for the module before to reference

// since this is a circley fifo implementation, this means that when the read next and write next pointers are equal the fifo is either full or empty. the wrap around bit helps differentiate between the two as whenever any pointer passes the last slot in the fifo, one is added to that bit meaning that when it is empty both the wraparound and address are equal and when full only the address is equal. 
module fifo_ctrl_sync #(
    parameter ASIZE = 4   // address width (DEPTH = 2^ASIZE)
)(
    input  wire             clk,
    input  wire             rst_n,   // active-low reset
    input  wire             winc,    // write increment request (external)
    input  wire             rinc,    // read  increment request (external)
    output wire [ASIZE-1:0] waddr,   // write address for memory
    output wire [ASIZE-1:0] raddr,   // read  address for memory
    output reg              full,    // FIFO full flag (registered)
    output reg              empty,   // FIFO empty flag (registered)
    output wire             wen,     // effective write enable to memory (accepted this cycle)
    output wire             ren      // effective read  enable to memory (accepted this cycle)
);

    // one extra bit for wrap-around detection (ASIZE+1)
    reg [ASIZE:0] wptr, rptr;

    // decide whether a write or read is actually accepted this cycle ("fire")
  // Use'full' and 'empty' (viewed by external logicz) and the incoming requests winc/rinc 

//Write is allowed if FIFO not full, or if it’s full but a read is also happening (which makes room).
    wire wr_fire = winc && !(full && !rinc);

 //Read is allowed if FIFO not empty, or if it’s empty but a write is also happening (which provides data).
    wire rd_fire = rinc && !(empty && !winc);

  // next pointer values
wire [ASIZE:0] wptr_next;
wire [ASIZE:0] rptr_next;
assign wptr_next = wptr + wr_fire;  
assign rptr_next = rptr + rd_fire;

    // addresses to memory are the lower ASIZE bits of the pointers
    assign waddr = wptr[ASIZE-1:0];
    assign raddr = rptr[ASIZE-1:0];

    // NOTE: wr_fire/rd_fire are control-level signals (did the operation get accepted?).wen/ren are memory-level signals (should I toggle the memory R/W ports?). keeping them separate is good design style — in case later to adjust memory timing, add pipelining, or modify how memory sees enables (without touching the control logic)
    assign wen = wr_fire;
    assign ren = rd_fire;

    // sequential update: pointers and registered flags
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr  <= 0;
            rptr  <= 0;
            full  <= 1'b0;
            empty <= 1'b1;
        end else begin
            // update pointers with accepted operations
            wptr <= wptr_next;
            rptr <= rptr_next;

            // compute flags from NEXT pointers (cycle-accurate)
            // full: write pointer next would match read pointer next in address bits, but top wrap bit different
            full  <= (wptr_next[ASIZE-1:0] == rptr_next[ASIZE-1:0]) &&
                     (wptr_next[ASIZE]     != rptr_next[ASIZE]);

            // empty: next pointers equal (no data)
            empty <= (wptr_next == rptr_next);
        end
    end

endmodule
