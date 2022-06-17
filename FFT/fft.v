`include "top.vh"
module fft(clk, rst, sig, addr, din, dout, wea, clk_mem);
input clk;
input rst;
input sig;
output [`logN*`M-1:0] addr;
input [64*`M-1:0] din;
output [64*`M-1:0] dout;
output wea;
output clk_mem;

reg busy;
wire start, clk_run;
reg [0:0] stage;
reg [`logN-1:0] rnd;
reg [`N/`M-1:0] iter;
genvar igen;
integer k;

assign start = sig & ~busy;
assign clk_run = clk & busy;
for (igen = 0; igen < `M; igen = igen + 1) begin : op_units
    reg [63:0] ar, ai, br, bi;
    reg [`logN-1:0] omega; 
    wire [63:0] cr, ci, dr, di, wr, wi;
    wire [63:0] revin;
    wire [63:0] revout;
    fft_op_unit op(ar, ai, br, bi, cr, ci, dr, di, wr, wi);
    bit_reverse(revin, revout);
    brom_cos4096(.addra(omega), .clka(clk_run), .douta(wr));
    brom_sin4096(.addra(omega), .clka(clk_run), .douta(wi));
end

always @(posedge clk_run)
begin
    case (stage)
    0: begin
        stage = 1;
    end
    1: begin
        rnd <= rnd + 1;
        iter <= iter + 1;
        for (k = 0; k < `M; k = k + 1) begin
            op_units[k].ar <= 64'd0;
            op_units[k].ai <= 64'd0;
            op_units[k].br <= 64'd0;
            op_units[k].bi <= 64'd0;
            op_units[k].omega <= `logN'd0;
        end
        if (rnd == ~`logN'd0) begin
            busy <= 0;
            stage <= 0;
        end
    end
    endcase
end

always @(posedge busy)
    stage <= 0;

always @(posedge start)
    busy <= 1;

always @(posedge rst)
    busy <= 0;
endmodule

module fft_op_unit(ar, ai, br, bi, cr, ci, dr, di, wr, wi);
input [63:0] ar, ai, br, bi;
output [63:0] cr, ci, dr, di;
input [63:0] wr, wi;
wire [63:0] tr, ti, t1, t2, t3, t4;
floating_point_multiplier mul1(
    .s_axis_a_tdata(br), .s_axis_a_tvalid(1'd1),
    .s_axis_b_tdata(wr), .s_axis_b_tvalid(1'd1),
    .m_axis_result_tdata(t1));
floating_point_multiplier mul2(
    .s_axis_a_tdata(bi), .s_axis_a_tvalid(1'd1),
    .s_axis_b_tdata(wi), .s_axis_b_tvalid(1'd1),
    .m_axis_result_tdata(t2));
floating_point_multiplier mul3(
    .s_axis_a_tdata(bi), .s_axis_a_tvalid(1'd1),
    .s_axis_b_tdata(wr), .s_axis_b_tvalid(1'd1),
    .m_axis_result_tdata(t3));
floating_point_multiplier mul4(
    .s_axis_a_tdata(br), .s_axis_a_tvalid(1'd1),
    .s_axis_b_tdata(wi), .s_axis_b_tvalid(1'd1),
    .m_axis_result_tdata(t4));
floating_point_adder adder(
    .s_axis_a_tdata(t1), .s_axis_a_tvalid(1'd1),
    .s_axis_b_tdata(t2), .s_axis_b_tvalid(1'd1),
    .m_axis_result_tdata(tr));
floating_point_subtracter subtracter(
    .s_axis_a_tdata(t3), .s_axis_a_tvalid(1'd1),
    .s_axis_b_tdata(t4), .s_axis_b_tvalid(1'd1),
    .m_axis_result_tdata(ti));
floating_point_adder adder_r(
    .s_axis_a_tdata(ar), .s_axis_a_tvalid(1'd1),
    .s_axis_b_tdata(tr), .s_axis_b_tvalid(1'd1),
    .m_axis_result_tdata(cr));
floating_point_adder adder_i(
    .s_axis_a_tdata(ai), .s_axis_a_tvalid(1'd1),
    .s_axis_b_tdata(ti), .s_axis_b_tvalid(1'd1),
    .m_axis_result_tdata(ci));
floating_point_subtracter subtracter_r(
    .s_axis_a_tdata(ar), .s_axis_a_tvalid(1'd1),
    .s_axis_b_tdata(tr), .s_axis_b_tvalid(1'd1),
    .m_axis_result_tdata(dr));
floating_point_subtracter subtracter_i(
    .s_axis_a_tdata(ai), .s_axis_a_tvalid(1'd1),
    .s_axis_b_tdata(ti), .s_axis_b_tvalid(1'd1),
    .m_axis_result_tdata(di));
endmodule

module bit_reverse(din, dout);
input [`logN-1:0] din;
output [`logN-1:0] dout;
genvar i;
for (i = 0; i < `logN; i = i + 1) begin
    assign dout[i] = din[`logN - 1 - i];
end
endmodule
