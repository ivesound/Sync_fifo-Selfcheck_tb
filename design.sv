`include "fifo_ctrl_sync.sv"
`include "fifo_mem_sync.sv"

`timescale 1ns/1ps

// this module is the top-level FIFO wrapper that instantiates two other modules: ctrl + mem
module fifo_sync #(
    parameter DSIZE = 8,
    parameter ASIZE = 4
)(
    input  wire                 clk,
    input  wire                 rst_n,   // active-low reset
    input  wire                 winc,    // write request (external)
    input  wire                 rinc,    // read  request (external)
    input  wire [DSIZE-1:0]     wdata,   // write data (external)
    output wire [DSIZE-1:0]     rdata,   // read  data (external)
    output wire                 wfull,   // FIFO full (external)
    output wire                 rempty   // FIFO empty (external)
);

    // internal wires between ctrl and mem
    wire [ASIZE-1:0] waddr;
    wire [ASIZE-1:0] raddr;
    wire wen_eff;
    wire ren_eff;
    wire full_reg;
    wire empty_reg;

    // Instantiate control module
    fifo_ctrl_sync #(.ASIZE(ASIZE)) ctrl (
        .clk   (clk),
        .rst_n (rst_n),
        .winc  (winc),
        .rinc  (rinc),
        .waddr (waddr),
        .raddr (raddr),
        .full  (full_reg),
        .empty (empty_reg),
        .wen   (wen_eff),
        .ren   (ren_eff)
    );

    // Instantiate memory module
    fifo_mem_sync #(.DSIZE(DSIZE), .ASIZE(ASIZE)) mem (
        .clk  (clk),
        .wen  (wen_eff),
        .ren  (ren_eff),
        .waddr(waddr),
        .raddr(raddr),
        .wdata(wdata),
        .rdata(rdata)
    );

    // map internal flags to top-level outputs (names expected by testbench)
    assign wfull  = full_reg;
    assign rempty = empty_reg;

endmodule

