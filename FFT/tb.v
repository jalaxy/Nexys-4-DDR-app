`timescale 1ns/1ns
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