`timescale 1ps/1ps
module tb2();
reg clk = 0, chg_ena = 0;
wire scl, sda;
integer i;
ADC inst(.clk(clk), .sw(),
    .sda(sda), .scl(scl),
    .main(), .start(), .ch(), .on(), .level(), .offset(), .data(), .chg_ena(chg_ena), .chg_fns());
initial
begin;
    for (i = 1; i <= 100000; i = i + 1)
    begin
        clk = ~clk;
        #1;
        if (i > 3)
            chg_ena = 1;
    end
end
endmodule