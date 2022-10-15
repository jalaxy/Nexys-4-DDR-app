module divider800Hz(input I_CLK, output reg O_CLK = 0);
integer n = 1;
parameter times = 125000;
always @(posedge I_CLK)
begin
    if (n == times / 2)
        begin
            O_CLK = ~O_CLK;
            n = 1;
        end
    else n = n + 1;
end
endmodule