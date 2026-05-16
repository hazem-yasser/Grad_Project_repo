`timescale 1ns / 1ps

module rom_L1_b (
    input  logic [4:0] addr,
    output logic [15:0] data
);

    always_comb begin
        case (addr)
            5'd0: data = 16'h04F5;
            5'd1: data = 16'h1970;
            5'd2: data = 16'h1DCC;
            5'd3: data = 16'h1A0C;
            5'd4: data = 16'hFBFB;
            5'd5: data = 16'hDE72;
            5'd6: data = 16'hE5BB;
            5'd7: data = 16'h2362;
            5'd8: data = 16'hFF32;
            5'd9: data = 16'hF110;
            5'd10: data = 16'hF46F;
            5'd11: data = 16'h0739;
            5'd12: data = 16'h02D3;
            5'd13: data = 16'hF567;
            5'd14: data = 16'hFC44;
            5'd15: data = 16'hF8C1;
            5'd16: data = 16'h06EA;
            5'd17: data = 16'h03BF;
            5'd18: data = 16'h2467;
            5'd19: data = 16'hCB20;
            5'd20: data = 16'hFD90;
            5'd21: data = 16'hE589;
            5'd22: data = 16'hF007;
            5'd23: data = 16'hEC4D;
            5'd24: data = 16'hFEF4;
            5'd25: data = 16'h0384;
            5'd26: data = 16'hE4EE;
            5'd27: data = 16'h12AD;
            5'd28: data = 16'hDFD7;
            5'd29: data = 16'h03AA;
            5'd30: data = 16'hE00F;
            5'd31: data = 16'h2209;
            default: data = 16'd0;
        endcase
    end

endmodule
