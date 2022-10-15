module ADC_I2C(input clk, inout sda, output scl, output [7:0] anode, output [6:0] cathode, output dp);
parameter N = 100_000;
integer n = 0, m = 0;
assign scl = (n < N / 2) ? 0 : 1;
integer state = 0, state_1 = 0;
// state:
// 0: idle
// 1: preperation of a sending
// 2: host start a sending
// 3: host ---buffer--> slave
// 4: host <-ACK/NACK-- slave
// 5: host <---data---- slave
// 6: host --ACK/NACK-> slave
integer i = 0;
reg sda_r = 1, sda_link = 0;
assign sda = sda_link ? sda_r : 1'bz;
reg [7:0] buffer = 8'b100_1000_0;
wire [31:0] U;
reg [7:0] div;
assign U = 330 * div / 256;
integer_display inst_display (.n(U), .clk(clk), .blink(0), .blink_ena(0), .anode(anode), .cathode(cathode));
assign dp = anode[2];
reg read = 1;
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
            begin
                m = 0;
                state = 1;
            end
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
                if (state_1 == 0)
                begin
                    buffer = 8'b0_0_00_0_0_00;
                    state_1 = 1;
                end
                else if (state_1 == 1)
                begin
                    sda_r = 0;
                    sda_link = 1;
                    state_1 = 2;
                end
                else if (state_1 == 2)
                    state_1 = 3;
            end
        5: sda_link = 0;
        6:
            begin
                sda_link = 1;
                sda_r = 0;
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
                if (state_1 < 2)
                    state = 3;
                else if (state_1 == 2)
                begin
                    sda_r = 1;
                    buffer = 8'b100_1000_1;
                    state = 2;
                end
                else if (state_1 == 3)
                begin
                    i = 0;
                    state = 5;
                end
            end
        5:
            begin
                div[7 - i] = read ? sda : div[7 - i];
                if (i < 7)
                    i = i + 1;
                else
                begin
                    read = 0;
                    state = 6;
                end
            end
        6:
            begin
                i = 0;
                m = m + 1;
                if (m == 50)
                begin
                    read = 1;
                    m = 0;
                end
                state = 5;
            end
        default: state = state;
        endcase
    end
    else n = n;
end
endmodule