module Memory(clk, addr, cs, w, din, dout);
    input clk;
    input [7:0] addr;
    input cs;
    input w;
    input [7:0] din;
    output [7:0] dout;

    reg [7:0] mem[0:2047];
    integer i;

    assign dout = mem[addr];
    wire cs_w_clk;
    assign cs_w_clk = cs & w & clk;
    always @(posedge cs_w_clk)
        mem[addr] = din;
endmodule