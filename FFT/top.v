`include "top.vh"
module top(clk, rst, sig, we, rev, addr, din, dout);
input clk, rst, sig, we, rev;
input [`logN-1:0] addr;
input [`CW-1:0] din;
output [`CW-1:0] dout; 
fft inst_fft(clk, rst, sig, we, rev, addr, din, dout);
endmodule
