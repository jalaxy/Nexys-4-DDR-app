`timescale 1ns/1ns
`include "top.vh"
module fft_tb();
reg clk, rst, sig, we, rev;
reg [31:0] addr;
reg [127:0] din;
wire [127:0] dout; 
fft inst(clk, rst, sig, we, rev, addr, din, dout);
wire clk_run, busy;
wire [16:0] rnd, iter, cycle;
assign clk_run = inst.clk_run;
assign busy = inst.busy;
assign rnd = inst.rnd;
assign iter = inst.iter;
assign cycle = inst.cycle;

//wire [127:0] opa0, opb0, w0, ome0, opc0, opd0;
//wire [127:0] opa1, opb1, w1, ome1, opc1, opd1;
//assign opa0 = fft.opa[0];
//assign opb0 = fft.opb[0];
//assign w0 = fft.op_units[0].w;
//assign ome0 = fft.op_units[0].omega;
//assign opc0 = fft.opc[0];
//assign opd0 = fft.opd[0];
//assign opa1 = fft.opa[1];
//assign opb1 = fft.opb[1];
//assign w1 = fft.op_units[1].w;
//assign ome1 = fft.op_units[1].omega;
//assign opc1 = fft.opc[1];
//assign opd1 = fft.opd[1];

//wire [4:0] addra_calc[0:3], addrb_calc[0:3];
//assign addra_calc[0] = fft.addra_calc[0];
//assign addra_calc[1] = fft.addra_calc[1];
//assign addra_calc[2] = fft.addra_calc[2];
//assign addra_calc[3] = fft.addra_calc[3];
//assign addrb_calc[0] = fft.addrb_calc[0];
//assign addrb_calc[1] = fft.addrb_calc[1];
//assign addrb_calc[2] = fft.addrb_calc[3];
//assign addrb_calc[3] = fft.addrb_calc[3];

//wire [4:0] addra[0:3], addrb[0:3];
//assign addra[0] = fft.op_units[0].addra;
//assign addrb[0] = fft.op_units[0].addrb;
//assign addra[1] = fft.op_units[1].addra;
//assign addrb[1] = fft.op_units[1].addrb;
//assign addra[2] = fft.op_units[2].addra;
//assign addrb[2] = fft.op_units[2].addrb;
//assign addra[3] = fft.op_units[3].addra;
//assign addrb[3] = fft.op_units[3].addrb;


//wire [4:0] grpa[0:1], grpb[0:1];
//wire [4:0] idxa[0:1], idxb[0:1];
//assign grpa[0] = fft.grpa[0];
//assign grpa[1] = fft.grpa[1];
//assign grpb[0] = fft.grpb[0];
//assign grpb[1] = fft.grpb[1];
//assign idxa[0] = fft.idxa[0];
//assign idxa[1] = fft.idxa[1];
//assign idxb[0] = fft.idxb[0];
//assign idxb[1] = fft.idxb[1];

integer i;
reg [127:0] res [0:15];

initial begin
    clk = 0; sig = 0; addr = 64'd0; rst = 0; #10; rst = 1; #5; rst = 0;
    din = 0; we = 0; rev = 0;
    for (addr = 0; addr < 16; addr = addr + 1) #20;
    #2000;
    #100;
    sig = 1; #10; sig = 0;
    for (i = 0; i < 1000; i = i + 1) begin
        #10;
//        if (fft.rnd == 4) begin rst = 1; #50; rst = 0; end
    end
    for (addr = 0; addr < 16; addr = addr + 1) begin
        #20;
        res[addr] = dout;
        #10;
    end
    #200;
    $stop();
end
initial begin
    while (1) begin clk = ~clk; #5; end
end
endmodule

module bit_reverse_tb();
reg [`logN-1:0] din;
wire [`logN-1:0] dout;
bit_reverse inst(din, dout);
initial begin
    din = `logN'd0; #10;
    for (din = 1; din != 0; din = din + 1) #10;
end
endmodule

module bram_dual_tb();
reg clk, wea, web;
reg [7:0] addra, addrb, dina, dinb;
wire [7:0] douta, doutb;  
bram_data inst_data(
        .wea(wea), .addra(addra), .dina(dina), .douta(douta), .clka(clk),
        .web(web), .addrb(addrb), .dinb(dinb), .doutb(doutb), .clkb(clk));
initial begin
    clk = 0; wea = 1; web = 1; #10;
    for (addra = 0; addra != 8'd127; addra = addra + 1) begin
        addrb = 256 - addra; dina = addra; dinb = addrb; #20;
    end
    wea = 0; web = 0; #100;
    for (addra = 0; addra != 8'd127; addra = addra + 1) begin
        addrb = 256 - addra; #20;
    end
    $stop();
end
initial begin
    while (1) begin
        clk = ~clk; #5;
    end
end
endmodule

module fft_op_unit_tb();
reg [63:0] ar, ai, br, bi, wr, wi;
wire [63:0] cr, ci, dr, di;
fft_op_unit op(ar, ai, br, bi, cr, ci, dr, di, wr, wi);

integer fpi, fpo, n, i;
initial begin
    fpi = $fopen("/home/nya/input.txt", "r");
    fpo = $fopen("/home/nya/output.txt", "w");
    i = $fscanf(fpi, "%d", n);
    $display("%d\n", n);
    for (i = 0; i < n; i = i + 1) begin
        $fscanf(fpi, "%x%x%x%x%x%x", ar, ai, br, bi, wr, wi); #10;
        $fdisplay(fpo, "%x %x %x %x", cr, ci, dr, di);
    end
    $stop();
end
endmodule