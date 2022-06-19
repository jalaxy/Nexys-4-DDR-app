`include "top.vh"
module fft(clk, rst, sig, we, rev, addr, din, dout);
input clk, rst, sig;
input we, rev;
input [`logN-1:0] addr;
input [`CW-1:0] din;
output [`CW-1:0] dout;

reg busy, finish;
wire clk_run;
reg [`logS-1:0] stage;
wire [`logN-1:0] addr_rev;
wire [`logN-1:0] addr_phy;
reg [`logN-1:0] rnd; // even though rnd is in (0, logN] instead [0, N)
reg [`logNpM-2:0] iter;
reg [`logCyc-1:0] cycle;
genvar igen;
wire we_calc;
reg [`logNpM-1:0] addra_calc[0:`M], addrb_calc[0:`M]; // address during FFT calculation (register)
wire [`logM-1:0] grpa[0:`M], grpb[0:`M]; // memory unit number of a and b
wire [`logNpM-1:0] idxa[0:`M], idxb[0:`M]; // index of a and b within a unit
reg [`CW-1:0] dina_calc[0:`M], dinb_calc[0:`M]; // input data during FFT calculation (register)
wire [`CW-1:0] douta_calc[0:`M], doutb_calc[0:`M]; // output data during FFT calculation
reg [`CW-1:0] opa[0:`M], opb[0:`M]; // oprands a and b
wire [`CW-1:0] opc[0:`M], opd[0:`M]; // operands c and d
reg [`logM:0] k; // iterator

