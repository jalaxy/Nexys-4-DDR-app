module temperature(input clk, inout sda, output reg scl = 0, output [7:0] anode, output [6:0] cathode, output dp);
reg [7:0] addr_and_state = 8'b100_1011_1;
reg [7:0] msb, lsb;
wire [15:0] tmp;
assign tmp = ({msb, lsb} >> 3) * 625 / 1000;
reg sda_r = 1, sda_link = 0;
assign sda = sda_link ? sda_r : 1'bz;
integer_display integer_display_inst(.n(tmp), .clk(clk), .blink(0), .blink_ena(0), .anode(anode), .cathode(cathode));
assign dp = anode[1];
reg mid = 0, get_tmp = 0;
integer state = 0, i = 0, n = 0, n_1 = 0;
// state table:
// 0: start the i2c communication
// 1: transmit address and state message from the host to slave device
// 2: the host receive acknowledge message from the slave
// 3: transmit msb from the slave to the host
// 4: the host send an aknowledge message to the slave
// 5: transmit lsb from the slave to the host
// 6: end the i2c communication
always @(posedge clk)
begin
    // 250 = (frequency of clk) / (frequency of scl) / 2 (for converting) / 2 (for middle judging)
    if (n == 250)
    begin
        if (!mid)
            // frequency of scl is 100MHz / 2 / 500 = 100kHz
            scl = ~scl;
        else
        begin
            // handle the sdl data at the middle of every stable scl signal level
            if (!scl)
                // when scl is down
                if (get_tmp)
                    case(state)
                        0: state = 0;
                        1: sda_r = addr_and_state[7 - i];
                        2:
                            begin
                                sda_r = 1;
                                sda_link = 0;
                            end
                        3: sda_link = 0;
                        4:
                            begin
                                sda_r = 0;
                                sda_link = 1;
                            end
                        5: sda_link = 0;
                        6:
                            begin
                                sda_r = 0;
                                sda_link = 1;
                            end
                    endcase
                else
                    state = 0;
            else
                // when scl is up
                if (get_tmp)
                    case(state)
                        0:
                            begin
                                sda_link = 1;
                                sda_r = 0;
                                state = 1;
                                i = 0;
                            end
                        1:
                            if (i < 7)
                                i = i + 1;
                            else
                                state = 2;
                        2: 
                            begin
                                state = 3;
                                i = 0;
                            end
                        3:
                            begin
                                msb[7 - i] = sda;
                                if (i < 7)
                                    i = i + 1;
                                else
                                    state = 4;
                            end
                        4:
                            begin
                                state = 5;
                                i = 0;
                            end
                        5:
                            begin
                                lsb[7 - i] = sda;
                                if (i < 7)
                                    i = i + 1;
                                else
                                    state = 6;
                            end
                        6:
                            begin
                                sda_r = 1;
                                sda_link = 0;
                                state = 0;
                                get_tmp = 0;
                            end
                    endcase
                else
                    state = 0;
        end
        mid = ~mid;
        n = 1;
        if (n_1 == 50_000_000 / 250)
        begin
            get_tmp = 1;
            n_1 = 1;
        end
        else
            n_1 = n_1 + 1;
    end
    else
        n = n + 1;
end
endmodule