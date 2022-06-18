`include "top.vh"
module top(clk, rst, sig, we, rev, addr, din, dout);
input clk, rst, sig, we, rev;
input [`logN-1:0] addr;
input [63:0] din, dout; 
fft(clk, rst, sig, we, rev, addr, din, dout);
endmodule
