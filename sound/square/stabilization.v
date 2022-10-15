module stabilization(input clk, input origin, output reg stabilized_signal);
reg [31:0] down = 0;
integer times = 100_000_000 / 100;
always @(posedge clk)
begin
    if (origin == 1)
    begin
        stabilized_signal = 1;
        down = 0;
    end
    else
        down = down + 1;
    if (down == times - 1)
    begin
        stabilized_signal = 0;
        down = 0;
    end
end
endmodule