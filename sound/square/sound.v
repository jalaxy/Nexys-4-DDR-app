module sound(input [31:0] f_dHz, input clk, output reg soundbit = 0);
reg [31:0] n = 0;
//reg [31:0] f_dHz = 1_000_0;
always @(posedge clk)
begin
    n = n + 1;
    if (n >= 500_000_000 / f_dHz)
    begin
        n = 1;
        soundbit = ~soundbit;
    end
end
endmodule