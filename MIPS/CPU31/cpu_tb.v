`timescale 10ps/1ps
module cpu_tb();
    reg clk, rst;
    wire [31:0] inst, pc;
    sccomp_dataflow uut(clk, rst, inst, pc);
    integer i, j, fo;
    reg [31:0] pc_pre, inst_pre, cnt;
    initial
    begin
        clk = 0;
        rst = 1;
        cnt = 0;
        pc_pre = 32'h00400000;
        inst_pre = 32'h3c1d1001;
        fo = $fopen("C:/Users/china/OneDrive/_English_directory_without_space/verilog/MIPS/output.txt");
        #205;
        rst = 0;
    end
    always
    begin
        #50;
        clk = ~clk;
        if (clk == 1'b0 && rst == 0)
        begin
            if (cnt < 1100)
            begin
                cnt = cnt + 1;
                $fdisplay(fo, "pc: %h", pc_pre);
                $fdisplay(fo, "instr: %h", inst_pre);
                for (j = 0; j < 32; j = j + 1)
                    $fdisplay(fo, "regfile%1d: %h", j, cpu_tb.uut.sccpu.cpu_ref.array_reg[j]);
            end
        end
        else if (clk == 1'b1 && rst == 0)
        begin
            pc_pre = pc;
            inst_pre = inst;
        end
    end
endmodule