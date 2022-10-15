module CP0(clk, rst, addr, wea, data_in, data_out, pc, timer_int, exc, exc_type);
    // input and output
    input clk;          // cpu clock
    input rst;          // cpu reset
    input [4:0] addr;   // address
    input wea;          // write enable signal
    input [31:0] data_in;   // input data
    output [31:0] data_out; // output data
    // the four ports above are related to mfc0, mfc0
    input [31:0] pc;       // current pc
    output timer_int;      // timer interrupt
    output exc;            // exception happens (including eret)
    input [7:0] exc_type;  // the type of exception
    /* Type of exception
     * 0x00: interrupt
     * 0x08: syscall
     * 0x09: break
     * 0x0a: reserved instruction
     * 0x0c: overflow
     * 0x0d: trap
     * 0x20: eret
     * 0xff: no exception
     */

    wire [31:0] din[0:31];  // input data of each register
    wire [31:0] dout[0:31]; // output data of each register
    wire [31:0] ena;        // write enable signal of each register
    reg timer_int_r;        // register of timer interrupt
    wire timer_rst;
    wire timer_equ;
    Reg32 count(clk, rst, 1'd1, din[9], dout[9]);
    Reg32 compare(clk, rst, ena[11], din[11], dout[11]);
    Reg32 status(clk, rst, ena[12] | exc, din[12], dout[12]);
    Reg32 cause(clk, rst, ena[13] | (exc_type < 8'h20), din[13], dout[13]);
    Reg32 epc(clk, rst, ena[14] | exc & exc_type != 8'h20, din[14], dout[14]);

    // notice: in real use maybe not all the bits are writable
    assign ena = {31'd0, wea} << addr;
    assign din[9]  = ena[9]  ? data_in : dout[9] + 32'd1; // count
    assign din[11] = ena[11] ? data_in : 32'dz;           // compare
    assign din[12] = ena[12] ? data_in :                  // status
                    (exc_type == 8'h20 ? {dout[12][31:2], 1'b0, dout[12][0]} :
                    (exc ? {dout[12][31:2], 1'b1, dout[12][0]} : 32'hz));
    assign din[13] = ena[13] ? data_in : // cause
                    (exc_type < 8'h20 ?
                        {dout[13][31:10], 2'b00, dout[13][7], exc_type[4:0], dout[13][1:0]} : 32'dz);
    assign din[14] = wea & addr == 5'd14 ? data_in : // epc
                    (exc & exc_type != 8'h20 ? pc : 32'dz);
    assign data_out = exc_type == 8'h20 ? dout[14] : (wea ? 32'dz : dout[addr]);
    // output the epc when getting instruction eret
    assign timer_int = timer_int_r;
    assign timer_rst = rst | wea & addr == 5'd11 | dout[11] == 32'd0;
    assign timer_equ = dout[9] == dout[11];
    assign exc = exc_type != 8'hff;

    always @(posedge timer_equ or posedge timer_rst)
        timer_int_r = timer_rst ? 1'd0 : 1'd1;
endmodule