`timescale 1ns / 1ps

module neural_eq_top (
    input  logic clk, rst_n,
    input  logic valid_in,
    input  logic signed [15:0] in_I, in_Q,
    output logic signed [15:0] out_I, out_Q,
    output logic valid_out
);

    // Internal signals
    wire signed [15:0] win_I [0:4];
    wire signed [15:0] win_Q [0:4];
    wire v_win;

    wire signed [15:0] l1_out [0:31];
    wire v_l1;

    wire signed [15:0] l2_out [0:31];
    wire v_l2;
    
    wire signed [15:0] l3_out [0:1];

    // ========================================================================
    // MODULE INSTANTIATIONS
    // ========================================================================

    // INPUT WINDOW
    input_window_ctrl u_input_window (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .in_I(in_I),
        .in_Q(in_Q),
        .win_I(win_I),
        .win_Q(win_Q),
        .valid_out(v_win)
    );

    // LAYER 1
    layer1_compute u_layer1 (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(v_win),
        .win_I(win_I),
        .win_Q(win_Q),
        .l1_out(l1_out),
        .valid_out(v_l1)
    );

    // LAYER 2
    layer2_compute u_layer2 (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(v_l1),
        .l1_out(l1_out),
        .l2_out(l2_out),
        .valid_out(v_l2)
    );

    // LAYER 3
    layer3_compute u_layer3 (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(v_l2),
        .l2_out(l2_out),
        .l3_out(l3_out),
        .valid_out(valid_out)
    );
    
    // Map layer3 outputs to top-level outputs
    assign out_I = l3_out[0];
    assign out_Q = l3_out[1];

endmodule
