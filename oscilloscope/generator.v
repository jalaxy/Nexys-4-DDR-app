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
        4'he: oData = 7'b0101101;
        4'hd: oData = 7'b1110001;
        4'hf: oData = 7'b1100011;
        default: oData = 7'b1111111;
    endcase
    else
        oData = 7'b1111111;
end
endmodule

module integer_display(input [31:0] n, input [4:0] func, input clk, input [2:0] blink, input blink_ena, output reg [7:0] anode, output [6:0] cathode);
reg [3:0] digit;
wire [31:0] digits;
integer num = 0, blink_num = 0;
reg [2:0] i = 7;
reg ena = 1;
wire cathode_ena;
assign cathode_ena = (i == blink && ena == 0) ? 0 : 1;
display7 inst(.iData(digit), .cathode_ena(cathode_ena), .oData(cathode));
assign digits[31:28] = n / 10000000 % 10;
assign digits[27:24] = n / 1000000 % 10;
assign digits[23:20] = n / 100000 % 10;
assign digits[19:16] = func;
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
        digit = digits[i * 4 + 3 -: 4];
        num = 1;
    end
    else
        num = num + 1;
end
endmodule

module display(input clk, input [4:0] btn, output [7:0] anode, output [6:0] cathode, output dp, inout sda, output scl, input [31:0] state_p);
reg change_mode = 0;

wire [31:0] f_dHz;
reg [31:0] digits = 32'b0010_0000_0000_1111_0000_0101_0000_0000;
assign f_dHz = ((((((digits[31:28] * 10 + digits[27:24]) * 10 + digits[23:20]) * 10 + 0) * 10 + digits[15:12]) * 10 + digits[11:8]) * 10 + digits[7:4]) * 10 + digits[3:0];

reg [2:0] i1 = 0;
reg [2:0] i2 = 0;
wire [2:0] i;
assign i = i1 + i2;

parameter change_times = 20_000_000;
integer btn1 = change_times, btn2 = change_times, btn3 = change_times, btn4 = change_times;
wire blink_ena;
assign blink_ena = change_mode && !btn[1] && !btn[2] && !btn[3] && !btn[4];
wire [4:0] btn_stb;

// integer state_tmp, state_n = 0;

integer_display integer_display_inst(.n(f_dHz), .func(digits[19:16]), .clk(clk), .blink(i), .blink_ena(blink_ena), .anode(anode), .cathode(cathode));
// integer_display integer_display_inst(.n(state_tmp), .clk(clk), .blink(i), .blink_ena(blink_ena), .anode(anode), .cathode(cathode));
stabilization stabilization_inst_0(.clk(clk), .origin(btn[0]), .stabilized_signal(btn_stb[0]));
stabilization stabilization_inst_1(.clk(clk), .origin(btn[1]), .stabilized_signal(btn_stb[1]));
stabilization stabilization_inst_2(.clk(clk), .origin(btn[2]), .stabilized_signal(btn_stb[2]));
stabilization stabilization_inst_3(.clk(clk), .origin(btn[3]), .stabilized_signal(btn_stb[3]));
stabilization stabilization_inst_4(.clk(clk), .origin(btn[4]), .stabilized_signal(btn_stb[4]));
DAC inst_dac(.f_dHz(f_dHz), .func(digits[19:16] - 13), .clk(clk), .scl(scl), .sda(sda));
assign dp = anode[1] & anode[7];

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

    // if (state_n == 50_000_000)
    // begin
    //     state_tmp = state_p;
    //     state_n = 1;
    // end
    // else
    //     state_n = state_n + 1;

    if (change_mode)
    begin
        if (btn_stb[2] == 1)
        begin
            if (btn2 == change_times)
            begin
                if (i == 4)
                    digits[19:16] = digits[19:16] % 3 + 13;
                else
                    digits[4 * i + 3 -: 4] = (digits[4 * i + 3 -: 4] + 9) % 10;
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
                if (i == 4)
                    digits[19:16] = (digits[19:16] + 1) % 3 + 13;
                else
                    digits[4 * i + 3 -: 4] = (digits[4 * i + 3 -: 4] + 1) % 10;
                btn4 = 1;
            end
            else
                btn4 = btn4 + 1;
        end
        else
            btn4 = change_times;
    end
