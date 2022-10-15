module RAM(clk, addr, wea, width, sign, din, dout, err);
    input clk;              // memory clock
    input [31:0] addr;      // from 0x0 8 bits per address
    input wea;              // write enable signal
    input [1:0] width;      // write width: 0 -> 1 byte; 1 -> 2 bytes; 3 -> 4 bytes
    input sign;             // sign extension: 0 -> 0; 1 -> sign
    input [31:0] din;       // input data
    output [31:0] dout;     // output data with sign extension (if required)
    output err;             // address error exception

    wire [31:0] addr_div, addr_mod; // address first 30 bits and last 2 bits
    wire [31:0] din_shift;          // input shifted to align
    wire [31:0] dout_o;             // origin real output
    wire [31:0] dout_shift;         // output shiftd to align
    wire [31:0] hi;                 // position of the highest bit plus 1
    wire [3:0] ena;                 // enable pin of each byte
    Memory mem3(clk, addr_div, 1'b1, ena[3], din_shift[31:24], dout_o[31:24]);
    Memory mem2(clk, addr_div, 1'b1, ena[2], din_shift[23:16], dout_o[23:16]);
    Memory mem1(clk, addr_div, 1'b1, ena[1], din_shift[15:08], dout_o[15:08]);
    Memory mem0(clk, addr_div, 1'b1, ena[0], din_shift[07:00], dout_o[07:00]);

    assign addr_div = addr >> 32'd2;
    assign addr_mod = addr & 32'b11;
    assign din_shift = din << (addr_mod << 32'd3);
    assign err = width == 2'd2 | (width & addr_mod) != 2'd0;
    assign ena = {4{wea & ~err}} & (4'hf << addr_mod) & ~(4'hf << (addr_mod + width + 32'd1));
    assign dout_shift = dout_o >> (addr_mod << 32'd3);
    assign hi = (width + 5'd1) << 32'd3;
    assign dout = wea ? 32'hz : dout_shift & ~(32'hffffffff << hi) | {32{sign & dout_shift[hi - 1]}} << hi;
endmodule