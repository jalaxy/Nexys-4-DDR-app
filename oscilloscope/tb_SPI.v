`timescale 1ps/1ps
module tb();
reg clk = 0;
wire sck, mosi, dc, cs, rst;
wire [31:0] i;
oscilloscope inst(.clk(clk), .sck(sck), .mosi(mosi), .dc(dc), .rst(rst), .cs(cs));
integer ii;
initial
begin
    for (ii = 0; ii <= 100_000; ii = ii + 1)
    begin
        #1;
        clk = ~clk;
    end
end
endmodule