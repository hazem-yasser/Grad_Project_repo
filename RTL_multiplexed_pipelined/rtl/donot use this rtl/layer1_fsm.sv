`timescale 1ns / 1ps

// ============================================================================
// Module: layer1_fsm
// Description: Layer-1 FSM controller and input mux (10 inputs, 4-cycle latency).
//              Latches the input window and drives the 3-input mux for the MACs.
// ============================================================================
module layer1_fsm (
    input  logic clk, rst_n,
    // From input_window
    input  logic [79:0] win_I_flat,
    input  logic [79:0] win_Q_flat,
    input  logic v_win,
    // To layer1_mac
    output logic signed [15:0] l1_in1, l1_in2, l1_in3,
    output logic [2:0]         l1_tick,
    output logic               l1_busy,
    output logic               v_l1
);

    logic signed [15:0] win_I [0:4];
    logic signed [15:0] win_Q [0:4];
    assign {win_I[4], win_I[3], win_I[2], win_I[1], win_I[0]} = win_I_flat;
    assign {win_Q[4], win_Q[3], win_Q[2], win_Q[1], win_Q[0]} = win_Q_flat;

    logic signed [15:0] l1_latched_I [0:4];
    logic signed [15:0] l1_latched_Q [0:4];

    // STRICT FSM: Idle -> Latch -> Compute (4) -> Fire
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l1_tick <= 0; l1_busy <= 0; v_l1 <= 0;
        end else begin
            v_l1 <= 0; // Pulse logic

            if (v_win && !l1_busy) begin
                // START: Latch data and enter BUSY
                l1_busy <= 1;
                l1_tick <= 1;
                for (int i = 0; i < 5; i++) begin
                    l1_latched_I[i] <= win_I[i];
                    l1_latched_Q[i] <= win_Q[i];
                end
            end else if (l1_busy) begin
                if (l1_tick == 4) begin
                    l1_busy <= 0;
                    v_l1    <= 1; // FIRE VALID only after 4 ticks
                end else begin
                    l1_tick <= l1_tick + 1;
                end
            end
        end
    end

    // Input mux: feeds 3 inputs per cycle from the latched window
    always_comb begin
        case (l1_tick)
            1: {l1_in1, l1_in2, l1_in3} = {l1_latched_I[0], l1_latched_I[1], l1_latched_I[2]};
            2: {l1_in1, l1_in2, l1_in3} = {l1_latched_I[3], l1_latched_I[4], l1_latched_Q[0]};
            3: {l1_in1, l1_in2, l1_in3} = {l1_latched_Q[1], l1_latched_Q[2], l1_latched_Q[3]};
            4: {l1_in1, l1_in2, l1_in3} = {l1_latched_Q[4], 16'sd0,           16'sd0};
            default: {l1_in1, l1_in2, l1_in3} = 48'd0;
        endcase
    end

endmodule
