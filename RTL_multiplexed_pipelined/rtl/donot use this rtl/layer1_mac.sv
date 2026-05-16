`timescale 1ns / 1ps

// ============================================================================
// Module: layer1_mac
// Description: Layer-1 MAC array — 32 neurons, 4-cycle accumulate, ReLU output.
//              Weights and biases loaded from hex files.
//              ROM: L1_W_ROM[128], L1_b_ROM[32]
// ============================================================================
module layer1_mac (
    input  logic clk, rst_n,
    // Control from layer1_fsm
    input  logic signed [15:0] l1_in1, l1_in2, l1_in3,
    input  logic [2:0]         l1_tick,
    input  logic               l1_busy,
    input  logic               v_win,
    // Outputs
    output logic [511:0] l1_out_flat
);

    logic [47:0]        L1_W_ROM [0:127];
    logic signed [15:0] L1_b_ROM [0:31];
    initial begin
        $readmemh("hex_files/L1_W.hex", L1_W_ROM);
        $readmemh("hex_files/L1_b.hex", L1_b_ROM);
    end

    // Internal output registers (avoids multi-driver on array output port)
    logic signed [15:0] out_reg [0:31];

    genvar i;
    generate
        for (i = 0; i < 32; i++) begin : L1_MAC
            logic [47:0]        w_bus;
            assign w_bus = (l1_busy) ? L1_W_ROM[(i*4) + (l1_tick-1)] : 48'd0;

            logic signed [39:0] acc;
            logic signed [31:0] p1, p2, p3;

            // CORRECT WEIGHT ORDERING: [47:32]=w0, [31:16]=w1, [15:0]=w2
            assign p1 = l1_in1 * $signed(w_bus[47:32]);
            assign p2 = l1_in2 * $signed(w_bus[31:16]);
            assign p3 = l1_in3 * $signed(w_bus[15:0]);

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) acc <= 0;
                else if (v_win && !l1_busy) acc <= 0; // Clear on start
                else if (l1_busy) acc <= (p1 + p2) + (p3 + acc);
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) out_reg[i] <= 0;
                else if (l1_busy && l1_tick == 4) begin
                    logic signed [39:0] final_acc;
                    logic signed [39:0] tmp;
                    final_acc = (p1 + p2) + (p3 + acc);
                    tmp = (final_acc >>> 14) + L1_b_ROM[i];
                    if (tmp < 0) tmp = 0; // ReLU
                    if (tmp > 32767)       out_reg[i] <= 32767;
                    else if (tmp < -32768) out_reg[i] <= -32768;
                    else                   out_reg[i] <= tmp[15:0];
                end
            end

            assign l1_out_flat[i*16+15 : i*16] = out_reg[i];
        end
    endgenerate

endmodule
