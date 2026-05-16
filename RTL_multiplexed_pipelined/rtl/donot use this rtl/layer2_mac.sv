`timescale 1ns / 1ps

// ============================================================================
// Module: layer2_mac
// Description: Layer-2 MAC array — 32 neurons, dual-bank 6-cycle accumulate,
//              ReLU output. ROM: L2A_W_ROM[192], L2B_W_ROM[192], L2_b_ROM[32]
// ============================================================================
module layer2_mac (
    input  logic clk, rst_n,
    // Control from layer2_fsm
    input  logic signed [15:0] l2a_in1, l2a_in2, l2a_in3,
    input  logic signed [15:0] l2b_in1, l2b_in2, l2b_in3,
    input  logic [2:0]         l2_tick,
    input  logic               l2_busy,
    input  logic               v_l1,
    // Outputs
    output logic [511:0] l2_out_flat
);

    logic [47:0]        L2A_W_ROM [0:191];
    logic [47:0]        L2B_W_ROM [0:191];
    logic signed [15:0] L2_b_ROM  [0:31];
    initial begin
        $readmemh("hex_files/L2A_W.hex", L2A_W_ROM);
        $readmemh("hex_files/L2B_W.hex", L2B_W_ROM);
        $readmemh("hex_files/L2_b.hex",  L2_b_ROM);
    end

    // Internal output registers (avoids multi-driver on array output port)
    logic signed [15:0] out_reg [0:31];

    genvar i;
    generate
        for (i = 0; i < 32; i++) begin : L2_MAC
            logic [47:0]        w_bus_a, w_bus_b;
            assign w_bus_a = (l2_busy) ? L2A_W_ROM[(i*6) + (l2_tick-1)] : 48'd0;
            assign w_bus_b = (l2_busy) ? L2B_W_ROM[(i*6) + (l2_tick-1)] : 48'd0;

            logic signed [39:0] acc;
            logic signed [31:0] p1, p2, p3, p4, p5, p6;

            assign p1 = l2a_in1 * $signed(w_bus_a[47:32]);
            assign p2 = l2a_in2 * $signed(w_bus_a[31:16]);
            assign p3 = l2a_in3 * $signed(w_bus_a[15:0]);

            assign p4 = l2b_in1 * $signed(w_bus_b[47:32]);
            assign p5 = l2b_in2 * $signed(w_bus_b[31:16]);
            assign p6 = l2b_in3 * $signed(w_bus_b[15:0]);

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) acc <= 0;
                else if (v_l1 && !l2_busy) acc <= 0;
                else if (l2_busy && l2_tick == 6 && v_l1) acc <= 0;
                else if (l2_busy) acc <= acc + (p1 + p2) + (p3 + p4) + (p5 + p6);
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) out_reg[i] <= 0;
                else if (l2_busy && l2_tick == 6) begin
                    logic signed [39:0] final_acc;
                    logic signed [39:0] tmp;
                    final_acc = acc + (p1 + p2) + (p3 + p4) + (p5 + p6);
                    tmp = (final_acc >>> 14) + L2_b_ROM[i];
                    if (tmp < 0) tmp = 0; // ReLU
                    if (tmp > 32767)       out_reg[i] <= 32767;
                    else if (tmp < -32768) out_reg[i] <= -32768;
                    else                   out_reg[i] <= tmp[15:0];
                end
            end

            assign l2_out_flat[i*16+15 : i*16] = out_reg[i];
        end
    endgenerate

endmodule
