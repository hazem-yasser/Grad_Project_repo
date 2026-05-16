`timescale 1ns / 1ps

module rom_L3B_W (
    input  logic [3:0] addr,
    output logic [47:0] data
);

    always_comb begin
        case (addr)
            4'd0: data = 48'hF83914530C23;
            4'd1: data = 48'h034DFF72C3B3;
            4'd2: data = 48'h022F158DFA0E;
            4'd3: data = 48'h0AEBF4BE1E6B;
            4'd4: data = 48'h035BCB39C507;
            4'd5: data = 48'hD52F00000000;
            4'd6: data = 48'h2A8DF26F0740;
            4'd7: data = 48'h10EB45080043;
            4'd8: data = 48'h1FD9AD95103E;
            4'd9: data = 48'h2E13D8FDF9AD;
            4'd10: data = 48'hC96AFAC5FE79;
            4'd11: data = 48'hFBC300000000;
            default: data = 48'd0;
        endcase
    end

endmodule
