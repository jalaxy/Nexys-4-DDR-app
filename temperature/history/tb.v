`timescale 1ps/1ps
module tb();
reg clk = 1;
wire sda, scl;
temperature inst(.clk(clk), .sda(sda), .scl(scl));
integer i;
initial
begin
    for (i = 0; i <= 500_000; i = i + 1)
    begin
        clk = !clk;
        #1;
    end
end
endmodule