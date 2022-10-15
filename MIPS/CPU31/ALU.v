module ALU(a, b, s, r, zero, overflow);
    input [31:0] a;
    input [31:0] b;
    input [3:0] s;
    output [31:0] r;
    output zero;
    output overflow;

    wire [32:0] r_ext;
    assign r_ext = {a[31], a} + {b[31], b};
    assign zero = r == 0;
    assign overflow = (r_ext[32] ^ r_ext[31]) & (s == 4'b0010 | s == 4'b0011);
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
              (s == 4'b1100 ? $signed($signed(b) >>> a):
              (s == 4'b1110 ? b << a :
              (s == 4'b1111 ? b << a :
              (s == 4'b1101 ? b >> a :
               32'b0)))))))))))))));
endmodule