bit_reverse inst_rev(addr, addr_rev);
assign clk_run = clk & busy;
assign addr_phy = rev ? addr_rev : addr;
assign we_calc = cycle == `logCyc'd4 | cycle == `logCyc'd5;
for (igen = 0; igen < `M; igen = igen + 1) begin : mem_units // RAM units
    wire wea, web; // write enable signal of port A and B
    wire [`logNpM-1:0] addra, addrb; // addresses within an RAM unit
    wire [`CW-1:0] dina, dinb, douta, doutb; // data
    bram_data inst_data_r(
        .wea(wea), .addra({`logNpM'd0, addra}), .dina(`r(dina)), .douta(`r(douta)), .clka(clk),
        .web(web), .addrb({`logNpM'd0, addrb}), .dinb(`r(dinb)), .doutb(`r(doutb)), .clkb(clk)); // real part bram
    bram_data inst_data_i(
        .wea(wea), .addra({`logNpM'd0, addra}), .dina(`i(dina)), .douta(`i(douta)), .clka(clk),
        .web(web), .addrb({`logNpM'd0, addrb}), .dinb(`i(dinb)), .doutb(`i(doutb)), .clkb(clk)); // imaginary part bram
    assign wea   = busy ? (stage == `logS'd1 ? we_calc : 1'd0) : (igen == addr_phy[`logN-1:`logNpM]) & we;
    assign web   = busy ? (stage == `logS'd1 ? we_calc : 1'd0) : 1'd0;
    assign addra = busy ? (stage == `logS'd1 ? addra_calc[igen] : `logNpM'dz) : addr_phy[`logNpM-1:0];
    assign addrb = busy ? (stage == `logS'd1 ? addrb_calc[igen] : `logNpM'dz) : `logNpM'dz;
    assign dina  = busy ? (stage == `logS'd1 ? dina_calc[igen] : `CW'dz) : din;
    assign dinb  = busy ? (stage == `logS'd1 ? dinb_calc[igen] : `CW'dz) : `CW'dz;
    assign dout  = igen == addr_phy[`logN-1:`logNpM] ? douta : `CW'dz;
    assign douta_calc[igen] = douta;
    assign doutb_calc[igen] = doutb;
end
for (igen = 0; igen < `M; igen = igen + 1) begin : op_units // Operator units
    wire [`CW-1:0] w; // operand w
    wire [`logN-1:0] addra, addrb; // address of oprand a and b
    wire [`logN-2:0] omega; // argument omega
    wire [`logN-1:0] addr_op; // address of operation
    fft_op_unit op(`r(opa[igen]), `i(opa[igen]), `r(opb[igen]), `i(opb[igen]),
        `r(opc[igen]), `i(opc[igen]), `r(opd[igen]), `i(opd[igen]), `r(w), `i(w)); // operator unit
    brom_cos4096 inst_cos(.addra({`logNpM'd0, omega}), .clka(clk_run), .douta(`r(w))); // cos storage
    brom_sin4096 inst_sin(.addra({`logNpM'd0, omega}), .clka(clk_run), .douta(`i(w))); // sin storage
    assign addr_op = rnd > `logNpM ?
        {igen[`logM-1:0], igen[`logM-1:0] & (`logM'd1 << (rnd - 1 - `logNpM)) ? 1'd1 : 1'd0, iter} :
        {igen[`logM-1:0], iter, 1'd0} & (~`logN'd0 << (rnd - 1)) | iter & ~(~`logN'd0 << (rnd - 1));
    assign addra = addr_op & ~(`logN'd1 << (rnd - 1));
    assign addrb = addr_op | (`logN'd1 << (rnd - 1));
    assign grpa[igen] = addra[`logN-1:`logNpM];
    assign grpb[igen] = addrb[`logN-1:`logNpM];
    assign idxa[igen] = addra[`logNpM-1:0];
    assign idxb[igen] = addrb[`logNpM-1:0];
    assign omega = addra << (`logN - rnd);
end

always @(posedge clk)
begin
    if (rst | ~busy) begin
        stage <= `logS'd0;
        finish <= 1'd0;
    end
    else case (stage)
        `logS'd0: begin // preperation stage
            rnd <= `logN'd1;
            iter <= `logNpM'd0;
            cycle <= 1'd0;
            stage <= `logS'd1;
            finish <= 1'd0;
        end
        `logS'd1: begin // calculation stage
            if (cycle == `logCyc'd0) begin // 0: calculation of addresses
                for (k = 0; k < `M; k = k + 1) begin // k is operator unit number
                    if (rnd > `logNpM) begin
                        if (k[0]) begin
                            addrb_calc[grpa[k]] <= idxa[k];
                            addrb_calc[grpb[k]] <= idxb[k];
                        end else begin
                            addra_calc[grpa[k]] <= idxa[k];
                            addra_calc[grpb[k]] <= idxb[k];
                        end
                    end else begin
                        addra_calc[grpa[k]] <= idxa[k];
                        addrb_calc[grpb[k]] <= idxb[k];
                    end
                end
                cycle <= 1;
            end else if (cycle == `logCyc'd2) begin // 2: read oprands from memory (1 clock latency)
                for (k = 0; k < `M; k = k + 1) begin
                    if (rnd > `logNpM) begin
                        if (k[0]) begin
                            opa[k] <= doutb_calc[grpa[k]];
                            opb[k] <= doutb_calc[grpb[k]];
                        end else begin
                            opa[k] <= douta_calc[grpa[k]];
                            opb[k] <= douta_calc[grpb[k]];
                        end
                    end else begin
                        opa[k] <= douta_calc[grpa[k]];
                        opb[k] <= doutb_calc[grpb[k]];
                    end
                end
                cycle <= 3;
            end else if (cycle == `logCyc'd3) begin // 3: write result into buffer
                for (k = 0; k < `M; k = k + 1) begin
                    if (rnd > `logNpM) begin
                        if (k[0]) begin
                            dinb_calc[grpa[k]] <= opc[k];
                            dinb_calc[grpb[k]] <= opd[k];
                        end else begin
                            dina_calc[grpa[k]] <= opc[k];
                            dina_calc[grpb[k]] <= opd[k];
                        end
                    end else begin
                        dina_calc[grpa[k]] <= opc[k];
                        dinb_calc[grpb[k]] <= opd[k];
                    end
                end
                cycle <= 4;
            end else if (cycle == `logCyc'd5) begin // 5: write buffer into memory (1 clock latency) and reset
                if ({1'd1, iter} == ~`logNpM'd0) begin
                    if (rnd == `logN) begin
                        finish <= 1'd1;
                        stage <= `logS'd0;
                    end
                    rnd <= rnd + 1;
                end
                iter <= iter + 1;
                cycle <= 1'd0;
            end else cycle <= cycle + 1;
        end
        default: begin
            stage <= `logS'd0;
        end
    endcase
end

always @(posedge sig or posedge rst or posedge finish)
    busy <= rst ? 1'd0 : (finish ? 1'd0 : 1'd1);
endmodule

module fft_op_unit(ar, ai, br, bi, cr, ci, dr, di, wr, wi);
input [`FW-1:0] ar, ai, br, bi;
output [`FW-1:0] cr, ci, dr, di;
input [`FW-1:0] wr, wi;
wire [`FW-1:0] tr, ti, t1, t2, t3, t4;
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
