module display7(input [3:0] iData, input cathode_ena, output reg [6:0] oData);
always @(iData)
begin
    if (cathode_ena == 1)
    case (iData)
        4'd0: oData = 7'b1000000;
        4'd1: oData = 7'b1111001;
        4'd2: oData = 7'b0100100;
        4'd3: oData = 7'b0110000;
        4'd4: oData = 7'b0011001;
        4'd5: oData = 7'b0010010;
        4'd6: oData = 7'b0000010;
        4'd7: oData = 7'b1111000;
        4'd8: oData = 7'b0000000;
        4'd9: oData = 7'b0010000;
        default: oData = 7'b1111111;
    endcase
    else
        oData = 7'b1111111;
end
endmodule
module integer_display(input [31:0] n, input clk, input [2:0] blink, input blink_ena, output reg [7:0] anode, output [6:0] cathode);
reg [3:0] digit;
wire [31:0] digits;
integer num = 0, blink_num = 0, j;
reg [2:0] i = 7;
reg ena = 1;
wire cathode_ena;
assign cathode_ena = (i == blink && ena == 0) ? 0 : 1;
display7 inst(.iData(digit), .cathode_ena(cathode_ena), .oData(cathode));
assign digits[31:28] = n / 10000000 % 10;
assign digits[27:24] = n / 1000000 % 10;
assign digits[23:20] = n / 100000 % 10;
assign digits[19:16] = n / 10000 % 10;
assign digits[15:12] = n / 1000 % 10;
assign digits[11:8] =  n / 100 % 10;
assign digits[7:4] =   n / 10 % 10;
assign digits[3:0] =   n / 1 % 10;
always @(posedge clk)
begin
    if (num == 50_000_000 / 400)
    begin
        i = i + 1;
        if (blink_ena && blink_num == 400)
        begin
            blink_num = 1;
            ena = ~ena;
        end
        else if (blink_ena)
            blink_num = blink_num + 1;
        else
        begin
            blink_num = 0;
            ena = 1;
        end
        anode = 8'b11111111;
        anode[i] = 0;
        for (j = 0; j < 4; j = j + 1)
            digit[j] = digits[i * 4 + j];
        num = 1;
    end
    else
        num = num + 1;
end
endmodule