`timescale 1ns / 1ps

// ============================================================================
// Module: layer3_mac
// Description: Layer-3 MAC array — 2 output neurons (I & Q), dual-bank
//              6-cycle accumulate, saturation-only output (no ReLU).
//              ROM: L3A_W_ROM[12], L3B_W_ROM[12], L3_b_ROM[2]
// ============================================================================
module layer3_mac (
    input  logic clk, rst_n,
    // Control from layer3_fsm
    input  logic signed [15:0] l3a_in1, l3a_in2, l3a_in3,
    input  logic signed [15:0] l3b_in1, l3b_in2, l3b_in3,
    input  logic [2:0]         l3_tick,
    input  logic               l3_busy,
    input  logic               v_l2,
    input  logic               v_l3,  // valid pulse from layer3_fsm
    // Outputs
    output logic signed [15:0] out_I, out_Q,
    output logic               valid_out
);

    // Pass through the registered valid pulse from the FSM
    assign valid_out = v_l3;

    logic [47:0]        L3A_W_ROM [0:11];
    logic [47:0]        L3B_W_ROM [0:11];
    logic signed [15:0] L3_b_ROM  [0:1];
    initial begin
        $readmemh("hex_files/L3A_W.hex", L3A_W_ROM);
        $readmemh("hex_files/L3B_W.hex", L3B_W_ROM);
        $readmemh("hex_files/L3_b.hex",  L3_b_ROM);
    end

    // Internal per-neuron output registers (avoids multi-driver on ports)
    logic signed [15:0] neuron_out [0:1];
    assign out_I = neuron_out[0];
    assign out_Q = neuron_out[1];

    genvar i;
    generate
        for (i = 0; i < 2; i++) begin : L3_MAC
            logic [47:0]        w_bus_a, w_bus_b;
            assign w_bus_a = (l3_busy) ? L3A_W_ROM[(i*6) + (l3_tick-1)] : 48'd0;
            assign w_bus_b = (l3_busy) ? L3B_W_ROM[(i*6) + (l3_tick-1)] : 48'd0;

            logic signed [39:0] acc;
            logic signed [31:0] p1, p2, p3, p4, p5, p6;

            assign p1 = l3a_in1 * $signed(w_bus_a[47:32]);
            assign p2 = l3a_in2 * $signed(w_bus_a[31:16]);
            assign p3 = l3a_in3 * $signed(w_bus_a[15:0]);
            assign p4 = l3b_in1 * $signed(w_bus_b[47:32]);
            assign p5 = l3b_in2 * $signed(w_bus_b[31:16]);
            assign p6 = l3b_in3 * $signed(w_bus_b[15:0]);

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) acc <= 0;
                else if (v_l2 && !l3_busy) acc <= 0;
                else if (l3_busy && l3_tick == 6 && v_l2) acc <= 0;
                else if (l3_busy) acc <= acc + (p1 + p2) + (p3 + p4) + (p5 + p6);
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) neuron_out[i] <= 0;
                else if (l3_busy && l3_tick == 6) begin
                    logic signed [39:0] final_acc;
                    logic signed [39:0] tmp;
                    final_acc = acc + (p1 + p2) + (p3 + p4) + (p5 + p6);
                    tmp = (final_acc >>> 14) + L3_b_ROM[i];

                    // SATURATE ONLY (No ReLU for Output)
                    if (tmp > 32767)       tmp = 32767;
                    else if (tmp < -32768) tmp = -32768;

                    neuron_out[i] <= tmp[15:0];
                end
            end
        end
    endgenerate

endmodule
