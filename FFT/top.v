`include "top.vh"
module top(clk, rst);
input clk;
input rst;
wire wea;
wire [`logN:0] addr;
wire [63:0] din;
wire [63:0] dout;
wire clk_mem;
bram_data(.wea(wea), .addra(addr), .dina(din), .douta(dout), .clka(clk_mem));
fft(clk, rst, 1'd0, addr, din, dout, wea, clk_mem);
endmodule
