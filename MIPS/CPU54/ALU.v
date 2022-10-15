module ALU(a, b, s, r, zero, overflow, negative);
    input [31:0] a;
    input [31:0] b;
    input [3:0] s;
    output [31:0] r;
    output zero;
    output overflow;
    output negative;

    wire [32:0] r_ext;
    assign r_ext = s == 4'b0010 ? {a[31], a} + {b[31], b} : {a[31], a} - {b[31], b};
    assign zero = r == 0;
    assign overflow = (r_ext[32] ^ r_ext[31]) & (s == 4'b0010 | s == 4'b0011);
    assign negative = r[31];
    assign r = s == 4'b0000 ? a + b :
              (s == 4'b0010 ? a + b :
              (s == 4'b0001 ? a - b :
              (s == 4'b0011 ? a - b :
              (s == 4'b0100 ? a & b :
              (s == 4'b0101 ? a | b :
              (s == 4'b0110 ? a ^ b :
              (s == 4'b0111 ? ~(a | b) :
              (s == 4'b1000 ? {b[15:0], 16'b0} :
              (s == 4'b1001 ? {b[15:0], 16'b0} :
              (s == 4'b1011 ? $signed(a) < $signed(b) :
              (s == 4'b1010 ? a < b :
              (s == 4'b1100 ? $signed($signed(b) >>> a[4:0]):
              (s == 4'b1110 ? b << a[4:0] :
              (s == 4'b1111 ? b << a[4:0] :
              (s == 4'b1101 ? b >> a[4:0] :
               32'b0)))))))))))))));
endmodule

module MUL(a, b, r, sign);
    input [31:0] a;
    input [31:0] b;
    input sign;
    output [63:0] r;
    wire [31:0] a_abs;
    wire [31:0] b_abs;
    wire [63:0] r_abs;
    assign a_abs = sign & a[31] ? -a : a;
    assign b_abs = sign & b[31] ? -b : b;
    assign r_abs =
        ((b_abs[00] ? {32'b0, a_abs}        : 64'b0) + (b_abs[01] ? {31'b0, a_abs, 01'b0} : 64'b0) +
         (b_abs[02] ? {30'b0, a_abs, 02'b0} : 64'b0) + (b_abs[03] ? {29'b0, a_abs, 03'b0} : 64'b0) +
         (b_abs[04] ? {28'b0, a_abs, 04'b0} : 64'b0) + (b_abs[05] ? {27'b0, a_abs, 05'b0} : 64'b0) +
         (b_abs[06] ? {26'b0, a_abs, 06'b0} : 64'b0) + (b_abs[07] ? {25'b0, a_abs, 07'b0} : 64'b0) +
         (b_abs[08] ? {24'b0, a_abs, 08'b0} : 64'b0) + (b_abs[09] ? {23'b0, a_abs, 09'b0} : 64'b0) +
         (b_abs[10] ? {22'b0, a_abs, 10'b0} : 64'b0) + (b_abs[11] ? {21'b0, a_abs, 11'b0} : 64'b0) +
         (b_abs[12] ? {20'b0, a_abs, 12'b0} : 64'b0) + (b_abs[13] ? {19'b0, a_abs, 13'b0} : 64'b0) +
         (b_abs[14] ? {18'b0, a_abs, 14'b0} : 64'b0) + (b_abs[15] ? {17'b0, a_abs, 15'b0} : 64'b0) +
         (b_abs[16] ? {16'b0, a_abs, 16'b0} : 64'b0) + (b_abs[17] ? {15'b0, a_abs, 17'b0} : 64'b0) +
         (b_abs[18] ? {14'b0, a_abs, 18'b0} : 64'b0) + (b_abs[19] ? {13'b0, a_abs, 19'b0} : 64'b0) +
         (b_abs[20] ? {12'b0, a_abs, 20'b0} : 64'b0) + (b_abs[21] ? {11'b0, a_abs, 21'b0} : 64'b0) +
         (b_abs[22] ? {10'b0, a_abs, 22'b0} : 64'b0) + (b_abs[23] ? {09'b0, a_abs, 23'b0} : 64'b0) +
         (b_abs[24] ? {08'b0, a_abs, 24'b0} : 64'b0) + (b_abs[25] ? {07'b0, a_abs, 25'b0} : 64'b0) +
         (b_abs[26] ? {06'b0, a_abs, 26'b0} : 64'b0) + (b_abs[27] ? {05'b0, a_abs, 27'b0} : 64'b0) +
         (b_abs[28] ? {04'b0, a_abs, 28'b0} : 64'b0) + (b_abs[29] ? {03'b0, a_abs, 29'b0} : 64'b0) +
         (b_abs[30] ? {02'b0, a_abs, 30'b0} : 64'b0) + (b_abs[31] ? {01'b0, a_abs, 31'b0} : 64'b0));
    assign r = sign & (a[31] ^ b[31]) ? -r_abs : r_abs;
endmodule

module DIV(a, b, q, r, sign, dbz);
    input [31:0] a, b;
    input sign;
    output [31:0] q, r;
    output dbz;
    wire [31:0] a_abs, b_abs, q_abs, r_abs;
    assign a_abs = sign & a[31] ? -a : a;
    assign b_abs = sign & b[31] ? -b : b;
    wire [31:0] r00, r01, r02, r03, r04, r05, r06, r07,
                r08, r09, r10, r11, r12, r13, r14, r15,
                r16, r17, r18, r19, r20, r21, r22, r23,
                r24, r25, r26, r27, r28, r29, r30, r31, r32;
    wire [31:0] d00, d01, d02, d03, d04, d05, d06, d07,
                d08, d09, d10, d11, d12, d13, d14, d15,
                d16, d17, d18, d19, d20, d21, d22, d23,
                d24, d25, d26, d27, d28, d29, d30, d31;
    assign r32 = 32'd0;
    assign d31 = {r32[30:0], a_abs[31]}; assign r31 = d31 - (d31 < b_abs ? 32'd0 : b_abs);
    assign d30 = {r31[30:0], a_abs[30]}; assign r30 = d30 - (d30 < b_abs ? 32'd0 : b_abs);
    assign d29 = {r30[30:0], a_abs[29]}; assign r29 = d29 - (d29 < b_abs ? 32'd0 : b_abs);
    assign d28 = {r29[30:0], a_abs[28]}; assign r28 = d28 - (d28 < b_abs ? 32'd0 : b_abs);
    assign d27 = {r28[30:0], a_abs[27]}; assign r27 = d27 - (d27 < b_abs ? 32'd0 : b_abs);
    assign d26 = {r27[30:0], a_abs[26]}; assign r26 = d26 - (d26 < b_abs ? 32'd0 : b_abs);
    assign d25 = {r26[30:0], a_abs[25]}; assign r25 = d25 - (d25 < b_abs ? 32'd0 : b_abs);
    assign d24 = {r25[30:0], a_abs[24]}; assign r24 = d24 - (d24 < b_abs ? 32'd0 : b_abs);
    assign d23 = {r24[30:0], a_abs[23]}; assign r23 = d23 - (d23 < b_abs ? 32'd0 : b_abs);
    assign d22 = {r23[30:0], a_abs[22]}; assign r22 = d22 - (d22 < b_abs ? 32'd0 : b_abs);
    assign d21 = {r22[30:0], a_abs[21]}; assign r21 = d21 - (d21 < b_abs ? 32'd0 : b_abs);
    assign d20 = {r21[30:0], a_abs[20]}; assign r20 = d20 - (d20 < b_abs ? 32'd0 : b_abs);
    assign d19 = {r20[30:0], a_abs[19]}; assign r19 = d19 - (d19 < b_abs ? 32'd0 : b_abs);
    assign d18 = {r19[30:0], a_abs[18]}; assign r18 = d18 - (d18 < b_abs ? 32'd0 : b_abs);
    assign d17 = {r18[30:0], a_abs[17]}; assign r17 = d17 - (d17 < b_abs ? 32'd0 : b_abs);
    assign d16 = {r17[30:0], a_abs[16]}; assign r16 = d16 - (d16 < b_abs ? 32'd0 : b_abs);
    assign d15 = {r16[30:0], a_abs[15]}; assign r15 = d15 - (d15 < b_abs ? 32'd0 : b_abs);
    assign d14 = {r15[30:0], a_abs[14]}; assign r14 = d14 - (d14 < b_abs ? 32'd0 : b_abs);
    assign d13 = {r14[30:0], a_abs[13]}; assign r13 = d13 - (d13 < b_abs ? 32'd0 : b_abs);
    assign d12 = {r13[30:0], a_abs[12]}; assign r12 = d12 - (d12 < b_abs ? 32'd0 : b_abs);
    assign d11 = {r12[30:0], a_abs[11]}; assign r11 = d11 - (d11 < b_abs ? 32'd0 : b_abs);
    assign d10 = {r11[30:0], a_abs[10]}; assign r10 = d10 - (d10 < b_abs ? 32'd0 : b_abs);
    assign d09 = {r10[30:0], a_abs[09]}; assign r09 = d09 - (d09 < b_abs ? 32'd0 : b_abs);
    assign d08 = {r09[30:0], a_abs[08]}; assign r08 = d08 - (d08 < b_abs ? 32'd0 : b_abs);
    assign d07 = {r08[30:0], a_abs[07]}; assign r07 = d07 - (d07 < b_abs ? 32'd0 : b_abs);
    assign d06 = {r07[30:0], a_abs[06]}; assign r06 = d06 - (d06 < b_abs ? 32'd0 : b_abs);
    assign d05 = {r06[30:0], a_abs[05]}; assign r05 = d05 - (d05 < b_abs ? 32'd0 : b_abs);
    assign d04 = {r05[30:0], a_abs[04]}; assign r04 = d04 - (d04 < b_abs ? 32'd0 : b_abs);
    assign d03 = {r04[30:0], a_abs[03]}; assign r03 = d03 - (d03 < b_abs ? 32'd0 : b_abs);
    assign d02 = {r03[30:0], a_abs[02]}; assign r02 = d02 - (d02 < b_abs ? 32'd0 : b_abs);
    assign d01 = {r02[30:0], a_abs[01]}; assign r01 = d01 - (d01 < b_abs ? 32'd0 : b_abs);
    assign d00 = {r01[30:0], a_abs[00]}; assign r00 = d00 - (d00 < b_abs ? 32'd0 : b_abs);
    assign q_abs = ((!(d00 < b_abs)) << 5'd00) + ((!(d01 < b_abs)) << 5'd01) +
                   ((!(d02 < b_abs)) << 5'd02) + ((!(d03 < b_abs)) << 5'd03) +
                   ((!(d04 < b_abs)) << 5'd04) + ((!(d05 < b_abs)) << 5'd05) +
                   ((!(d06 < b_abs)) << 5'd06) + ((!(d07 < b_abs)) << 5'd07) +
                   ((!(d08 < b_abs)) << 5'd08) + ((!(d09 < b_abs)) << 5'd09) +
                   ((!(d10 < b_abs)) << 5'd10) + ((!(d11 < b_abs)) << 5'd11) +
                   ((!(d12 < b_abs)) << 5'd12) + ((!(d13 < b_abs)) << 5'd13) +
                   ((!(d14 < b_abs)) << 5'd14) + ((!(d15 < b_abs)) << 5'd15) +
                   ((!(d16 < b_abs)) << 5'd16) + ((!(d17 < b_abs)) << 5'd17) +
                   ((!(d18 < b_abs)) << 5'd18) + ((!(d19 < b_abs)) << 5'd19) +
                   ((!(d20 < b_abs)) << 5'd20) + ((!(d21 < b_abs)) << 5'd21) +
                   ((!(d22 < b_abs)) << 5'd22) + ((!(d23 < b_abs)) << 5'd23) +
                   ((!(d24 < b_abs)) << 5'd24) + ((!(d25 < b_abs)) << 5'd25) +
                   ((!(d26 < b_abs)) << 5'd26) + ((!(d27 < b_abs)) << 5'd27) +
                   ((!(d28 < b_abs)) << 5'd28) + ((!(d29 < b_abs)) << 5'd29) +
                   ((!(d30 < b_abs)) << 5'd30) + ((!(d31 < b_abs)) << 5'd31);
    assign r_abs = r00;
    assign q = sign & (a[31] ^ b[31]) ? -q_abs : q_abs;
    assign r = sign & a[31] ? -r_abs : r_abs;
    assign dbz = b == 32'd0;
endmodule