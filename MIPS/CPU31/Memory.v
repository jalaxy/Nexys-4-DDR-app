module Memory(clk, addr, cs, w, data);
    input clk;
    input [31:0] addr;
    input cs;
    input w;
    inout [31:0] data;

    reg [31:0] mem[0:2047];
    integer i;

    assign data = cs && ~w ? mem[addr] : 32'bz;
    wire cs_w_clk;
    assign cs_w_clk = cs & w & clk;
    always @(posedge cs_w_clk)
        mem[addr] = data;
endmodule