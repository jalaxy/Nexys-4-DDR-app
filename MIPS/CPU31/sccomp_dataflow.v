module sccomp_dataflow(
    input clk_in,
    input reset,
    output [31:0] inst,
    output [31:0] pc
);
    wire [31:0] addr_imem, addr_dmem;
    wire [31:0] data_imem, data_dmem;
    wire wea_dmem, clk_dmem;

    CPU31 sccpu(clk_in, reset, addr_imem, data_imem, addr_dmem, data_dmem, wea_dmem, clk_dmem);

    parameter offset_imem = 32'h00400000;
    wire [31:0] addr_imem_map;
    assign addr_imem_map = (addr_imem - offset_imem) >> 2;
    rom imem(.a(addr_imem_map), .spo(data_imem));

    parameter offset_dmem = 32'h10010000;
    wire [31:0] addr_dmem_map;
    assign addr_dmem_map = (addr_dmem - offset_dmem) >> 2;
    Memory dmem(clk_dmem, addr_dmem_map, 1'b1, wea_dmem, data_dmem);
    // // IP CORE RAM -> delay -> 0.1ns
    // wire [31:0] data_dmem_i, data_dmem_o;
    // assign data_dmem_i = wea_dmem ? data_dmem : 32'bz;
    // assign data_dmem = wea_dmem ? 32'bz : data_dmem_o;
    // ram dmem(.a(addr_dmem_map), .d(data_dmem_i), .clk(clk_dmem), .we(wea_dmem), .spo(data_dmem_o));

    assign pc = sccpu.pc;
    assign inst = sccpu.data_imem;
endmodule