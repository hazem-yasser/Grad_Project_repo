`timescale 1ns / 1ps

module input_window_ctrl (
    input  logic clk, rst_n,
    input  logic valid_in,
    input  logic signed [15:0] in_I, in_Q,
    output logic signed [15:0] win_I [0:4],
    output logic signed [15:0] win_Q [0:4],
    output logic valid_out
);

    localparam signed [15:0] INIT_VAL = 16'shD99A; // -9830
    localparam int TIMEOUT_CYCLES = 50;

    logic [2:0] fill_cnt;
    logic [2:0] flush_cnt;
    logic [7:0] silence_timer;
    logic flushing_active;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fill_cnt <= 0; flush_cnt <= 0; silence_timer <= 0; flushing_active <= 0;
            valid_out <= 0;
            for (int i=0; i<5; i++) begin win_I[i] <= INIT_VAL; win_Q[i] <= INIT_VAL; end
        end else begin
            valid_out <= 0; // Default: Pulse Low

            if (valid_in) silence_timer <= 0;
            else if (fill_cnt >= 3 && !flushing_active && flush_cnt == 0) begin
                if (silence_timer < TIMEOUT_CYCLES) silence_timer <= silence_timer + 1;
                else flushing_active <= 1;
            end

            if (valid_in) begin
                for (int i=0; i<4; i++) begin win_I[i] <= win_I[i+1]; win_Q[i] <= win_Q[i+1]; end
                win_I[4] <= in_I; win_Q[4] <= in_Q;

                if (fill_cnt < 3) begin
                    fill_cnt <= fill_cnt + 1;
                    if (fill_cnt == 2) valid_out <= 1; // Pulse ONCE on 3rd symbol
                end else valid_out <= 1; // Pulse ONCE per symbol
            end 
            else if (flushing_active) begin
                if (flush_cnt == 0 || flush_cnt == 6) begin
                    for (int i=0; i<4; i++) begin win_I[i] <= win_I[i+1]; win_Q[i] <= win_Q[i+1]; end
                    win_I[4] <= INIT_VAL; win_Q[4] <= INIT_VAL;
                    valid_out <= 1; 
                end
                if (flush_cnt < 7)
                    flush_cnt <= flush_cnt + 1;
                else
                    flushing_active <= 0;
            end
        end
    end

endmodule
