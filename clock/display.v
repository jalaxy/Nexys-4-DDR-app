module display(input clk, input rst, input pause, output reg [7:0] anode, output [6:0] cathode, output reg dp);
wire [31:0] Data;
wire [7:0] dp_input;
clock clk_inst(.CLK(clk), .rst(rst), .pause(pause), .oData(Data), .dp(dp_input));

reg [2:0] i_a = 0;
reg [3:0] iData;
wire O_CLK;
divider800Hz div_inst(.I_CLK(clk), .O_CLK(O_CLK));
display7 dis_inst(.iData(iData), .oData(cathode));
always @(posedge O_CLK)
begin
    iData = {Data[i_a * 4 + 3], Data[i_a * 4 + 2], Data[i_a * 4 + 1], Data[i_a * 4]};
    dp = dp_input[i_a];
    anode = 8'b11111111;
    anode[i_a] = 0;
    i_a = i_a + 1;
end
endmodule