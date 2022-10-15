module clock(CLK, rst, pause, oData, dp);
    input CLK;
    input rst;
    input pause;
    output [31:0] oData;
    output reg [7:0] dp = 8'b10101010;
    wire O_CLK;
    reg [3:0] ms1 = 0, ms2 = 0, s1 = 0, s2 = 0, m1 = 0, m2 = 0, h1 = 0, h2 = 0;
    reg pause_reg = 1;
    reg [5:0] dpTime = 0;
    assign oData = {h2, h1, m2, m1, s2, s1, ms2, ms1};
    divider100Hz divider_inst(.I_CLK(CLK), .O_CLK(O_CLK));
    always @(posedge pause)
    begin
        pause_reg = !pause_reg;
    end
    always @(posedge O_CLK)
    begin
        if (dpTime == 50 && pause_reg == 0)
        begin
            dpTime = 1;
            dp[0] = ~dp[0];
            dp[2] = ~dp[2];
            dp[4] = ~dp[4];
            dp[6] = ~dp[6];
        end
        else if (pause_reg == 0)
            dpTime = dpTime + 1;
        else dpTime = dpTime;
        if (pause_reg == 0)
        begin
            ms1 = ms1 + 1;
            if (ms1 == 10)
            begin
                ms1 = 0;
                ms2 = ms2 + 1;
            end
            else
                ms1 = ms1;
            if (ms2 == 10)
            begin
                ms2 = 0;
                s1 = s1 + 1;
            end
            else
                ms2 = ms2;
            if (s1 == 10)
            begin
                s1 = 0;
                s2 = s2 + 1;
            end
            else
                s1 = s1;
            if (s2 == 6)
            begin
                s2 = 0;
                m1 = m1 + 1;
            end
            else
                s2 = s2;
            if (m1 == 10)
            begin
                m1 = 0;
                m2 = m2 + 1;
            end
            else
                m1 = m1;
            if (m2 == 6)
            begin
                m2 = 0;
                h1 = h1 + 1;
            end
            else
                m2 = m2;
            if (h1 == 10)
            begin
                h1 = 0;
                h2 = h2 + 1;
            end
            else
                h1 = h1;
            if (h2 == 10)
            begin
                h2 = 0;
            end
            else
                h2 = h2;
        end
        else pause_reg = pause_reg;
        if (rst == 1)
        begin
            dpTime = 0;
            dp = 8'b10101010;
            {ms1, ms2, s1, s2, m1, m2, h1, h2} = 32'd0;
        end
        else pause_reg = pause_reg;
    end
endmodule