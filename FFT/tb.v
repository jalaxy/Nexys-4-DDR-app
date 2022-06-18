`timescale 1ns/1ns
module fft_tb();
reg clk, rst, sig, we, rev;
reg [31:0] addr;
reg [127:0] din;
wire [127:0] dout; 
fft inst(clk, rst, sig, we, rev, addr, din, dout);
wire [127:0] dina, douta, test;
wire wea;
assign wea = fft.mem_units[0].wea;
assign dina = fft.mem_units[0].dina;
assign douta = fft.mem_units[0].douta;
assign test = fft.addr_phy;
initial begin
    clk = 0; addr = 64'd0; rst = 0; #10; rst = 1; #5; rst = 0;
    we = 1;
    rev = 1;
    #10;
    for (addr = 0; addr < 1024; addr = addr + 1) begin
        din = (addr << 65) + addr;
        #20;
    end
    we = 0;
    rev = 0;
    #1000;
    for (addr = 0; addr < 1024; addr = addr + 1) #20;
    #20;
    $stop();
end
initial begin
    while (1) begin
        clk = ~clk;
        #5;
    end
end
endmodule

module bit_reverse_tb();
reg [`logN-1:0] din;
wire [`logN-1:0] dout;
bit_reverse inst(din, dout);
initial begin
    din = `logN'd0;
    #10;
    for (din = 1; din != 0; din = din + 1)
        #10;
    end
endmodule

module bram_dual_tb();
reg clk, wea, web;
reg [31:0] addra, addrb, dina, dinb;
wire [31:0] douta, doutb;  
bram_data inst_data(
        .wea(wea), .addra(addra), .dina(dina), .douta(douta), .clka(clk),
        .web(web), .addrb(addrb), .dinb(dinb), .doutb(doutb), .clkb(clk));
initial begin
    clk = 0;
    wea = 1;
    #10;
    addra = 0;
    dina = 100;
    #10;
    wea = 0;
end
initial begin
    while (1) begin
        clk = ~clk;
        #10;
    end
end
endmodule

module fft_op_unit_tb();
reg [63:0] ar, ai, br, bi, wr, wi;
wire [63:0] cr, ci, dr, di;
fft_op_unit op(ar, ai, br, bi, cr, ci, dr, di, wr, wi);

integer fpi, fpo, n, i;
initial begin
    fpi = $fopen("C:\\Users\\JXY\\Desktop\\project\\input.txt", "r");
    fpo = $fopen("C:\\Users\\JXY\\Desktop\\project\\output.txt", "w");
    i = $fscanf(fpi, "%d", n);
    $display("%d\n", n);
    for (i = 0; i < n; i = i + 1) begin
        $fscanf(fpi, "%x%x%x%x%x%x", ar, ai, br, bi, wr, wi);
        #10;
        $fdisplay(fpo, "%x %x %x %x", cr, ci, dr, di);
    end
end
endmodule