`timescale 1ns / 1ps

// --- 1. Standard Triple MAC (Used in Layer 1: 10 inputs) ---
// This unit does NOT need a partial sum input because L1 is small.
module neuron_triple_mac #(parameter bit USE_RELU = 1) (
    input  logic        clk, rst_n,
    input  logic        acc_clear, mac_en, apply_act,
    input  logic signed [15:0] in1, in2, in3,
    input  logic [47:0]        w_triple, // Packed {w3, w2, w1}
    input  logic signed [15:0] bias,
    output logic signed [15:0] out_val
);
    logic signed [39:0] acc, act_v;
    logic signed [15:0] w1, w2, w3;
    
    // Unpack weights
    assign {w3, w2, w1} = w_triple;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc <= '0;
            out_val <= '0;
        end else begin
            if (acc_clear) begin
                acc <= '0;
            end else if (mac_en) begin
                acc <= acc + 40'(in1*w1) + 40'(in2*w2) + 40'(in3*w3);
            end

            if (apply_act) begin
                act_v = (acc >>> 14) + 40'(bias);
                if (USE_RELU && act_v < 0) 
                    out_val <= 16'd0;
                else 
                    out_val <= (act_v > 32767) ? 16'sd32767 : (act_v < -32768) ? -16'sd32768 : 16'(act_v);
            end
        end
    end
endmodule

// --- 2. Triple Stage A (Partial Accumulator for L2/L3) ---
module neuron_triple_stage_A (
    input  logic        clk, rst_n,
    input  logic        acc_clear, mac_en,
    input  logic signed [15:0] in1, in2, in3,
    input  logic [47:0]        w_triple,
    output logic signed [39:0] partial_acc
);
    logic signed [15:0] w1, w2, w3;
    assign {w3, w2, w1} = w_triple;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) partial_acc <= '0;
        else if (acc_clear) partial_acc <= '0;
        else if (mac_en)    partial_acc <= partial_acc + 40'(in1*w1) + 40'(in2*w2) + 40'(in3*w3);
    end
endmodule

// --- 3. Triple Stage B (Final Accumulator & Activation for L2/L3) ---
module neuron_triple_stage_B #(parameter bit USE_RELU = 1) (
    input  logic        clk, rst_n,
    input  logic        acc_clear, mac_en, apply_act,
    input  logic signed [15:0] in1, in2, in3,
    input  logic [47:0]        w_triple,
    input  logic signed [15:0] bias,
    input  logic signed [39:0] partial_acc_in,
    output logic signed [15:0] out_val
);
    logic signed [39:0] acc, act_v;
    logic signed [15:0] w1, w2, w3;
    assign {w3, w2, w1} = w_triple;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) {acc, out_val} <= '0;
        else begin
            if (acc_clear) acc <= partial_acc_in; // LOAD partial sum from Stage A
            else if (mac_en) acc <= acc + 40'(in1*w1) + 40'(in2*w2) + 40'(in3*w3);
            
            if (apply_act) begin
                act_v = (acc >>> 14) + 40'(bias);
                if (USE_RELU && act_v < 0) 
                    out_val <= 16'd0;
                else 
                    out_val <= (act_v > 32767) ? 16'sd32767 : (act_v < -32768) ? -16'sd32768 : 16'(act_v);
            end
        end
    end
endmodule