end
endmodule

module DAC(input [31:0] f_dHz, input [1:0] func, input clk, output scl, inout sda);
// 100kHz
parameter N = 100_000_000 / 100_000;
integer n = 0, m = 0;
reg scl_ena = 1;
assign scl = scl_ena & ((n < N / 2) ? 0 : 1);
// sda link control
reg sda_link = 0, sda_r = 1;
assign sda = sda_link ? sda_r : 1'bz;
// states and counters
integer state = 0, i = 0, t = 0;
reg [7:0] buffer = 8'b100_1000_0;

// harmonic signal
reg [7999:0] f_h = {8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd5, 8'd5, 8'd5, 8'd5, 8'd6, 8'd6, 8'd6, 8'd6, 8'd6, 8'd7, 8'd7, 8'd7, 8'd8, 8'd8, 8'd8, 8'd8, 8'd9, 8'd9, 8'd9, 8'd10, 8'd10, 8'd10, 8'd10, 8'd11, 8'd11, 8'd11, 8'd12, 8'd12, 8'd12, 8'd13, 8'd13, 8'd14, 8'd14, 8'd14, 8'd15, 8'd15, 8'd15, 8'd16, 8'd16, 8'd17, 8'd17, 8'd17, 8'd18, 8'd18, 8'd19, 8'd19, 8'd19, 8'd20, 8'd20, 8'd21, 8'd21, 8'd22, 8'd22, 8'd22, 8'd23, 8'd23, 8'd24, 8'd24, 8'd25, 8'd25, 8'd26, 8'd26, 8'd27, 8'd27, 8'd28, 8'd28, 8'd29, 8'd29, 8'd30, 8'd30, 8'd31, 8'd31, 8'd32, 8'd32, 8'd33, 8'd33, 8'd34, 8'd35, 8'd35, 8'd36, 8'd36, 8'd37, 8'd37, 8'd38, 8'd38, 8'd39, 8'd40, 8'd40, 8'd41, 8'd41, 8'd42, 8'd43, 8'd43, 8'd44, 8'd44, 8'd45, 8'd46, 8'd46, 8'd47, 8'd47, 8'd48, 8'd49, 8'd49, 8'd50, 8'd51, 8'd51, 8'd52, 8'd53, 8'd53, 8'd54, 8'd55, 8'd55, 8'd56, 8'd56, 8'd57, 8'd58, 8'd59, 8'd59, 8'd60, 8'd61, 8'd61, 8'd62, 8'd63, 8'd63, 8'd64, 8'd65, 8'd65, 8'd66, 8'd67, 8'd67, 8'd68, 8'd69, 8'd70, 8'd70, 8'd71, 8'd72, 8'd72, 8'd73, 8'd74, 8'd75, 8'd75, 8'd76, 8'd77, 8'd78, 8'd78, 8'd79, 8'd80, 8'd81, 8'd81, 8'd82, 8'd83, 8'd84, 8'd84, 8'd85, 8'd86, 8'd87, 8'd87, 8'd88, 8'd89, 8'd90, 8'd90, 8'd91, 8'd92, 8'd93, 8'd93, 8'd94, 8'd95, 8'd96, 8'd97, 8'd97, 8'd98, 8'd99, 8'd100, 8'd100, 8'd101, 8'd102, 8'd103, 8'd104, 8'd104, 8'd105, 8'd106, 8'd107, 8'd108, 8'd108, 8'd109, 8'd110, 8'd111, 8'd112, 8'd112, 8'd113, 8'd114, 8'd115, 8'd116, 8'd116, 8'd117, 8'd118, 8'd119, 8'd119, 8'd120, 8'd121, 8'd122, 8'd123, 8'd123, 8'd124, 8'd125, 8'd126, 8'd127, 8'd127, 8'd128, 8'd129, 8'd130, 8'd131, 8'd132, 8'd132, 8'd133, 8'd134, 8'd135, 8'd136, 8'd136, 8'd137, 8'd138, 8'd139, 8'd139, 8'd140, 8'd141, 8'd142, 8'd143, 8'd143, 8'd144, 8'd145, 8'd146, 8'd147, 8'd147, 8'd148, 8'd149, 8'd150, 8'd151, 8'd151, 8'd152, 8'd153, 8'd154, 8'd155, 8'd155, 8'd156, 8'd157, 8'd158, 8'd158, 8'd159, 8'd160, 8'd161, 8'd162, 8'd162, 8'd163, 8'd164, 8'd165, 8'd165, 8'd166, 8'd167, 8'd168, 8'd168, 8'd169, 8'd170, 8'd171, 8'd171, 8'd172, 8'd173, 8'd174, 8'd174, 8'd175, 8'd176, 8'd177, 8'd177, 8'd178, 8'd179, 8'd180, 8'd180, 8'd181, 8'd182, 8'd183, 8'd183, 8'd184, 8'd185, 8'd185, 8'd186, 8'd187, 8'd188, 8'd188, 8'd189, 8'd190, 8'd190, 8'd191, 8'd192, 8'd192, 8'd193, 8'd194, 8'd194, 8'd195, 8'd196, 8'd196, 8'd197, 8'd198, 8'd199, 8'd199, 8'd200, 8'd200, 8'd201, 8'd202, 8'd202, 8'd203, 8'd204, 8'd204, 8'd205, 8'd206, 8'd206, 8'd207, 8'd208, 8'd208, 8'd209, 8'd209, 8'd210, 8'd211, 8'd211, 8'd212, 8'd212, 8'd213, 8'd214, 8'd214, 8'd215, 8'd215, 8'd216, 8'd217, 8'd217, 8'd218, 8'd218, 8'd219, 8'd219, 8'd220, 8'd220, 8'd221, 8'd222, 8'd222, 8'd223, 8'd223, 8'd224, 8'd224, 8'd225, 8'd225, 8'd226, 8'd226, 8'd227, 8'd227, 8'd228, 8'd228, 8'd229, 8'd229, 8'd230, 8'd230, 8'd231, 8'd231, 8'd232, 8'd232, 8'd233, 8'd233, 8'd233, 8'd234, 8'd234, 8'd235, 8'd235, 8'd236, 8'd236, 8'd236, 8'd237, 8'd237, 8'd238, 8'd238, 8'd238, 8'd239, 8'd239, 8'd240, 8'd240, 8'd240, 8'd241, 8'd241, 8'd241, 8'd242, 8'd242, 8'd243, 8'd243, 8'd243, 8'd244, 8'd244, 8'd244, 8'd245, 8'd245, 8'd245, 8'd245, 8'd246, 8'd246, 8'd246, 8'd247, 8'd247, 8'd247, 8'd247, 8'd248, 8'd248, 8'd248, 8'd249, 8'd249, 8'd249, 8'd249, 8'd249, 8'd250, 8'd250, 8'd250, 8'd250, 8'd251, 8'd251, 8'd251, 8'd251, 8'd251, 8'd252, 8'd252, 8'd252, 8'd252, 8'd252, 8'd252, 8'd253, 8'd253, 8'd253, 8'd253, 8'd253, 8'd253, 8'd253, 8'd254, 8'd254, 8'd254, 8'd254, 8'd254, 8'd254, 8'd254, 8'd254, 8'd254, 8'd254, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd254, 8'd254, 8'd254, 8'd254, 8'd254, 8'd254, 8'd254, 8'd254, 8'd254, 8'd254, 8'd253, 8'd253, 8'd253, 8'd253, 8'd253, 8'd253, 8'd253, 8'd252, 8'd252, 8'd252, 8'd252, 8'd252, 8'd252, 8'd251, 8'd251, 8'd251, 8'd251, 8'd251, 8'd250, 8'd250, 8'd250, 8'd250, 8'd249, 8'd249, 8'd249, 8'd249, 8'd249, 8'd248, 8'd248, 8'd248, 8'd247, 8'd247, 8'd247, 8'd247, 8'd246, 8'd246, 8'd246, 8'd245, 8'd245, 8'd245, 8'd245, 8'd244, 8'd244, 8'd244, 8'd243, 8'd243, 8'd243, 8'd242, 8'd242, 8'd241, 8'd241, 8'd241, 8'd240, 8'd240, 8'd240, 8'd239, 8'd239, 8'd238, 8'd238, 8'd238, 8'd237, 8'd237, 8'd236, 8'd236, 8'd236, 8'd235, 8'd235, 8'd234, 8'd234, 8'd233, 8'd233, 8'd233, 8'd232, 8'd232, 8'd231, 8'd231, 8'd230, 8'd230, 8'd229, 8'd229, 8'd228, 8'd228, 8'd227, 8'd227, 8'd226, 8'd226, 8'd225, 8'd225, 8'd224, 8'd224, 8'd223, 8'd223, 8'd222, 8'd222, 8'd221, 8'd220, 8'd220, 8'd219, 8'd219, 8'd218, 8'd218, 8'd217, 8'd217, 8'd216, 8'd215, 8'd215, 8'd214, 8'd214, 8'd213, 8'd212, 8'd212, 8'd211, 8'd211, 8'd210, 8'd209, 8'd209, 8'd208, 8'd208, 8'd207, 8'd206, 8'd206, 8'd205, 8'd204, 8'd204, 8'd203, 8'd202, 8'd202, 8'd201, 8'd200, 8'd200, 8'd199, 8'd199, 8'd198, 8'd197, 8'd196, 8'd196, 8'd195, 8'd194, 8'd194, 8'd193, 8'd192, 8'd192, 8'd191, 8'd190, 8'd190, 8'd189, 8'd188, 8'd188, 8'd187, 8'd186, 8'd185, 8'd185, 8'd184, 8'd183, 8'd183, 8'd182, 8'd181, 8'd180, 8'd180, 8'd179, 8'd178, 8'd177, 8'd177, 8'd176, 8'd175, 8'd174, 8'd174, 8'd173, 8'd172, 8'd171, 8'd171, 8'd170, 8'd169, 8'd168, 8'd168, 8'd167, 8'd166, 8'd165, 8'd165, 8'd164, 8'd163, 8'd162, 8'd162, 8'd161, 8'd160, 8'd159, 8'd158, 8'd158, 8'd157, 8'd156, 8'd155, 8'd155, 8'd154, 8'd153, 8'd152, 8'd151, 8'd151, 8'd150, 8'd149, 8'd148, 8'd147, 8'd147, 8'd146, 8'd145, 8'd144, 8'd143, 8'd143, 8'd142, 8'd141, 8'd140, 8'd139, 8'd139, 8'd138, 8'd137, 8'd136, 8'd136, 8'd135, 8'd134, 8'd133, 8'd132, 8'd132, 8'd131, 8'd130, 8'd129, 8'd128, 8'd128, 8'd127, 8'd126, 8'd125, 8'd124, 8'd123, 8'd123, 8'd122, 8'd121, 8'd120, 8'd119, 8'd119, 8'd118, 8'd117, 8'd116, 8'd116, 8'd115, 8'd114, 8'd113, 8'd112, 8'd112, 8'd111, 8'd110, 8'd109, 8'd108, 8'd108, 8'd107, 8'd106, 8'd105, 8'd104, 8'd104, 8'd103, 8'd102, 8'd101, 8'd100, 8'd100, 8'd99, 8'd98, 8'd97, 8'd97, 8'd96, 8'd95, 8'd94, 8'd93, 8'd93, 8'd92, 8'd91, 8'd90, 8'd90, 8'd89, 8'd88, 8'd87, 8'd87, 8'd86, 8'd85, 8'd84, 8'd84, 8'd83, 8'd82, 8'd81, 8'd81, 8'd80, 8'd79, 8'd78, 8'd78, 8'd77, 8'd76, 8'd75, 8'd75, 8'd74, 8'd73, 8'd72, 8'd72, 8'd71, 8'd70, 8'd70, 8'd69, 8'd68, 8'd67, 8'd67, 8'd66, 8'd65, 8'd65, 8'd64, 8'd63, 8'd63, 8'd62, 8'd61, 8'd61, 8'd60, 8'd59, 8'd59, 8'd58, 8'd57, 8'd56, 8'd56, 8'd55, 8'd55, 8'd54, 8'd53, 8'd53, 8'd52, 8'd51, 8'd51, 8'd50, 8'd49, 8'd49, 8'd48, 8'd47, 8'd47, 8'd46, 8'd46, 8'd45, 8'd44, 8'd44, 8'd43, 8'd43, 8'd42, 8'd41, 8'd41, 8'd40, 8'd40, 8'd39, 8'd38, 8'd38, 8'd37, 8'd37, 8'd36, 8'd36, 8'd35, 8'd35, 8'd34, 8'd33, 8'd33, 8'd32, 8'd32, 8'd31, 8'd31, 8'd30, 8'd30, 8'd29, 8'd29, 8'd28, 8'd28, 8'd27, 8'd27, 8'd26, 8'd26, 8'd25, 8'd25, 8'd24, 8'd24, 8'd23, 8'd23, 8'd22, 8'd22, 8'd22, 8'd21, 8'd21, 8'd20, 8'd20, 8'd19, 8'd19, 8'd19, 8'd18, 8'd18, 8'd17, 8'd17, 8'd17, 8'd16, 8'd16, 8'd15, 8'd15, 8'd15, 8'd14, 8'd14, 8'd14, 8'd13, 8'd13, 8'd12, 8'd12, 8'd12, 8'd11, 8'd11, 8'd11, 8'd10, 8'd10, 8'd10, 8'd10, 8'd9, 8'd9, 8'd9, 8'd8, 8'd8, 8'd8, 8'd8, 8'd7, 8'd7, 8'd7, 8'd6, 8'd6, 8'd6, 8'd6, 8'd6, 8'd5, 8'd5, 8'd5, 8'd5, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0};

