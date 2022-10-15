module display(input clk, input [4:0] btn, input [15:0] sw, output reg [15:0] ld, output [7:0] anode, output [6:0] cathode, output dp, output soundbit);
reg change_mode = 0;

wire [31:0] f_dHz;
reg [31:0] digits = 32'b0000_0000_0000_0000_0010_0110_0001_0110;
assign f_dHz = ((((((digits[31:28] * 10 + digits[27:24]) * 10 + digits[23:20]) * 10 + digits[19:16]) * 10 + digits[15:12]) * 10 + digits[11:8]) * 10 + digits[7:4]) * 10 + digits[3:0];

reg [2:0] i1 = 0;
reg [2:0] i2 = 0;
wire [2:0] i;
assign i = i1 + i2;

integer j, mod;
parameter change_times = 20_000_000;
integer btn1 = change_times, btn2 = change_times, btn3 = change_times, btn4 = change_times;
reg flag;
wire blink_ena;
assign blink_ena = change_mode && !btn[1] && !btn[2] && !btn[3] && !btn[4];
wire [4:0] btn_stb;
sound sound_inst(.f_dHz(f_dHz), .clk(clk), .soundbit(soundbit));
integer_display integer_display_inst(.n(f_dHz), .clk(clk), .blink(i), .blink_ena(blink_ena), .anode(anode), .cathode(cathode));
stabilization stabilization_inst_0(.clk(clk), .origin(btn[0]), .stabilized_signal(btn_stb[0]));
stabilization stabilization_inst_1(.clk(clk), .origin(btn[1]), .stabilized_signal(btn_stb[1]));
stabilization stabilization_inst_2(.clk(clk), .origin(btn[2]), .stabilized_signal(btn_stb[2]));
stabilization stabilization_inst_3(.clk(clk), .origin(btn[3]), .stabilized_signal(btn_stb[3]));
stabilization stabilization_inst_4(.clk(clk), .origin(btn[4]), .stabilized_signal(btn_stb[4]));
assign dp = anode[1];
always @(posedge btn_stb[0])
    change_mode = ~change_mode;
always @(posedge btn_stb[1])
    if (change_mode)
        i1 = i1 + 1;
always @(posedge btn_stb[3])
    if(change_mode)
        i2 = i2 - 1;
always @(posedge clk)
begin
    if (change_mode)
    begin
        if (btn_stb[2] == 1)
        begin
            if (btn2 == change_times)
            begin
                {digits[4 * i + 3], digits[4 * i + 2], digits[4 * i + 1], digits[4 * i]} = ({digits[4 * i + 3], digits[4 * i + 2], digits[4 * i + 1], digits[4 * i]} + 9) % 10;
                btn2 = 1;
            end
            else
                btn2 = btn2 + 1;
        end
        else
            btn2 = change_times;
        if (btn_stb[4] == 1)
        begin
            if (btn4 == change_times)
            begin
                {digits[4 * i + 3], digits[4 * i + 2], digits[4 * i + 1], digits[4 * i]} = ({digits[4 * i + 3], digits[4 * i + 2], digits[4 * i + 1], digits[4 * i]} + 1) % 10;
                btn4 = 1;
            end
            else
                btn4 = btn4 + 1;
        end
        else
            btn4 = change_times;
    end
end
always @(sw)
begin
    flag = 1;
    ld = 16'b0000_0000_0000_0000;
    for (j = 15; j >= 0; j = j - 1)
        if (sw[j] == 1 && flag)
        begin
            ld[j] = 1;
            flag = 0;
        end
        else flag = flag;
end
endmodule