`timescale 1ns / 1ps

module rom_L3_b (
    input  logic [0:0] addr,
    output logic [15:0] data
);

    always_comb begin
        case (addr)
            1'd0: data = 16'h010A;
            1'd1: data = 16'hFD0B;
            default: data = 16'd0;
        endcase
    end

endmodule
