module ADC(clk, sw,
    sda, scl,
    main, start, ch, on, level, offset, data, chg_ena, chg_fns);
input clk;
input [15:0] sw;
inout sda;
output scl;
input main;
inout start;
input [2:0] ch;
input on;
input [7:0] level;
input [7:0] offset;
output reg [3191:0] data;
input chg_ena;
output reg chg_fns = 0;

reg start_r = 0;
assign start = main ? start_r : 1'bz;

// I2C clock frequency: 100kHz -> 10us
// conversion rate: 100kHz / 9 -> 11.1kHz
parameter N = 100_000_000 / 100_000;
integer n = 0;
assign scl = (n < N / 2) ? 0 : 1;

// sda link control
reg sda_link = 0, sda_r = 1;
assign sda = sda_link ? sda_r : 1'bz;

// states and counters
integer state = 0, i = 0, j = 0, t = 0;

// sample time & scale
wire [8:0] N_sample; // t_div = 10ms * N_sample
integer i_sample = 1;
assign N_sample = sw[2] ? 8'd10 : (sw[1] ? 8'd5 : (sw[0] ? 8'd2 : 8'd1));
wire [8:0] div; // divisions of every 2 volts
assign div = sw[5] ? 8'd1 : (sw[4] ? 8'd2 : sw[3] ? 8'd4 : 8'd10); // U_div = 2 / div = {2, 1, 0.5, 0.2};

// 1-byte buffer
reg [7:0] buffer, pre, cur;
reg first = 1;
wire [7:0] pixel;
assign pixel = buffer * 165 * div / 512 < 299 - offset ? buffer * 165 * div / 512 : 299 - offset;

