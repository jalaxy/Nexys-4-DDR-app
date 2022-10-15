module CPU(clk, rst, addr_imem, data_imem,
           addr_dmem, data_dmem_in, data_dmem_out, wea_dmem,
           clk_dmem, sign_dmem, width_dmem, err_dmem);
    // IO
    input clk, rst;
    output [31:0] addr_imem; // instruction memory
    input [31:0] data_imem;
    output [31:0] addr_dmem; // data memory
    output [31:0] data_dmem_in;
    input [31:0] data_dmem_out;
    output wea_dmem, clk_dmem, sign_dmem;
    output [1:0] width_dmem;
    input err_dmem;

    // definition
    wire clk0, clk1, clk2, clk3; // clocks
    reg [1:0] phase;
    wire rt_in, dm_wea; // control signal
    wire [3:0] aluc;
    wire [1:0] m0, m1, m3, m4, m5, m6, m7, m8, m9;
    wire m2, me;
    wire m_sign, d_sign;
    wire [1:0] width;
    wire sign;
    wire c0_wea, trap, division;
    wire [7:0] exc_t;
    wire ADD,   ADDU,  SUB,   SUBU,  AND,     OR,    XOR,   NOR,
         SLT,   SLTU,  SLL,   SRL,   SRA,     SLLV,  SRLV,  SRAV,
         JR,    ADDI,  ADDIU, ANDI,  ORI,     XORI,  LUI,   SLTI,
         SLTIU, LW,    SW,    BEQ,   BNE,     J,     JAL,   DIV,
         DIVU,  MULT,  MULTU, BGEZ,  JALR,    LBU,   LHU,   LB,
         LH,    SB,    SH,    BREAK, SYSCALL, ERET,  MFHI,  MFLO,
         MTHI,  MTLO,  MFC0,  MTC0,  CLZ,     TEQ,   MUL;
    reg [31:0] pc; // pc register
    wire [31:0] npc;
    reg [31:0] hi, lo; // HI and LO register
    wire [31:0] nhi, nlo;
    wire [5:0] op, func; // instructions
    wire [4:0] rsc_imem, rtc_imem, rdc_imem, sa;
    wire [25:0] imm26;
    wire [15:0] imm16;
    wire [4:0] rsc_rf, rtc_rf, rdc_rf; // register file
    wire [31:0] rs, rti, rto, rd;
    wire [31:0] a, b, r, a_mul, b_mul, a_div, b_div, q_div, r_div; // ALU
    wire [63:0] r_mul;
    wire zero, overflow, negative, sign_mul, sign_div, divided_by_zero;
    wire [31:0] zero_num; // the number of leading zeros
    wire [4:0] addr_c0; // CP0
    wire wea_c0;
    wire [31:0] data_c0_in, data_c0_out;
    wire timer_int, exc;
    wire [7:0] exc_type;
    parameter exc_handler_address = 32'h00400004;

    // clocks
    // posedge order: 1 -> 2 -> 3 -> 0
    assign clk1 = clk;
    assign clk2 = clk;
    assign clk3 = ~clk;
    always @(posedge clk or posedge rst)
        phase = rst ? 2'd0 : phase + 1;

    // control signal
    assign {rt_in, dm_wea, aluc, m0, m1, m2, m3, m4, m5, m6, m7, m8, m9, me, m_sign, d_sign, division, width, sign, c0_wea, trap, exc_t} =
           {ADDI | ADDIU | ANDI | ORI | XORI | LUI | SLTI | SLTIU | LW | LBU | LHU | LB | LH | MFC0,
            SW | SB | SH,
            SLT | SLTU | SLL | SRL | SRA | SLLV | SRLV | SRAV | LUI | SLTI | SLTIU,
            AND | OR | XOR | NOR | SLL | SRL | SRA | SLLV | SRLV | SRAV | ANDI | ORI | XORI,
            ADD | SUB | XOR | NOR | SLT | SLTU | SLL | SLLV | ADDI | XORI | SLTI | SLTIU,
            SUB | SUBU | OR | NOR | SLT | SRL | SRLV | ORI | SLTI | BEQ | BNE | BGEZ | TEQ,
            JR | J | JAL | JALR | ERET,
            JR | BEQ | BNE | BGEZ | JALR,
            ADD | ADDU | SUB | SUBU | AND | OR | XOR | NOR | SLT | SLTU | SLL | SRL | SRA | SLLV | SRLV | SRAV | MUL | MFHI | MFLO | CLZ,
            JAL | JALR,
            SLL | SRL | SRA,
            ADDI | ADDIU | ANDI | ORI | XORI | LUI | SLTI | SLTIU | LW | SW | LBU | LHU | LB | LH | SB | SH,
            ADDI | ADDIU | SLTI | SLTIU | LW | SW | BGEZ | LBU | LHU | LB | LH | SB | SH,
            MFC0,
            LW | LBU | LHU | LB | LH,
            BGEZ,
            BNE,
            MUL | MFHI | MFLO | CLZ,
            JAL | JALR | CLZ,
            DIV | DIVU | MULT | MULTU | MUL,
            DIV | DIVU | MTHI,
            DIV | DIVU | MULT | MULTU | MUL,
            DIV | DIVU | MTLO,
            MUL,
            MFLO,
            BREAK | SYSCALL | ERET,
            MULT | MUL,
            DIV,
            DIV | DIVU,
            LW | SW,
            LW | SW | LHU | LH | SH,
            LB | LH,
            MTC0,
            TEQ,
            2'b00, ERET, 1'b0, BREAK | SYSCALL, 2'b00, BREAK};

    assign ADD     = op == 6'b000000 & func == 6'b100000;
    assign ADDU    = op == 6'b000000 & func == 6'b100001;
    assign SUB     = op == 6'b000000 & func == 6'b100010;
    assign SUBU    = op == 6'b000000 & func == 6'b100011; assign ADDI    = op == 6'b001000;
    assign AND     = op == 6'b000000 & func == 6'b100100; assign ADDIU   = op == 6'b001001;
    assign OR      = op == 6'b000000 & func == 6'b100101; assign ANDI    = op == 6'b001100;
    assign XOR     = op == 6'b000000 & func == 6'b100110; assign ORI     = op == 6'b001101;
    assign NOR     = op == 6'b000000 & func == 6'b100111; assign XORI    = op == 6'b001110;
    assign SLT     = op == 6'b000000 & func == 6'b101010; assign SLTI    = op == 6'b001010;
    assign SLTU    = op == 6'b000000 & func == 6'b101011; assign SLTIU   = op == 6'b001011;
    assign SLL     = op == 6'b000000 & func == 6'b000000; assign LUI     = op == 6'b001111;
    assign SRL     = op == 6'b000000 & func == 6'b000010; assign LW      = op == 6'b100011;
    assign SRA     = op == 6'b000000 & func == 6'b000011; assign SW      = op == 6'b101011;
    assign SLLV    = op == 6'b000000 & func == 6'b000100; assign BEQ     = op == 6'b000100;
    assign SRLV    = op == 6'b000000 & func == 6'b000110; assign BNE     = op == 6'b000101;
    assign SRAV    = op == 6'b000000 & func == 6'b000111; assign J       = op == 6'b000010;
    assign JR      = op == 6'b000000 & func == 6'b001000; assign JAL     = op == 6'b000011;
    assign DIV     = op == 6'b000000 & func == 6'b011010;
    assign DIVU    = op == 6'b000000 & func == 6'b011011;
    assign MULT    = op == 6'b000000 & func == 6'b011000;
    assign MULTU   = op == 6'b000000 & func == 6'b011001;
    assign MUL     = op == 6'b011100 & sa == 5'b00000 & func == 6'b000010;
    assign BGEZ    = op == 6'b000001 & rtc_imem == 5'b00001;
    assign JALR    = op == 6'b000000 & rtc_imem == 5'b00000 & func == 6'b001001;
    assign LBU     = op == 6'b100100;
    assign LHU     = op == 6'b100101;
    assign LB      = op == 6'b100000;
    assign LH      = op == 6'b100001;
    assign SB      = op == 6'b101000;
    assign SH      = op == 6'b101001;
    assign BREAK   = op == 6'b000000 & func == 6'b001101;
    assign SYSCALL = op == 6'b000000 & func == 6'b001100;
    assign ERET    = data_imem == 32'b010000_10000_00000_00000_00000_011000;
    assign MFHI    = op == 6'b000000 & rsc_imem == 5'b00000 & rtc_imem == 5'b00000 & sa == 5'b00000 & func == 6'b010000;
    assign MFLO    = op == 6'b000000 & rsc_imem == 5'b00000 & rtc_imem == 5'b00000 & sa == 5'b00000 & func == 6'b010010;
    assign MTHI    = op == 6'b000000 & rtc_imem == 5'b00000 & rdc_imem == 5'b00000 & sa == 5'b00000 & func == 6'b010001;
    assign MTLO    = op == 6'b000000 & rtc_imem == 5'b00000 & rdc_imem == 5'b00000 & sa == 5'b00000 & func == 6'b010011;
    assign MFC0    = op == 6'b010000 & rsc_imem == 5'b00000 & sa == 5'b00000 & func == 6'b000000;
    assign MTC0    = op == 6'b010000 & rsc_imem == 5'b00100 & sa == 5'b00000 & func == 6'b000000;
    assign CLZ     = op == 6'b011100 & sa == 5'b00000 & func == 6'b100000;
    assign TEQ     = op == 6'b000000 & func == 6'b110100;

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
    assign wea_dmem = dm_wea & ~exc;
    assign clk_dmem = clk1;
    assign addr_dmem = r;
    assign data_dmem_in = dm_wea ? rto : 32'dz;
    assign sign_dmem = sign;
    assign width_dmem = width;

    // register file
    RegFile regfile(clk2, rst, rsc_rf, rtc_rf, rdc_rf, rs, rti, rto, rd, rt_in & ~exc);
    assign rsc_rf = rsc_imem;
    assign rtc_rf = rtc_imem;
    assign rdc_rf = (m1 & {2{~exc}}) == 2'b00 ? 5'd0 : ((m1 & {2{~exc}}) == 2'b01 ? 5'd31 : rdc_imem);
    assign rd = m6[1] ? (m6[0] ? zero_num : (m9[1] ? r_mul[31:0] : (m9[0] ? lo : hi))) : (m6[0] ? pc + /*8*/4 : r);
    assign rti = m4[1] ? data_c0_out : (m4[0] ? data_dmem_out : r);

    // ALU
    ALU alu(a, b, aluc, r, zero, overflow, negative);
    MUL mul(a_mul, b_mul, r_mul, sign_mul);
    DIV div(a_div, b_div, q_div, r_div, sign_div, divided_by_zero);
    assign a = m2 ? {27'd0, sa} : rs;
    assign b = m3 == 2'b10 ? {16'd0, imm16} :
              (m3 == 2'b11 ? {{16{imm16[15]}}, imm16} :
              (m3 == 2'b01 ? 32'd0 : rto));
    assign a_mul = rs;
    assign b_mul = rto;
    assign a_div = rs;
    assign b_div = rto;
    assign sign_mul = m_sign;
    assign sign_div = d_sign;
    assign zero_num = rs[31] ? 32'd00 : (rs[30] ? 32'd01 : (rs[29] ? 32'd02 : (rs[28] ? 32'd03 :
                      rs[27] ? 32'd04 : (rs[26] ? 32'd05 : (rs[25] ? 32'd06 : (rs[24] ? 32'd07 :
                      rs[23] ? 32'd08 : (rs[22] ? 32'd09 : (rs[21] ? 32'd10 : (rs[20] ? 32'd11 :
                      rs[19] ? 32'd12 : (rs[18] ? 32'd13 : (rs[17] ? 32'd14 : (rs[16] ? 32'd15 :
                      rs[15] ? 32'd16 : (rs[14] ? 32'd17 : (rs[13] ? 32'd18 : (rs[12] ? 32'd19 :
                      rs[11] ? 32'd20 : (rs[10] ? 32'd21 : (rs[09] ? 32'd22 : (rs[08] ? 32'd23 :
                      rs[07] ? 32'd24 : (rs[06] ? 32'd25 : (rs[05] ? 32'd26 : (rs[04] ? 32'd27 :
                      rs[03] ? 32'd28 : (rs[02] ? 32'd29 : (rs[01] ? 32'd30 : (rs[00] ? 32'd31 :
                      32'd32))))))))))))))))))))))));

    // CP0
    CP0 cp0(clk2, rst, addr_c0, wea_c0, data_c0_in, data_c0_out, pc, timer_int, exc, exc_type);
    assign data_c0_in = rto;
    assign addr_c0 = rdc_imem;
    assign wea_c0 = c0_wea;
    assign exc_type = me ? exc_t : (overflow ? 8'hc : (trap & zero ? 8'hd :
                          (err_dmem ? (dm_wea ? 8'h5 : 8'h4) : 8'hff)));

    assign npc = {exc, m0} == 3'b000 ? pc + 4 :
                ({exc, m0} == 3'b001 ? ((m5[1] ? ~negative : zero ^ m5[0]) ? pc + 4 + {{14{imm16[15]}}, imm16, 2'b00} : pc + 4) :
                ({exc, m0} == 3'b010 ? {pc[31:28], imm26, 2'b00} :
                ({exc, m0} == 3'b011 ? rs :
                ({exc, m0[1]} == 2'b10 ? exc_handler_address :
                ({exc, m0[1]} == 2'b11 ? data_c0_out : 32'dz)))));
    assign nhi = (m7 & {2{~(divided_by_zero & division)}}) == 2'b00 ? hi :
                ((m7 & {2{~(divided_by_zero & division)}}) == 2'b01 ? rs :
                ((m7 & {2{~(divided_by_zero & division)}}) == 2'b10 ? r_mul[63:32] : r_div));
    assign nlo = (m8 & {2{~(divided_by_zero & division)}}) == 2'b00 ? lo :
                ((m8 & {2{~(divided_by_zero & division)}}) == 2'b01 ? rs :
                ((m8 & {2{~(divided_by_zero & division)}}) == 2'b10 ? r_mul[31:0] : q_div));
    always @(posedge clk3 or posedge rst)
        pc = rst ? 32'h00400000 : npc;
    always @(posedge clk2 or posedge rst)
        hi = rst ? 32'h00000000 : nhi;
    always @(posedge clk2 or posedge rst)
        lo = rst ? 32'h00000000 : nlo;
endmodule