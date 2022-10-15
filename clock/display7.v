module display7(input [3:0] iData, output reg [6:0] oData);
    always @(iData)
    begin
        case(iData)
            4'd0: oData = 7'b1000000;
            4'd1: oData = 7'b1111001;
            4'd2: oData = 7'b0100100;
            4'd3: oData = 7'b0110000;
            4'd4: oData = 7'b0011001;
            4'd5: oData = 7'b0010010;
            4'd6: oData = 7'b0000010;
            4'd7: oData = 7'b1111000;
            4'd8: oData = 7'b0000000;
            4'd9: oData = 7'b0010000;
            default: oData = 7'b1111111;
        endcase
    end
endmodule