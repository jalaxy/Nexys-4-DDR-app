module sccomp_dataflow(
    input clk_in,
    input reset,
    output [31:0] inst,
    output [31:0] pc
);
    wire [31:0] addr_imem, addr_dmem;
    wire [31:0] data_imem, data_dmem_in, data_dmem_out;
    wire wea_dmem, clk_dmem, sign_dmem, err_dmem;
    wire [1:0] width_dmem;

    CPU sccpu(clk_in, reset, addr_imem, data_imem, addr_dmem, data_dmem_in, data_dmem_out, wea_dmem, clk_dmem, sign_dmem, width_dmem, err_dmem);

    parameter virtual_imem  = 32'h00400000;
    parameter physical_imem = 32'h00000000;
    parameter virtual_excp  = 32'h00400000;
    parameter physical_excp = 32'h00000000;
    wire [31:0] addr_imem_map;
    assign addr_imem_map = (addr_imem - virtual_imem + physical_imem) >> 2;
    ROM imem(.a(addr_imem_map), .spo(data_imem));

    parameter virtual_dmem = 32'h10010000;
    wire [31:0] addr_dmem_map;
    assign addr_dmem_map = addr_dmem - virtual_dmem;
    RAM dmem(clk_dmem, addr_dmem_map, wea_dmem, width_dmem, sign_dmem, data_dmem_in, data_dmem_out, err_dmem);

    assign pc = sccpu.pc;
    assign inst = sccpu.data_imem;
endmodule