always @(posedge clk)
begin
    n = n + 1;
    if (n == N)
        n = 0;
    else if (n == N / 4)
        case (state)
            default:
                begin
                    sda_link = 1;
                    sda_r = buffer[7 - i];
                end
            0: state = 0;
            1:
                begin
                    sda_link = 1;
                    sda_r = 1;
                end
            3: sda_link = 0;
            5: sda_link = 0;
        endcase
    else if (n == 3 * N / 4)
        case (state)
            default: state = state;
            0:
                begin
                    state = m > 10_000 ? 1 : 0;
                    if (state == 1)
                        m = 0;
                    else
                        m = m + 1;
                end
            1:
                begin
                    sda_r = 0;
                    state = 2;
                end
            2:
                if (i < 7)
                    i = i + 1;
                else
                begin
                    i = 0;
                    state = 3;
                end
            3:
                begin
                    buffer = 8'b0_1_00_0_0_00;
                    state = 4;
                end
            4:
                if (i < 7)
                    i = i + 1;
                else
                begin
                    i = 0;
                    state = 5;
                end
            5:
                begin
                    t = t + 1;
                    if (t * (f_dHz % 10_000)  * 9 / 1000 > 999)
                        t = 0;
                    else
                        t = t;
                    case (func) // (f_dHz / 100_000) is the first three digits of the whole number
                        default: buffer = (t * (f_dHz % 10_000) * 9 < 500_000 ? 0 : 255) * (f_dHz / 100_000) / 330;
                        2'd1: buffer = t * (f_dHz % 10_000) * 9 / 1_000 * 255 / 1_000 * (f_dHz / 100_000) / 330;
                        2'd2: buffer = f_h[t * (f_dHz % 10_000) * 9 / 1_000 * 8 + 7 -: 8] * (f_dHz / 100_000) / 330;
                    endcase
                    state = 6;
                end
            6:
                if (i < 7)
                    i = i + 1;
                else
                begin
                    i = 0;
                    state = 5;
                end
        endcase
    else
        n = n;
end
endmodule