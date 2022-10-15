`timescale 10ps/10ps
module CPU31(clk, rst,
             addr_imem, data_imem, 
             addr_dmem, data_dmem, wea_dmem, clk_dmem);
    // IO
    input clk, rst;
    output [31:0] addr_imem; // instruction memory
    input [31:0] data_imem;
    output [31:0] addr_dmem; // data memory
    inout [31:0] data_dmem;
    output wea_dmem, clk_dmem;

    // definition
    wire clk0, clk1, clk2, clk3; // clocks
    reg [1:0] phase;
    wire dm_wea, rt_in; // control signal
    wire [3:0] aluc;
    wire [1:0] m0, m1, m3;
    wire m2, m4, m5, m6;
    wire ADD,   ADDU,  SUB,   SUBU,  AND,   OR,    XOR,   NOR,
         SLT,   SLTU,  SLL,   SRL,   SRA,   SLLV,  SRLV,  SRAV,
         JR,    ADDI,  ADDIU, ANDI,  ORI,   XORI,  LUI,   SLTI,
         SLTIU, LW,    SW,    BEQ,   BNE,   J,     JAL;
    reg [31:0] pc; // pc register
    wire [31:0] npc;
    wire [5:0] op, func; // instructions
    wire [4:0] rsc_imem, rtc_imem, rdc_imem, sa;
    wire [25:0] imm26;
    wire [15:0] imm16;
    wire [4:0] rsc_rf, rtc_rf, rdc_rf; // register file
    wire [31:0] rs, rt, rd;
    wire [31:0] a, b, r; // ALU
    wire zero, overflow;

    //clocks
    assign clk1 = clk;
    assign clk2 = clk;
    assign clk3 = ~clk;
    // assign clk0 = ~phase[1] & ~phase[0];
    // assign clk1 = ~phase[1] & phase[0];
    // assign clk2 = phase[1] & ~phase[0];
    // assign clk3 = phase[1] & phase[0];
    // always @(posedge clk or posedge rst)
    //     phase = rst ? 2'd0 : phase + 1;

    // control signal
    assign ADD   = op == 6'b000000 && func == 6'b100000;
    assign ADDU  = op == 6'b000000 && func == 6'b100001;
    assign SUB   = op == 6'b000000 && func == 6'b100010;
    assign SUBU  = op == 6'b000000 && func == 6'b100011;
    assign AND   = op == 6'b000000 && func == 6'b100100;
    assign OR    = op == 6'b000000 && func == 6'b100101;
    assign XOR   = op == 6'b000000 && func == 6'b100110;
    assign NOR   = op == 6'b000000 && func == 6'b100111;
    assign SLT   = op == 6'b000000 && func == 6'b101010;
    assign SLTU  = op == 6'b000000 && func == 6'b101011;
    assign SLL   = op == 6'b000000 && func == 6'b000000;
    assign SRL   = op == 6'b000000 && func == 6'b000010;
    assign SRA   = op == 6'b000000 && func == 6'b000011;
    assign SLLV  = op == 6'b000000 && func == 6'b000100;
    assign SRLV  = op == 6'b000000 && func == 6'b000110;
    assign SRAV  = op == 6'b000000 && func == 6'b000111;
    assign JR    = op == 6'b000000 && func == 6'b001000;
    assign ADDI  = op == 6'b001000;
    assign ADDIU = op == 6'b001001;
    assign ANDI  = op == 6'b001100;
    assign ORI   = op == 6'b001101;
    assign XORI  = op == 6'b001110;
    assign SLTI  = op == 6'b001010;
    assign SLTIU = op == 6'b001011;
    assign LUI   = op == 6'b001111;
    assign LW    = op == 6'b100011;
    assign SW    = op == 6'b101011;
    assign BEQ   = op == 6'b000100;
    assign BNE   = op == 6'b000101;
    assign J     = op == 6'b000010;
    assign JAL   = op == 6'b000011;
    assign rt_in = ADDI | ADDIU | ANDI | ORI | XORI | LUI | SLTI | SLTIU | LW;
    assign dm_wea = SW;
    assign aluc = {SLT | SLTU | SLL | SRL | SRA | SLLV | SRLV | SRAV | LUI  | SLTI | SLTIU,
                   AND | OR   | XOR | NOR | SLL | SRL  | SRA  | SLLV | SRLV | SRAV | ANDI | ORI | XORI,
                   ADD | SUB  | XOR | NOR | SLT | SLTU | SLL  | SLLV | ADDI | XORI | SLTI | SLTIU,
                   SUB | SUBU | OR  | NOR | SLT | SRL  | SRLV | ORI  | SLTI | BEQ  | BNE};
    assign m0 = {JR | J | JAL, JR | BEQ | BNE};
    assign m1 = {ADD  | ADDU | SUB | SUBU | AND | OR | XOR | NOR | SLT | SLTU | SLL | SRL | SRA | SLLV |
                 SRLV | SRAV, JAL};
    assign m2 = SLL | SRL | SRA;
    assign m3 = {ADD  | ADDU | SUB | SUBU | AND | OR | XOR | NOR | SLT | SLTU | SLL | SRL | SRA | SLLV |
                 SRLV | SRAV | JR  | BEQ  | BNE | J  | JAL, ADDI | ADDIU | SLTI | SLTIU | LW | SW};
    assign m4 = LW;
    assign m5 = BNE;
    assign m6 = JAL;

    // instruction memory
    assign addr_imem = pc;
    assign op = data_imem[31:26];
    assign rsc_imem = data_imem[25:21];
    assign rtc_imem = data_imem[20:16];
    assign rdc_imem = data_imem[15:11];
    assign sa = data_imem[10:6];
    assign func = data_imem[5:0];
    assign imm26 = data_imem[25:0];
    assign imm16 = data_imem[15:0];

    // data memory
    assign wea_dmem = dm_wea;
    assign clk_dmem = clk1;
    assign addr_dmem = r;
    assign data_dmem = dm_wea & ~rt_in ? rt : 32'dz;

    // register file
    RegFile /*regfile*/cpu_ref(clk2, rst, rsc_rf, rtc_rf, rdc_rf, rs, rt, rd, rt_in);
    assign rsc_rf = rsc_imem;
    assign rtc_rf = rtc_imem;
    assign rdc_rf = m1 == 2'b00 ? 5'd0 : (m1 == 2'b01 ? 5'd31 : rdc_imem);
    assign rd = m6 ? pc + /*8*/4 : r;
    assign rt = rt_in ? (m4 ? data_dmem : r) : 32'dz;

    // ALU
    ALU alu(a, b, aluc, r, zero, overflow);
    assign a = m2 ? {27'd0, sa} : rs;
    assign b = m3 == 2'b00 ? {16'd0, imm16} :
              (m3 == 2'b01 ? {{16{imm16[15]}}, imm16} : (rt_in ? 32'dz : rt));

    assign npc = m0 == 2'b00 ? pc + 4 :
                (m0 == 2'b01 ? (zero ^ m5 ? pc + 4 + {{14{imm16[15]}}, imm16, 2'b00} : pc + 4) :
                (m0 == 2'b10 ? {pc[31:28], imm26, 2'b00} : rs));
    always @(posedge clk3 or posedge rst)
        pc = rst ? 32'h00400000 : npc;
endmodule