module temperature(input clk, inout sda, output reg scl = 0, output [7:0] anode, output [6:0] cathode, output dp);
reg get = 0;
reg [7:0] data = 8'b100_1011_1;
reg [7:0] msb, lsb;
wire [15:0] tmp;
assign tmp = ({msb, lsb} >> 3) * 625 / 1000;
reg sda_r = 1, sda_link = 0;
assign sda = sda_link ? sda_r : 1'bz;
integer n = 0, m = 0, i = 0;
integer_display integer_display_inst(.n(tmp), .clk(clk), .blink(0), .blink_ena(0), .anode(anode), .cathode(cathode));
assign dp = anode[1];
always @(posedge clk)
begin
    if (n == 500)
    begin
        if (get == 1)
        begin
            if (i == 0)
                if (scl == 0)
                    i = 0;
                else
                begin
                    sda_r = 0;
                    i = 1;
                end
            else if (i <= 8)
                if (scl == 0)
                    sda_r = data[8 - i];
                else
                    i = i + 1;
            else if (i == 9)
                if (scl == 0)
                    sda_link = 0;
                else
                    i = 10;
            else if (i <= 17)
                if (scl == 0)
                    i = i;
                else
                begin
                    msb[17 - i] = sda;
                    i = i + 1;
                end
            else if (i == 18)
                if (scl == 0)
                begin
                    sda_link = 1;
                    sda_r = 0;
                end
                else
                    i = 19;
            else if (i <= 26)
                if (scl == 0)
                    sda_link = 0;
                else
                begin
                    lsb[26 - i] = sda;
                    i = i + 1;
                end
            else if (i == 27)
                if (scl == 0)
                begin
                    sda_r = 0;
                    sda_link = 1;
                end
                else
                begin
                    sda_r = 1;
                    i = 28;
                end
            else
            begin
                i = 0;
                sda_r = 1;
                sda_link = 0;
                get = 0;
            end
        end
        scl = ~scl;
        if (m == 100_000)
        begin
            sda_r = 1;
            sda_link = 1;
            data = 8'b100_1011_1;
            get = 1;
            m = 1;
        end
        else
            m = m + 1;
        n = 1;
    end
    else
        n = n + 1;
end
endmodule