always @(posedge clk)
begin
    if (chg_ena)
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
                5:
                    begin
                        sda_link = 1;
                        sda_r = 0;
                    end
                6: sda_link = 1;
                8: sda_link = 0;
                9: state = 9;
                10:
                    begin
                        sda_link = 1;
                        sda_r = 0;
                    end
                11: state = 11;
                12: state = 12;
            endcase
        else if (n == 3 * N / 4)
            case (state)
            default: state = state;
                0: state = 1;
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
                    if (on)
                    begin
                        buffer = {6'b0_0_00_0_0, ch};
                        state = 4;
                    end
                    else
                        state = 12;
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
                        sda_r = 1;
                        state = 6;
                    end
                6: 
                    begin
                        sda_r = 0;
                        buffer = 8'b100_1000_1;
                        state = 7;
                    end
                7:
                    if (i < 7)
                        i = i + 1;
                    else
                    begin
                        i = 0;
                        state = 8;
                    end
                8: state = 9;
                9:
                    begin
                        buffer[7 - i] = sda;
                        if (i < 7)
                            i = i + 1;
                        else
                        begin
                            i = 0;
                            state = 10;
                        end
                    end
                10:
                    begin
                        sda_r = 1;
                        state = 11;
                    end
                11: // delay
                    if (i_sample < N_sample)
                    begin
                        i_sample = i_sample + 1;
                        state = 6;
                    end
                    else
                    begin
                        i_sample = 1;
                        state = 6;
                        if (first)
                        begin
                            pre = pixel;
                            cur = pixel;
                            first = 0;
                        end
                        else if (main && (j < 799 && (pre > level - offset || cur <= level - offset)) || !main && !start)
                        begin
                            j = j + 1;
                            pre = cur;
                            cur = pixel;
                        end
                        else if (main && !start)
                            start_r = 1;
                        else if (t < 399)
                        begin
                            data[8 * t + 7 -: 8] = pixel;
                            t = t + 1;
                        end
                        else
                        begin
                            j = 0;
                            t = 0;
                            buffer = 8'b100_1000_0;
                            first = 1;
                            state = 12;
                        end
                    end
                12:
                    begin
                        chg_fns = 1;
                        start_r = 0;
                    end
            endcase
        else
            n = n;
    end
    else
    begin
        n = 0;
        chg_fns = 0;
        state = 0;
        buffer = 8'b100_1000_0;
    end
end
endmodule



module oscilloscope(
    clk, sw, ld, test,
    sck, mosi, dc, rst, cs, led,
    sda1, scl1, sda2, scl2,
    btn, anode, cathode, dp,
    scl_o, sda_o,
    tsda, tscl);
input clk;
input [15:0] sw;
output [15:0] ld;
output [1:0] test;
output sck;
output reg mosi;
output reg dc;
output reg rst = 1;
output reg cs = 1;
output led;
inout sda1, sda2;
output scl1, scl2;
inout tsda;
output tscl;

input [4:0] btn;
output [7:0] anode;
output [6:0] cathode;
output dp;
output scl_o;
inout sda_o;

// principles:
// sck_ena & cs -> N / 4
// states -> 3 * N / 4

// ST7796S SPI serial clock cycle: 66ns(W), 150ns(R)
// Here is 100ns for 10MHz
parameter N = 100_000_000 / 10_000_000;
integer n = 0, m = 0;
reg sck_ena = 0;
assign sck = (n < N / 2 ? 0 : 1) & sck_ena;

// states and counters
integer state = 0, state_tmp;
integer i = 0, j = 0, k = 0, t = 0, i_loop = 0;

// 1-byte buffer
reg [7:0] buffer;

// led
reg led_ena = 0;
assign led = sw[15] & led_ena;

// colors
reg [17:0] color;
parameter white    = 18'b111111_111111_111111;
parameter grey     = 18'b110000_110000_110000;
parameter black    = 18'b000000_000000_000000;
parameter red      = 18'b111111_000000_000000;
parameter green    = 18'b000000_111111_000000;
parameter blue     = 18'b000000_000000_111111;
parameter magenta  = 18'b111111_000000_111111;
reg word_ena = 0;
wire [0:83] word_mtrx;
integer word_i, word_x, word_y;
wire [15:0] word_xs, word_xe, word_ys, word_ye;
assign word_xs = 16'd50 + 16'd12 * word_x[15:0];
assign word_xe = 16'd61 + 16'd12 * word_x[15:0];
assign word_ys = 16'd415 + 16'd7 * word_y[15:0];
assign word_ye = 16'd421 + 16'd7 * word_y[15:0];
words words_inst(.i(word_i), .mtrx(word_mtrx));

// colomn and row
reg [15:0] xs, xe, ys, ye;

// channels
reg [3191:0] ch1 = 3192'b0;
reg [3191:0] ch2 = 3192'b0;
wire [3191:0] ch1_next, ch2_next;
reg ch1_on = 0, ch2_on = 0, ch1_on_next, ch2_on_next;
reg chg_ena = 0;
wire chg_fns1, chg_fns2;
reg [8:0] level = 199, level_next = 199;
reg [8:0] offset1 = 149, offset1_next = 149, offset1_next_next = 149;
reg [8:0] offset2 = 149, offset2_next = 149, offset2_next_next = 149;
reg [8:0] mea_t = 199, mea_v= 29, mea_t_next = 199, mea_v_next = 29;

// temporary variable
wire [32:0] t_pre;
assign t_pre = t == 0 ? 0 : t - 1;
integer x_tmp, xs_tmp, xe_tmp;
wire [31:0] word_numt, word_numv;
assign word_numt = (mea_t < 199 ? 199 - mea_t : mea_t - 199) * (sw[2] ? 10 : (sw[1] ? 5 : (sw[0] ? 2 : 1))) / 5;
assign word_numv = (mea_v < 149 ? 149 - mea_v : mea_v - 149) * (sw[5] ? 20 : (sw[4] ? 10 : (sw[3] ? 5 : 2))) / 5;

// 50Hz standard test square signal
integer i_test = 0;
assign test = i_test < 1_000_000 ? 2'b10 : 2'b01;

// bus to sync
wire start, on_tmp;
assign on_tmp = !ch1_on_next & ch2_on_next;

// temperature
wire [15:0] tmp;

ADC ADC_inst_1(.clk(clk), .sw(sw), .sda(sda1), .scl(scl1), .ch(2'b00), .level(level), .offset(offset1_next), .data(ch1_next), .chg_ena(chg_ena), .chg_fns(chg_fns1), .main(ch1_on_next), .start(start), .on(ch1_on_next));
ADC ADC_inst_2(.clk(clk), .sw(sw), .sda(sda2), .scl(scl2), .ch(2'b00), .level(level), .offset(offset2_next), .data(ch2_next), .chg_ena(chg_ena), .chg_fns(chg_fns2), .main(on_tmp), .start(start), .on(ch2_on_next));
temperature tmp_inst(.clk(clk), .sda(tsda), .scl(tscl), .tmp_r(tmp));

display inst(.clk(clk), .btn(btn), .anode(anode), .cathode(cathode), .dp(dp), .sda(sda_o), .scl(scl_o), .state_p(state));

// sw[2:0] changed
reg t_chg1 = 0, t_chg2 = 0;
wire t_chg;
assign t_chg = t_chg1 ^ t_chg2; 
always @(sw[2:0])
    t_chg1 = ~t_chg2;

// sw[5:3] changed
reg v_chg1 = 0, v_chg2 = 0;
wire v_chg;
assign v_chg = v_chg1 ^ v_chg2;
always @(sw[5:3])
    v_chg1 = ~v_chg2;

always @(posedge clk)
begin
    if (i_test == 2_000_000)
        i_test = 1;
    else
        i_test = i_test + 1;

    if (m == 10_000_000)
    begin
        m = 0;
        if (sw[10])
            mea_t_next = (mea_t_next + sw[7] - sw[6] < 0 || mea_t_next + sw[7] - sw[6] > 398) ? mea_t_next : mea_t_next + sw[7] - sw[6];
        else if (sw[11])
            mea_v_next = (mea_v_next + sw[7] - sw[6] < 0 || mea_v_next + sw[7] - sw[6] > 298) ? mea_v_next : mea_v_next + sw[7] - sw[6];
        else if (sw[9])
            if (!sw[8])
                offset1_next_next = (offset1_next_next + sw[7] - sw[6] < 0 || offset1_next_next + sw[7] - sw[6] > 298) ? offset1_next_next : offset1_next_next + sw[7] - sw[6];
            else
                offset2_next_next = (offset2_next_next + sw[7] - sw[6] < 0 || offset2_next_next + sw[7] - sw[6] > 298) ? offset2_next_next : offset2_next_next + sw[7] - sw[6];
        else
            level_next = (level_next + sw[7] - sw[6] < 0 || level_next + sw[7] - sw[6] > 298) ? level_next : level_next + sw[7] - sw[6];
    end
    else
        m = m + 1;

    if (n == N)
        n = 0;
    else if (n == N / 4)
        case (state)
            default:
                begin
                    sck_ena = 1;
                    cs = 0;
                    mosi = buffer[7 - i];
                end
            0: begin sck_ena = 0; cs = 1; end
            2: begin sck_ena = 0; cs = 1; end
            8: begin sck_ena = 0; cs = 1; end
            23: begin sck_ena = 0; cs = 1; end
            24: begin sck_ena = 0; cs = 1; end
            25: begin sck_ena = 0; cs = 1; end
            26: begin sck_ena = 0; cs = 1; end
            27: begin sck_ena = 0; cs = 1; end
            28: begin sck_ena = 0; cs = 1; end
            29: begin sck_ena = 0; cs = 1; end
            30: begin sck_ena = 0; cs = 1; end
            31: begin sck_ena = 0; cs = 1; end
            32: begin sck_ena = 0; cs = 1; end
            33: begin sck_ena = 0; cs = 1; end
            34: begin sck_ena = 0; cs = 1; end
            35: begin sck_ena = 0; cs = 1; end
            36: begin sck_ena = 0; cs = 1; end
            37: begin sck_ena = 0; cs = 1; end
            38: begin sck_ena = 0; cs = 1; end
            39: begin sck_ena = 0; cs = 1; end
            40: begin sck_ena = 0; cs = 1; end
            41: begin sck_ena = 0; cs = 1; end
            42: begin sck_ena = 0; cs = 1; end
            43: begin sck_ena = 0; cs = 1; end
            44: begin sck_ena = 0; cs = 1; end
            45: begin sck_ena = 0; cs = 1; end
            46: begin sck_ena = 0; cs = 1; end
            47: begin sck_ena = 0; cs = 1; end
            48: begin sck_ena = 0; cs = 1; end
            49: begin sck_ena = 0; cs = 1; end
            50: begin sck_ena = 0; cs = 1; end
            51: begin sck_ena = 0; cs = 1; end
            52: begin sck_ena = 0; cs = 1; end
            53: begin sck_ena = 0; cs = 1; end
            54: begin sck_ena = 0; cs = 1; end
            55: begin sck_ena = 0; cs = 1; end
            56: begin sck_ena = 0; cs = 1; end
            57: begin sck_ena = 0; cs = 1; end
            58: begin sck_ena = 0; cs = 1; end
            59: begin sck_ena = 0; cs = 1; end
            60: begin sck_ena = 0; cs = 1; end
            61: begin sck_ena = 0; cs = 1; end
            62: begin sck_ena = 0; cs = 1; end
            63: begin sck_ena = 0; cs = 1; end
            64: begin sck_ena = 0; cs = 1; end
            65: begin sck_ena = 0; cs = 1; end
            66: begin sck_ena = 0; cs = 1; end
            67: begin sck_ena = 0; cs = 1; end
            68: begin sck_ena = 0; cs = 1; end
            69: begin sck_ena = 0; cs = 1; end
            70: begin sck_ena = 0; cs = 1; end
            71: begin sck_ena = 0; cs = 1; end
            72: begin sck_ena = 0; cs = 1; end
            73: begin sck_ena = 0; cs = 1; end
            74: begin sck_ena = 0; cs = 1; end
            75: begin sck_ena = 0; cs = 1; end
            76: begin sck_ena = 0; cs = 1; end
            77: begin sck_ena = 0; cs = 1; end
            78: begin sck_ena = 0; cs = 1; end
            79: begin sck_ena = 0; cs = 1; end
            80: begin sck_ena = 0; cs = 1; end
            81: begin sck_ena = 0; cs = 1; end
            82: begin sck_ena = 0; cs = 1; end
            83: begin sck_ena = 0; cs = 1; end
            84: begin sck_ena = 0; cs = 1; end
            85: begin sck_ena = 0; cs = 1; end
            86: begin sck_ena = 0; cs = 1; end
            87: begin sck_ena = 0; cs = 1; end
            88: begin sck_ena = 0; cs = 1; end
            89: begin sck_ena = 0; cs = 1; end
            90: begin sck_ena = 0; cs = 1; end
            91: begin sck_ena = 0; cs = 1; end
            92: begin sck_ena = 0; cs = 1; end
            93: begin sck_ena = 0; cs = 1; end
            94: begin sck_ena = 0; cs = 1; end
            95: begin sck_ena = 0; cs = 1; end
            96: begin sck_ena = 0; cs = 1; end
            97: begin sck_ena = 0; cs = 1; end
            98: begin sck_ena = 0; cs = 1; end
            99: begin sck_ena = 0; cs = 1; end
            100: begin sck_ena = 0; cs = 1; end
            101: begin sck_ena = 0; cs = 1; end
            102: begin sck_ena = 0; cs = 1; end
            103: begin sck_ena = 0; cs = 1; end
            104: begin sck_ena = 0; cs = 1; end
            105: begin sck_ena = 0; cs = 1; end
            106: begin sck_ena = 0; cs = 1; end
            107: begin sck_ena = 0; cs = 1; end
            108: begin sck_ena = 0; cs = 1; end
            109: begin sck_ena = 0; cs = 1; end
            110: begin sck_ena = 0; cs = 1; end
            111: begin sck_ena = 0; cs = 1; end
            112: begin sck_ena = 0; cs = 1; end
            113: begin sck_ena = 0; cs = 1; end
            114: begin sck_ena = 0; cs = 1; end
            115: begin sck_ena = 0; cs = 1; end
            116: begin sck_ena = 0; cs = 1; end
            117: begin sck_ena = 0; cs = 1; end
            118: begin sck_ena = 0; cs = 1; end
            119: begin sck_ena = 0; cs = 1; end
            120: begin sck_ena = 0; cs = 1; end
            121: begin sck_ena = 0; cs = 1; end
            122: begin sck_ena = 0; cs = 1; end
            123: begin sck_ena = 0; cs = 1; end
            124: begin sck_ena = 0; cs = 1; end
            125: begin sck_ena = 0; cs = 1; end
            126: begin sck_ena = 0; cs = 1; end
            127: begin sck_ena = 0; cs = 1; end
            128: begin sck_ena = 0; cs = 1; end
            129: begin sck_ena = 0; cs = 1; end
            130: begin sck_ena = 0; cs = 1; end
            131: begin sck_ena = 0; cs = 1; end
        endcase
    else if (n == 3 * N / 4)
        case (state)
            default: state = state;
            0: // hardware reset
                begin
                    i = 0;
                    if (j == 2)
                    begin
                        j = 0;
                        state = 1;
                        // software reset
                        buffer = 8'h01;
                        dc = 0;
                    end
                    else
                    begin
                        j = j + 1;
                        rst = ~rst;
                    end
                end
            1:
                if (i == 7)
                begin
                    state = 2;
                    i = 0;
                end
                else
                    i = i + 1;
            2: // delay for 120ms
                if (i == 120_000_0)
                begin
                    i = 0;
                    state = 3;
                    // sleep out
                    buffer = 8'h11;
                    dc = 0;
                end
                else
                    i = i + 1;
            3:
                if (i == 7)
                begin
                    state = 4;
                    i = 0;
                    // access control
                    buffer = 8'h36;
                    dc = 0;
                end
                else
                    i = i + 1;
            4:
                if (i == 7)
                begin
                    state = 5;
                    i = 0;
                    buffer = 8'b11000000;
                    dc = 1;
                end
                else
                    i = i + 1;
            5:
                if (i == 7)
                begin
                    state = 6;
                    i = 0;
                    // write memory
                    buffer = 8'h2c;
                    dc = 0;
                end
                else
                    i = i + 1;
            6:
                if (j == 320 * 480 * 3 && i == 7)
                begin
                    state = 7;
                    j = 0;
                    i = 0;
                    // display on
                    buffer = 8'h29;
                    dc = 0;
                    led_ena = 1;
                end
                else if (i == 7)
                begin
                    j = j + 1;
                    i = 0;
                    buffer = 8'hff;
                    dc = 1;
                end
                else
                    i = i + 1;
            7:
                if (i == 7)
                begin
                    state = 23;
                    i = 0;
                end
                else
                    i = i + 1;
            8:
                begin
                    state = 9;
                    buffer = 8'h2a;
                    xs = word_ena ? word_xs : xs;
                    xe = word_ena ? word_xe : xe;
                    ys = word_ena ? word_ys : ys;
                    ye = word_ena ? word_ye : ye;
                    dc = 0;
                end
            9:
                if (i == 7)
                begin
                    state = 10;
                    i = 0;
                    buffer = xs[15:8];
                    dc = 1;
                end
                else
                    i = i + 1;
            10:
                if (i == 7)
                begin
                    state = 11;
                    i = 0;
                    buffer = xs[7:0];
                    dc = 1;
                end
                else
                    i = i + 1;
            11:
                if (i == 7)
                begin
                    state = 12;
                    i = 0;
                    buffer = xe[15:8];
                    dc = 1;
                end
                else
                    i = i + 1;
            12:
                if (i == 7)
                begin
                    state = 13;
                    i = 0;
                    buffer = xe[7:0];
                    dc = 1;
                end
                else
                    i = i + 1;
            13:
                if (i == 7)
                begin
                    state = 14;
                    i = 0;
                    buffer = 8'h2b;
                    dc = 0;
                end
                else
                    i = i + 1;
            14:
                if (i == 7)
                begin
                    state = 15;
                    i = 0;
                    buffer = ys[15:8];
                    dc = 1;
                end
                else
                    i = i + 1;
            15:
                if (i == 7)
                begin
                    state = 16;
                    i = 0;
                    buffer = ys[7:0];
                    dc = 1;
                end
                else
                    i = i + 1;
            16:
                if (i == 7)
                begin
                    state = 17;
                    i = 0;
                    buffer = ye[15:8];
                    dc = 1;
                end
                else
                    i = i + 1;
            17:
                if (i == 7)
                begin
                    state = 18;
                    i = 0;
                    buffer = ye[7:0];
                    dc = 1;
                end
                else
                    i = i + 1;
            18:
                if (i == 7)
                begin
                    state = 19;
                    i = 0;
                    buffer = 8'h2c;
                    dc = 0;
                end
                else
                    i = i + 1;
            19:
                if (i == 7)
                begin
                    state = 20;
                    i = 0;
                    buffer = word_ena && !word_mtrx[j] ? 8'hff : {color[5:0], 2'b00};
                    dc = 1;
                end
                else
                    i = i + 1;
            20:
                if (i == 7)
                begin
                    state = 21;
                    i = 0;
                    buffer = word_ena && !word_mtrx[j] ? 8'hff : {color[11:6], 2'b00};
                    dc = 1;
                end
                else
                    i = i + 1;
            21:
                if (j == {16'd0, xe - xs + 1} * {16'd0, ye - ys + 1} && i == 7)
                begin
                    i = 0;
                    j = 0;
                    state = 22;
                    buffer = word_ena && !word_mtrx[j] ? 8'hff : {color[17:12], 2'b00};
                end
                else if (i == 7)
                begin
                    state = 19;
                    i = 0;
                    buffer = word_ena && !word_mtrx[j] ? 8'hff : {color[17:12], 2'b00};
                    dc = 1;
                    j = j + 1;
                end
                else
                    i = i + 1;
            22:
                if (i == 7)
                begin
                    word_ena = 0;
                    state = state_tmp;
                    i = 0;
                end
                else
                    i = i + 1;
            23:
                begin
                    xs = 16'd59; xe = 16'd59;
                    ys = 16'd9; ye = 16'd409;
                    color = grey;
                    state = 8; state_tmp = 24;
                end
            24:
                begin
                    xs = 16'd109; xe = 16'd109;
                    ys = 16'd9; ye = 16'd409;
                    color = grey;
                    state = 8; state_tmp = 25;
                end
            25:
                begin
                    xs = 16'd209; xe = 16'd209;
                    ys = 16'd9; ye = 16'd409;
                    color = grey;
                    state = 8; state_tmp = 26;
                end
            26:
                begin
                    xs = 16'd259; xe = 16'd259;
                    ys = 16'd9; ye = 16'd409;
                    color = grey;
                    state = 8; state_tmp = 27;
                end
            27:
                begin
                    xs = 16'd9; xe = 16'd309;
                    ys = 16'd59; ye = 16'd59;
                    color = grey;
                    state = 8; state_tmp = 28;
                end
            28:
                begin
                    xs = 16'd9; xe = 16'd309;
                    ys = 16'd109; ye = 16'd109;
                    color = grey;
                    state = 8; state_tmp = 29;
                end
            29:
                begin
                    xs = 16'd9; xe = 16'd309;
                    ys = 16'd159; ye = 16'd159;
                    color = grey;
                    state = 8; state_tmp = 30;
                end
            30:
                begin
                    xs = 16'd9; xe = 16'd309;
                    ys = 16'd259; ye = 16'd259;
                    color = grey;
                    state = 8; state_tmp = 31;
                end
            31:
                begin
                    xs = 16'd9; xe = 16'd309;
                    ys = 16'd309; ye = 16'd309;
                    color = grey;
                    state = 8; state_tmp = 32;
                end
            32:
                begin
                    xs = 16'd9; xe = 16'd309;
                    ys = 16'd359; ye = 16'd359;
                    color = grey;
                    state = 8; state_tmp = 33;
                end
            33:
                begin
                    xs = 16'd9; xe = 16'd9;
                    ys = 16'd9; ye = 16'd409;
                    color = black;
                    state = 8; state_tmp = 34;
                end
            34:
                begin
                    xs = 16'd9; xe = 16'd309;
                    ys = 16'd409; ye = 16'd409;
                    color = black;
                    state = 8; state_tmp = 35;
                end
            35:
                begin
                    xs = 16'd309; xe = 16'd309;
                    ys = 16'd9; ye = 16'd409;
                    color = black;
                    state = 8; state_tmp = 36;
                end
            36:
                begin
                    xs = 16'd9; xe = 16'd309;
                    ys = 16'd9; ye = 16'd9;
                    color = black;
                    state = 8; state_tmp = 37;
                end
            37:
                begin
                    xs = 16'd9; xe = 16'd309;
                    ys = 16'd209; ye = 16'd209;
                    color = black;
                    state = 8; state_tmp = 38;
                end
            38:
                begin
                    xs = 16'd159; xe = 16'd159;
                    ys = 16'd9; ye = 16'd409;
                    color = black;
                    state = 8; state_tmp = 60;
                end
            39:
                begin
                    ch1_on_next = sw[14];
                    ch2_on_next = sw[13];
                    chg_ena = 1;
                    if (t_chg)
                    begin
                        state = 84;
                        t_chg2 = t_chg1;
                    end
                    else
                        state = 40;
                end
            40:
                if (chg_fns1 && chg_fns2)
                begin
                    if (v_chg)
                    begin
                        state = 87;
                        v_chg2 = v_chg1;
                    end
                    else
                        state = 41;
                    chg_ena = 0;
                end
                else
                    state = 40;
            41:
                if (t < 399)
                    if (ch1_on && ch1[8 * t_pre + 7 -: 8] + offset1 < 299 && ch1[8 * t + 7 -: 8] + offset1 < 299)
                    begin
                        xs = 308 - offset1 - ch1[8 * t_pre + 7 -: 8];
                        xe = 308 - offset1 - ch1[8 * t + 7 -: 8];
                        if (xs > xe)
                        begin
                            x_tmp = xs;
                            xs = xe;
                            xe = x_tmp;
                        end
                        ys = 10 + t; ye = 10 + t;
                        if (ys == 209)
                            color = black;
                        else if (ys % 50 == 9)
                            color = grey;
                        else
                            color = white;
                        state = 8;
                        state_tmp = 42;
                        xs_tmp = xs; xe_tmp = xe;
                    end
                    else
                        state = 43;
                else
                begin // the last thing
                    t = 0;
                    ch1_on = ch1_on_next;
                    ch2_on = ch2_on_next;
                    // for (i_loop = 0; i_loop < 3192; i_loop = i_loop + 1)
                    // begin
                    //     ch1[i_loop] = ch1_next[i_loop];
                    //     ch2[i_loop] = ch2_next[i_loop];
                    // end
                    ch1 = ch1_next;
                    ch2 = ch2_next;
                    state = 48;
                end
            42:
                if (ys % 50 != 9 && xs_tmp <= 59 && xe_tmp >= 59)
                begin
                    xs = 59; xe = 59;
                    color = grey;
                    state = 8;
                    state_tmp = 42;
                    xs_tmp = 60;
                end
                else if (ys % 50 != 9 && xs_tmp <= 109 && xe_tmp >= 59)
                begin
                    xs = 109; xe = 109;
                    color = grey;
                    state = 8;
                    state_tmp = 42;
                    xs_tmp = 110;
                end
                else if (ys % 50 != 9 && xs_tmp <= 159 && xe_tmp >= 59)
                begin
                    xs = 159; xe = 159;
                    color = black;
                    state = 8;
                    state_tmp = 42;
                    xs_tmp = 160;
                end
                else if (ys % 50 != 9 && xs_tmp <= 209 && xe_tmp >= 209)
                begin
                    xs = 209; xe = 209;
                    color = grey;
                    state = 8;
                    state_tmp = 42;
                    xs_tmp = 210;
                end
                else if (ys % 50 != 9 && xs_tmp <= 259 && xe_tmp >= 259)
                begin
                    xs = 259; xe = 259;
                    color = grey;
                    state = 8;
                    state_tmp = 42;
                    xs_tmp = 260;
                end
                else
                    state = 43;
            43:
                if (ch1_on_next && ch1_next[8 * t_pre + 7 -: 8] + offset1_next < 299 && ch1_next[8 * t + 7 -: 8] + offset1_next < 299)
                begin
                    xs = 308 - offset1_next - ch1_next[8 * t_pre + 7 -: 8];
                    xe = 308 - offset1_next - ch1_next[8 * t + 7 -: 8];
                    if (xs > xe)
                    begin
                        x_tmp = xs;
                        xs = xe;
                        xe = x_tmp;
                    end
                    ys = 10 + t; ye = 10 + t;
                    color = blue;
                    state = 8;
                    state_tmp = 44;
                end
                else
                    state = 44;
            44:
                if (ch2_on && ch2[8 * t_pre + 7 -: 8] + offset2 < 299 && ch2[8 * t + 7 -: 8] + offset2 < 299)
                begin
                    xs = 308 - offset2 - ch2[8 * t_pre + 7 -: 8];
                    xe = 308 - offset2 - ch2[8 * t + 7 -: 8];
                    if (xs > xe)
                    begin
                        x_tmp = xs;
                        xs = xe;
                        xe = x_tmp;
                    end
                    ys = 10 + t; ye = 10 + t;
                    if (ys == 209)
                        color = black;
                    else if (ys % 50 == 9)
                        color = grey;
                    else
                        color = white;
                    state = 8;
                    state_tmp = 45;
                    xs_tmp = xs; xe_tmp = xe;
                end
                else
                    state = 46;
            45:
                if (ys % 50 != 9 && xs_tmp <= 59 && xe_tmp >= 59)
                begin
                    xs = 59; xe = 59;
                    color = grey;
                    state = 8;
                    state_tmp = 45;
                    xs_tmp = 60;
                end
                else if (ys % 50 != 9 && xs_tmp <= 109 && xe_tmp >= 59)
                begin
                    xs = 109; xe = 109;
                    color = grey;
                    state = 8;
                    state_tmp = 45;
                    xs_tmp = 110;
                end
                else if (ys % 50 != 9 && xs_tmp <= 159 && xe_tmp >= 59)
                begin
                    xs = 159; xe = 159;
                    color = black;
                    state = 8;
                    state_tmp = 45;
                    xs_tmp = 160;
                end
                else if (ys % 50 != 9 && xs_tmp <= 209 && xe_tmp >= 209)
                begin
                    xs = 209; xe = 209;
                    color = grey;
                    state = 8;
                    state_tmp = 45;
                    xs_tmp = 210;
                end
                else if (ys % 50 != 9 && xs_tmp <= 259 && xe_tmp >= 259)
                begin
                    xs = 259; xe = 259;
                    color = grey;
                    state = 8;
                    state_tmp = 45;
                    xs_tmp = 260;
                end
                else
                    state = 46;
            46:
                if (ch2_on_next && ch2_next[8 * t_pre + 7 -: 8] + offset2_next < 299 && ch2_next[8 * t + 7 -: 8] + offset2_next < 299)
                begin
                    xs = 308 - offset2_next - ch2_next[8 * t_pre + 7 -: 8];
                    xe = 308 - offset2_next - ch2_next[8 * t + 7 -: 8];
                    if (xs > xe)
                    begin
                        x_tmp = xs;
                        xs = xe;
                        xe = x_tmp;
                    end
                    ys = 10 + t; ye = 10 + t;
                    color = green;
                    state = 8;
                    state_tmp = 41;
                    t = t + 1;
                end
                else
                begin
                    t = t + 1;
                    state = 41;
                end
            47: // delay for 40ms -> 25Hz
                if (k == 40_000_0)
                begin
                    k = 0;
                    state = 39;
                end
                else
                    k = k + 1;
            48: // inserted in 41 -> 47
                begin
                    xs = 308 - level;
                    xe = 308 - level;
                    ys = 3;
                    ye = 8;
                    state = 8;
                    state_tmp = 49;
                    color = white;
                end
            49:
                begin
                    xs = 308 - level - 3;
                    xe = 308 - level + 3;
                    ys = 2;
                    ye = 3;
                    state = 8;
                    // state_tmp = level == level_next ? 50 : 90;
                    state_tmp = 90;
                    level = level_next;
                end
            50:
                begin
                    xs = 308 - level;
                    xe = 308 - level;
                    ys = 3;
                    ye = 8;
                    state = 8;
                    state_tmp = 51;
                    color = red;
                end
            51:
                begin
                    xs = 308 - level - 3;
                    xe = 308 - level + 3;
                    ys = 2;
                    ye = 3;
                    state = 8;
                    state_tmp = 52;
                end
            52:
                begin
                    xs = 308 - offset1;
                    xe = 308 - offset1;
                    ys = 3;
                    ye = 8;
                    state = 8;
                    state_tmp = 53;
                    color = white;
                end
            53:
                begin
                    xs = 308 - offset1 - 3;
                    xe = 308 - offset1 + 3;
                    ys = 2;
                    ye = 3;
                    // state_tmp = offset1 == offset1_next ? 54 : 94;
                    state_tmp = 94;
                    offset1 = offset1_next;
                    state = 8;
                    offset1_next = offset1_next_next;
                end
            54:
                begin
                    xs = 308 - offset1;
                    xe = 308 - offset1;
                    ys = 3;
                    ye = 8;
                    state = 8;
                    state_tmp = 55;
                    color = blue;
                end
            55:
                begin
                    xs = 308 - offset1 - 3;
                    xe = 308 - offset1 + 3;
                    ys = 2;
                    ye = 3;
                    state = 8;
                    state_tmp = 56;
                end
            56:
                begin
                    xs = 308 - offset2;
                    xe = 308 - offset2;
                    ys = 3;
                    ye = 8;
                    state = 8;
                    state_tmp = 57;
                    color = white;
                end
            57:
                begin
                    xs = 308 - offset2 - 3;
                    xe = 308 - offset2 + 3;
                    ys = 2;
                    ye = 3;
                    // state_tmp = offset2 == offset2_next ? 58 : 98;
                    state_tmp = 98;
                    offset2 = offset2_next;
                    state = 8;
                    offset2_next = offset2_next_next;
                end
            58:
                begin
                    xs = 308 - offset2;
                    xe = 308 - offset2;
                    ys = 3;
                    ye = 8;
                    state = 8;
                    state_tmp = 59;
                    color = green;
                end
            59:
                begin
                    xs = 308 - offset2 - 3;
                    xe = 308 - offset2 + 3;
                    ys = 2;
                    ye = 3;
                    state = 8;
                    state_tmp = 102;
                end
            60: // inserted in 38 -> 39
                begin
                    word_ena = 1;
                    word_x = 0;
                    word_y = 0;
                    word_i = 13;
                    color = black;
                    state = 8;
                    state_tmp = 61;
                end
            61:
                begin
                    word_ena = 1;
                    word_x = 0;
                    word_y = 1;
                    word_i = 16;
                    color = black;
                    state = 8;
                    state_tmp = 62;
                end
            62:
                begin
                    word_ena = 1;
                    word_x = 0;
                    word_y = 2;
                    word_i = 19;
                    color = black;
                    state = 8;
                    state_tmp = 63;
                end
            63:
                begin
                    word_ena = 1;
                    word_x = 1;
                    word_y = 1;
                    word_i = 20;
                    color = black;
                    state = 8;
                    state_tmp = 64;
                end
            64:
                begin
                    word_ena = 1;
                    word_x = 1;
                    word_y = 7;
                    word_i = 22;
                    color = black;
                    state = 8;
                    state_tmp = 65;
                end
            65:
                begin
                    word_ena = 1;
                    word_x = 2;
                    word_y = 1;
                    word_i = 21;
                    color = black;
                    state = 8;
                    state_tmp = 66;
                end
            66:
                begin
                    word_ena = 1;
                    word_x = 2;
                    word_y = 7;
                    word_i = 19;
                    color = black;
                    state = 8;
                    state_tmp = 67;
                end
            67:
                begin
                    word_ena = 1;
                    word_x = 3;
                    word_y = 0;
                    word_i = 17;
                    color = red;
                    state = 8;
                    state_tmp = 68;
                end
            68:
                begin
                    word_ena = 1;
                    word_x = 3;
                    word_y = 1;
                    word_i = 19;
                    color = red;
                    state = 8;
                    state_tmp = 69;
                end
            69:
                begin
                    word_ena = 1;
                    word_x = 3;
                    word_y = 2;
                    word_i = 17;
                    color = red;
                    state = 8;
                    state_tmp = 70;
                end
            70:
                begin
                    word_ena = 1;
                    word_x = 4;
                    word_y = 5;
                    word_i = 19;
                    color = black;
                    state = 8;
                    state_tmp = 71;
                end
            71:
                begin
                    word_ena = 1;
                    word_x = 5;
                    word_y = 0;
                    word_i = 12;
                    color = blue;
                    state = 8;
                    state_tmp = 72;
                end
            72:
                begin
                    word_ena = 1;
                    word_x = 5;
                    word_y = 1;
                    word_i = 15;
                    color = blue;
                    state = 8;
                    state_tmp = 73;
                end
            73:
                begin
                    word_ena = 1;
                    word_x = 5;
                    word_y = 2;
                    word_i = 1;
                    color = blue;
                    state = 8;
                    state_tmp = 74;
                end
            74:
                begin
                    word_ena = 1;
                    word_x = 6;
                    word_y = 5;
                    word_i = 19;
                    color = black;
                    state = 8;
                    state_tmp = 75;
                end
            75:
                begin
                    word_ena = 1;
                    word_x = 7;
                    word_y = 0;
                    word_i = 12;
                    color = green;
                    state = 8;
                    state_tmp = 76;
                end
            76:
                begin
                    word_ena = 1;
                    word_x = 7;
                    word_y = 1;
                    word_i = 15;
                    color = green;
                    state = 8;
                    state_tmp = 77;
                end
            77:
                begin
                    word_ena = 1;
                    word_x = 7;
                    word_y = 2;
                    word_i = 2;
                    color = green;
                    state = 8;
                    state_tmp = 78;
                end
            78:
                begin
                    word_ena = 1;
                    word_x = 8;
                    word_y = 5;
                    word_i = 19;
                    color = black;
                    state = 8;
                    state_tmp = 79;
                end
            79:
                begin
                    word_ena = 1;
                    word_x = 1;
                    word_y = 4;
                    word_i = 10;
                    color = black;
                    state = 8;
                    state_tmp = 80;
                end
            80:
                begin
                    word_ena = 1;
                    word_x = 2;
                    word_y = 4;
                    word_i = 10;
                    color = black;
                    state = 8;
                    state_tmp = 81;
                end
            81:
                begin
                    word_ena = 1;
                    word_x = 4;
                    word_y = 2;
                    word_i = 10;
                    color = black;
                    state = 8;
                    state_tmp = 82;
                end
            82:
                begin
                    word_ena = 1;
                    word_x = 6;
                    word_y = 2;
                    word_i = 10;
                    color = black;
                    state = 8;
                    state_tmp = 83;
                end
            83:
                begin
                    word_ena = 1;
                    word_x = 8;
                    word_y = 2;
                    word_i = 10;
                    color = black;
                    state = 8;
                    state_tmp = 123;
                end
            84: // inserted in 39 -> 40
                begin
                    word_ena = 1;
                    word_x = 1;
                    word_y = 3;
                    word_i = 0;
                    color = black;
                    state = 8;
                    state_tmp = 85;
                end
            85:
                begin
                    word_ena = 1;
                    word_x = 1;
                    word_y = 5;
                    word_i = sw[2] ? 1 : 0;
                    color = black;
                    state = 8;
                    state_tmp = 86;
                end
            86:
                begin
                    word_ena = 1;
                    word_x = 1;
                    word_y = 6;
                    word_i = sw[2] ? 0 : (sw[1] ? 5 : (sw[0] ? 2 : 1));
                    color = black;
                    state = 8;
                    state_tmp = 40;
                end
            87: // inserted in 40 -> 41
                begin
                    word_ena = 1;
                    word_x = 2;
                    word_y = 3;
                    word_i = sw[5] ? 2 : (sw[4] ? 1 : 0);
                    color = black;
                    state = 8;
                    state_tmp = 88;
                end
            88:
                begin
                    word_ena = 1;
                    word_x = 2;
                    word_y = 5;
                    word_i = sw[5] || sw[4] ? 0 : (sw[3] ? 5 : 2);
                    color = black;
                    state = 8;
                    state_tmp = 89;
                end
            89:
                begin
                    word_ena = 1;
                    word_x = 2;
                    word_y = 6;
                    word_i = 0;
                    color = black;
                    state = 8;
                    state_tmp = 129;
                end
            90: // inserted in 49 -> 50
                begin
                    word_ena = 1;
                    word_x = 4;
                    word_y = 0;
                    word_i = level < 149 ? 23 : 32;
                    color = black;
                    state = 8;
                    state_tmp = 91;
                end
            91:
                begin
                    word_ena = 1;
                    word_x = 4;
                    word_y = 1;
                    word_i = (level < 149 ? 149 - level : level - 149) * (sw[5] ? 20 : (sw[4] ? 10 : sw[3] ? 5 : 2)) / 500 % 10;
                    color = black;
                    state = 8;
                    state_tmp = 92;
                end
            92:
                begin
                    word_ena = 1;
                    word_x = 4;
                    word_y = 3;
                    word_i = (level < 149 ? 149 - level : level - 149) * (sw[5] ? 20 : (sw[4] ? 10 : sw[3] ? 5 : 2)) / 50 % 10;
                    color = black;
                    state = 8;
                    state_tmp = 93;
                end
            93:
                begin
                    word_ena = 1;
                    word_x = 4;
                    word_y = 4;
                    word_i = (level < 149 ? 149 - level : level - 149) * (sw[5] ? 20 : (sw[4] ? 10 : sw[3] ? 5 : 2)) / 5 % 10;
                    color = black;
                    state = 8;
                    state_tmp = 50;
                end
            94: // inserted in 53 -> 54
                begin
                    word_ena = 1;
                    word_x = 6;
                    word_y = 0;
                    word_i = offset1 < 149 ? 23 : 32;
                    color = black;
                    state = 8;
                    state_tmp = 95;
                end
            95:
                begin
                    word_ena = 1;
                    word_x = 6;
                    word_y = 1;
                    word_i = (offset1 < 149 ? 149 - offset1 : offset1 - 149) * (sw[5] ? 20 : (sw[4] ? 10 : sw[3] ? 5 : 2)) / 500 % 10;
                    color = black;
                    state = 8;
                    state_tmp = 96;
                end
            96:
                begin
                    word_ena = 1;
                    word_x = 6;
                    word_y = 3;
                    word_i = (offset1 < 149 ? 149 - offset1 : offset1 - 149) * (sw[5] ? 20 : (sw[4] ? 10 : sw[3] ? 5 : 2)) / 50 % 10;
                    color = black;
                    state = 8;
                    state_tmp = 97;
                end
            97:
                begin
                    word_ena = 1;
                    word_x = 6;
                    word_y = 4;
                    word_i = (offset1 < 149 ? 149 - offset1 : offset1 - 149) * (sw[5] ? 20 : (sw[4] ? 10 : sw[3] ? 5 : 2)) / 5 % 10;
                    color = black;
                    state = 8;
                    state_tmp = 54;
                end
            98: // inserted in 57 -> 58
                begin
                    word_ena = 1;
                    word_x = 8;
                    word_y = 0;
                    word_i = offset2 < 149 ? 23 : 32;
                    color = black;
                    state = 8;
                    state_tmp = 99;
                end
            99:
                begin
                    word_ena = 1;
                    word_x = 8;
                    word_y = 1;
                    word_i = (offset2 < 149 ? 149 - offset2 : offset2 - 149) * (sw[5] ? 20 : (sw[4] ? 10 : sw[3] ? 5 : 2)) / 500 % 10;
                    color = black;
                    state = 8;
                    state_tmp = 100;
                end
            100:
                begin
                    word_ena = 1;
                    word_x = 8;
                    word_y = 3;
                    word_i = (offset2 < 149 ? 149 - offset2 : offset2 - 149) * (sw[5] ? 20 : (sw[4] ? 10 : sw[3] ? 5 : 2)) / 50 % 10;
                    color = black;
                    state = 8;
                    state_tmp = 101;
                end
            101:
                begin
                    word_ena = 1;
                    word_x = 8;
                    word_y = 4;
                    word_i = (offset2 < 149 ? 149 - offset2 : offset2 - 149) * (sw[5] ? 20 : (sw[4] ? 10 : sw[3] ? 5 : 2)) / 5 % 10;
                    color = black;
                    state = 8;
                    state_tmp = 58;
                end
            102: // inserted in 59 ~ 47
                begin
                    word_ena = 1;
                    word_x = 9;
                    word_y = 0;
                    word_i = sw[10] || sw[11] ? 18 : 32;
                    color = magenta;
                    state = 8;
                    state_tmp = 103;
                end
            103:
                begin
                    word_ena = 1;
                    word_x = 9;
                    word_y = 1;
                    word_i = sw[10] || sw[11] ? 14 : 32;
                    color = magenta;
                    state = 8;
                    state_tmp = 104;
                end
            104:
                begin
                    word_ena = 1;
                    word_x = 9;
                    word_y = 2;
                    word_i = sw[10] || sw[11] ? 11 : 32;
                    color = magenta;
                    state = 8;
                    state_tmp = 105;
                end
            105:
                begin
                    word_ena = 1;
                    word_x = 10;
                    word_y = 5;
                    word_i = sw[10] ? 22 : (sw[11] ? 19 : 32);
                    color = black;
                    state = 8;
                    state_tmp = 106;
                end
            106:
                begin
                    word_ena = 1;
                    word_x = 11;
                    word_y = 5;
                    word_i = sw[10] && sw[11] ? 19 : 32;
                    color = black;
                    state = 8;
                    state_tmp = 107;
                end
            107:
                begin
                    word_ena = 1;
                    word_x = 10;
                    word_y = 2;
                    word_i = sw[10] ? word_numt / 10 % 10 : (sw[11] ? 10 : 32);
                    color = black;
                    state = 8;
                    state_tmp = 108;
                end
            108:
                begin
                    word_ena = 1;
                    word_x = 11;
                    word_y = 2;
                    word_i =  sw[10] && sw[11] ? 10 : 32;
                    color = black;
                    state = 8;
                    state_tmp = 109;
                end
            109: //
                begin
                    word_ena = 1;
                    word_x = 10;
                    word_y = 0;
                    word_i = sw[10] && mea_t_next < 199 || !sw[10] && sw[11] && mea_v_next < 149 ? 23 : 32;
                    color = black;
                    state = 8;
                    state_tmp = 110;
                end
            110:
                begin
                    word_ena = 1;
                    word_x = 10;
                    word_y = 1;
                    if (sw[10])
                        word_i = word_numt / 100 % 10;
                    else if (sw[11])
                        word_i = word_numv / 100 % 10;
                    else
                        word_i = 32;
                    color = black;
                    state = 8;
                    state_tmp = 111;
                end
            111:
                begin
                    word_ena = 1;
                    word_x = 10;
                    word_y = 3;
                    if (sw[10])
                        word_i = word_numt % 10;
                    else if (sw[11])
                        word_i = word_numv / 10 % 10;
                    else
                        word_i = 32;
                    color = black;
                    state = 8;
                    state_tmp = 112;
                end
            112:
                begin
                    word_ena = 1;
                    word_x = 10;
                    word_y = 4;
                    if (sw[10])
                        word_i = 24;
                    else if (sw[11])
                        word_i = word_numv % 10;
                    else
                        word_i = 32;
                    color = black;
                    state = 8;
                    state_tmp = 113;
                end
            113:
                begin
                    word_ena = 1;
                    word_x = 11;
                    word_y = 0;
                    if (sw[10] && sw[11])
                        word_i = mea_v_next < 149 ? 23 : 32;
                    else
                        word_i = 32;
                    color = black;
                    state = 8;
                    state_tmp = 114;
                end
            114:
                begin
                    word_ena = 1;
                    word_x = 11;
                    word_y = 1;
                    word_i = sw[10] && sw[11] ? word_numv / 100 % 10 : 32;
                    color = black;
                    state = 8;
                    state_tmp = 115;
                end
            115:
                begin
                    word_ena = 1;
                    word_x = 11;
                    word_y = 3;
                    word_i = sw[10] && sw[11] ? word_numv / 10 % 10 : 32;
                    color = black;
                    state = 8;
                    state_tmp = 116;
                end
            116:
                begin
                    word_ena = 1;
                    word_x = 11;
                    word_y = 4;
                    word_i = sw[10] && sw[11] ? word_numv % 10 : 32;
                    color = black;
                    state = 8;
                    state_tmp = 117;
                end
            117:
                begin
                    xs = 10; xe = 308;
                    ys = 10 + mea_t; ye = 10 + mea_t;
                    if (ys == 209)
                        color = black;
                    else if (ys % 50 == 9)
                        color = grey;
                    else
                        color = white;
                    state = 8;
                    state_tmp = 118;
                end
            118:
                begin
                    xs = 59 + 50 * k; xe = 59 + 50 * k;
                    if (k < 4)
                    begin
                        color = xs == 159 ? black : grey;
                        state_tmp = 118;
                        k = k + 1;
                    end
                    else
                    begin
                        k = 0;
                        color = grey;
                        state_tmp = sw[10] ? 119 : 120;
                        mea_t = mea_t_next;
                    end
                    state = 8;
                end
            119:
                begin
                    xs = 10; xe = 308;
                    ys = 10 + mea_t; ye = 10 + mea_t;
                    color = magenta;
                    state = 8;
                    state_tmp = 120;
                end
            120:
                begin
                    xs = 308 - mea_v; xe = 308 - mea_v;
                    ys = 10; ye = 408;
                    if (xs == 159)
                        color = black;
                    else if (xs % 50 == 9)
                        color = grey;
                    else
                        color = white;
                    state = 8;
                    state_tmp = 121;
                end
            121:
                begin
                    ys = 59 + 50 * k; ye = 59 + 50 * k;
                    if (k < 6)
                    begin
                        color = ys == 209 ? black : grey;
                        state_tmp = 121;
                        k = k + 1;
                    end
                    else
                    begin
                        k = 0;
                        color = grey;
                        state_tmp = sw[11] ? 122 : 47;
                        mea_v = mea_v_next;
                    end
                    state = 8;
                end
            122:
                begin
                    xs = 308 - mea_v; xe = 308 - mea_v;
                    ys = 10; ye = 408;
                    color = magenta;
                    state = 8;
                    state_tmp = 47;
                end
            123: // inserted in 83 ~ 39
                begin
                    word_ena = 1;
                    word_x = 15;
                    word_y = 0;
                    word_i = 25;
                    color = black;
                    state = 8;
                    state_tmp = 124;
                end
            124:
                begin
                    word_ena = 1;
                    word_x = 15;
                    word_y = 1;
                    word_i = 18;
                    color = black;
                    state = 8;
                    state_tmp = 125;
                end
            125:
                begin
                    word_ena = 1;
                    word_x = 15;
                    word_y = 2;
                    word_i = 26;
                    color = black;
                    state = 8;
                    state_tmp = 126;
                end
            126:
                begin
                    word_ena = 1;
                    word_x = 16;
                    word_y = 3;
                    word_i = 10;
                    color = black;
                    state = 8;
                    state_tmp = 127;
                end
            127:
                begin
                    word_ena = 1;
                    word_x = 16;
                    word_y = 5;
                    word_i = 27;
                    color = black;
                    state = 8;
                    state_tmp = 128;
                end
            128:
                begin
                    word_ena = 1;
                    word_x = 16;
                    word_y = 6;
                    word_i = 12;
                    color = black;
                    state = 8;
                    state_tmp = 39;
                end
            129: // inserted in 89 -> 41
                begin
                    word_ena = 1;
                    word_x = 16;
                    word_y = 1;
                    word_i = tmp / 100 % 10;
                    color = black;
                    state = 8;
                    state_tmp = 130;
                end
            130:
                begin
                    word_ena = 1;
                    word_x = 16;
                    word_y = 2;
                    word_i = tmp / 10 % 10;
                    color = black;
                    state = 8;
                    state_tmp = 131;
                end
            131:
                begin
                    word_ena = 1;
                    word_x = 16;
                    word_y = 4;
                    word_i = tmp % 10;
                    color = black;
                    state = 8;
                    state_tmp = 41;
                end
        endcase
    else
        n = n;
    n = n + 1;
end
endmodule
module words(input [31:0] i, output reg [0:83] mtrx);
// table:
// 0 ~ 9: 0 ~ 9
// 10: decimal point
// 11 12 13 14 15 16 17 18 19 20 21 22 24 25 26 27
// A  C  D  E  H  I  L  M  V  X  Y  s  m  T  P  deg
// 23: -
always @(i)
    case(i)
    default: mtrx = 84'b0000_0000_0000_0000_0000_0;
    0:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    1:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    2:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    3:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    4:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0};
    5:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    6:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    7:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    8:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    9:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    10:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    11:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0};
    12:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0};
    13:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0};
    14:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0};
    15:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0};
    16:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    17:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0};
    18:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0};
    19:
        mtrx = {
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    20:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0};
    21:
        mtrx = {
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    22:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    23:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    24:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0};
    25:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    26:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    27:
        mtrx = {
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    endcase
endmodule

module temperature(input clk, inout sda, output reg scl = 0, output reg [15:0] tmp_r);
reg [7:0] addr_and_state = 8'b100_1011_1;
reg [7:0] msb, lsb;
wire [15:0] tmp;
assign tmp = ({msb, lsb} >> 3) * 625 / 1000;
reg sda_r = 1, sda_link = 0;
assign sda = sda_link ? sda_r : 1'bz;
reg mid = 0, get_tmp = 0;
integer state = 0, i = 0, n = 0, n_1 = 0;
// state table:
// 0: start the i2c communication
// 1: transmit address and state message from the host to slave device
// 2: the host receive acknowledge message from the slave
// 3: transmit msb from the slave to the host
// 4: the host send an aknowledge message to the slave
// 5: transmit lsb from the slave to the host
// 6: end the i2c communication
always @(posedge clk)
begin
    // 250 = (frequency of clk) / (frequency of scl) / 2 (for converting) / 2 (for middle judging)
    if (n == 250)
    begin
        if (!mid)
            // frequency of scl is 100MHz / 2 / 500 = 100kHz
            scl = ~scl;
        else
        begin
            // handle the sdl data at the middle of every stable scl signal level
            if (!scl)
                // when scl is down
                if (get_tmp)
                    case(state)
                        0: state = 0;
                        1: sda_r = addr_and_state[7 - i];
                        2:
                            begin
                                sda_r = 1;
                                sda_link = 0;
                            end
                        3: sda_link = 0;
                        4:
                            begin
                                sda_r = 0;
                                sda_link = 1;
                            end
                        5: sda_link = 0;
                        6:
                            begin
                                sda_r = 0;
                                sda_link = 1;
                            end
                    endcase
                else
                    state = 0;
            else
                // when scl is up
                if (get_tmp)
                    case(state)
                        0:
                            begin
                                sda_link = 1;
                                sda_r = 0;
                                state = 1;
                                i = 0;
                            end
                        1:
                            if (i < 7)
                                i = i + 1;
                            else
                                state = 2;
                        2: 
                            begin
                                state = 3;
                                i = 0;
                            end
                        3:
                            begin
                                msb[7 - i] = sda;
                                if (i < 7)
                                    i = i + 1;
                                else
                                    state = 4;
                            end
                        4:
                            begin
                                state = 5;
                                i = 0;
                            end
                        5:
                            begin
                                lsb[7 - i] = sda;
                                if (i < 7)
                                    i = i + 1;
                                else
                                    state = 6;
                            end
                        6:
                            begin
                                sda_r = 1;
                                sda_link = 0;
                                state = 0;
                                get_tmp = 0;
                            end
                    endcase
                else
                    state = 0;
        end
        mid = ~mid;
        n = 1;
        if (n_1 == 50_000_000 / 250)
        begin
            tmp_r = tmp;
            get_tmp = 1;
            n_1 = 1;
        end
        else
            n_1 = n_1 + 1;
    end
    else
        n = n + 1;
end
endmodule