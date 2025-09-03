`timescale 1ns/1ps

//this module takes in enable clock and address along with the data you are trying to read and outputs any data you are trying to write. it does this by inputting or outputting the at the specified address
module fifo_mem_sync #(
    parameter DSIZE = 8,        // data width
    parameter ASIZE = 4         // address width (DEPTH = 2^ASIZE)
)(
    input  wire                 clk,     // system clock
    input  wire                 wen,     // write enable (effective/accepted)
    input  wire                 ren,     // read enable  (effective/accepted)
    input  wire [ASIZE-1:0]     waddr,   // write address
    input  wire [ASIZE-1:0]     raddr,   // read address
    input  wire [DSIZE-1:0]     wdata,   // data in
    output reg  [DSIZE-1:0]     rdata    // data out (registered)
);

    localparam DEPTH = 1 << ASIZE;

    // memory array
    reg [DSIZE-1:0] mem [0:DEPTH-1]; // storage array (each entry DSIZE bits)

    always @(posedge clk) begin
        // write first (synchronous write)
        if (wen) begin
            mem[waddr] <= wdata;
        end

        // synchronous read (data appears one cycle after ren is asserted)
        if (ren) begin
            rdata <= mem[raddr];
        end
    end

endmodule

