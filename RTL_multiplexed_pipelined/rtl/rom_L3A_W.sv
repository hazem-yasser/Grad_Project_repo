`timescale 1ns / 1ps

module rom_L3A_W (
    input  logic [3:0] addr,
    output logic [47:0] data
);

    always_comb begin
        case (addr)
            4'd0: data = 48'hD6F8D805228E;
            4'd1: data = 48'hFAE831A93B54;
            4'd2: data = 48'h105718BEA892;
            4'd3: data = 48'hE96BB736F4E4;
            4'd4: data = 48'hD9AD0BBC0000;
            4'd5: data = 48'hF9AA00000000;
            4'd6: data = 48'h073A18AFF742;
            4'd7: data = 48'hF8010C382C00;
            4'd8: data = 48'hEF6D2E1EFE5B;
            4'd9: data = 48'h0451FEF3EF9C;
            4'd10: data = 48'hEEDBF0100000;
            4'd11: data = 48'h50C900000000;
            default: data = 48'd0;
        endcase
    end

endmodule
