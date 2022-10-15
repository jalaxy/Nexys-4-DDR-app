module DAC_I2C(input clk, input [7:0] div, inout sda, output scl, output [7:0] anode, output [6:0] cathode, output dp);
parameter N = 100_000;
integer n = 0, m = 0;
assign scl = (n < N / 2) ? 0 : 1;
integer state = 0;
// state:
// 0: idle
// 1: preperation of a sending
// 2: host start a sending
// 3: host ---buffer--> slave
// 4: host <-ACK/NACK-- slave
integer i = 0, j = 0;
reg sda_r = 1, sda_link = 0;
assign sda = sda_link ? sda_r : 1'bz;
reg [7:0] buffer = 8'b100_1000_0;
wire [31:0] U;
assign U = 330 * div / 256;
integer_display inst_display (.n(U), .clk(clk), .blink(0), .blink_ena(0), .anode(anode), .cathode(cathode));
assign dp = anode[2];
always @(posedge clk)
begin
    n = n + 1;
    if (n == N)
        n = 0;
    else if (n == N / 4)
    begin
        // at the middle of the down signal
        case (state)
        0:
            if (m == 100)
                state = 1;
            else
                m = m + 1;
        1: state = 1;
        2:
            begin
                sda_link = 1;
                sda_r = 1;
            end
        3:
            begin
                sda_link = 1;
                sda_r = buffer[7 - i];
            end
        4:
            begin
                sda_link = 0;
                if (j == 0)
                begin
                    buffer = 8'b0_1_00_0_0_00;
                    j = 1;
                end
                else
                begin
                    buffer = div;
                    j = 2;
                end
            end
        default: state = state;
        endcase
    end
    else if (n == 3 * N / 4)
    begin
        // at the middle of the up signal
        case (state)
        1: state = 2;
        2:
            begin
                sda_r = 0;
                i = 0;
                state = 3;
            end
        3:
            if (i < 7)
                i = i + 1;
            else
                state = 4;
        4: 
            begin
                i = 0;
                state = 3;
            end
        default: state = state;
        endcase
    end
    else n = n;
end
endmodule