`timescale 1ns / 1ps

module rom_L2_b (
    input  logic [4:0] addr,
    output logic [15:0] data
);

    always_comb begin
        case (addr)
            5'd0: data = 16'h1924;
            5'd1: data = 16'hE606;
            5'd2: data = 16'h0D7C;
            5'd3: data = 16'h07DC;
            5'd4: data = 16'hEDF1;
            5'd5: data = 16'hE89B;
            5'd6: data = 16'hFF45;
            5'd7: data = 16'h0499;
            5'd8: data = 16'h0A80;
            5'd9: data = 16'h18CA;
            5'd10: data = 16'hFDE3;
            5'd11: data = 16'h036C;
            5'd12: data = 16'h1585;
            5'd13: data = 16'hFC85;
            5'd14: data = 16'hFF3B;
            5'd15: data = 16'hFBD3;
            5'd16: data = 16'h0D38;
            5'd17: data = 16'h143A;
            5'd18: data = 16'h01B6;
            5'd19: data = 16'hFF42;
            5'd20: data = 16'h0DE7;
            5'd21: data = 16'hF288;
            5'd22: data = 16'h08E6;
            5'd23: data = 16'h105B;
            5'd24: data = 16'hF841;
            5'd25: data = 16'h071E;
            5'd26: data = 16'h2606;
            5'd27: data = 16'h1C3A;
            5'd28: data = 16'hF624;
            5'd29: data = 16'hE92D;
            5'd30: data = 16'hDFD1;
            5'd31: data = 16'h07E6;
            default: data = 16'd0;
        endcase
    end

endmodule
