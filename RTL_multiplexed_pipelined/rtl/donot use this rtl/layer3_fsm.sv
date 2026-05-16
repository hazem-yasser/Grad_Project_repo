`timescale 1ns / 1ps

// ============================================================================
// Module: layer3_fsm
// Description: Layer-3 FSM controller and dual-bank input mux
//              (32 inputs split into bank-A [0:15] and bank-B [16:31]),
//              6-cycle latency. Supports back-to-back throughput re-latching.
// ============================================================================
module layer3_fsm (
    input  logic clk, rst_n,
    // From layer2_mac
    input  logic [511:0] l2_out_flat,
    input  logic               v_l2,
    // To layer3_mac
    output logic signed [15:0] l3a_in1, l3a_in2, l3a_in3,
    output logic signed [15:0] l3b_in1, l3b_in2, l3b_in3,
    output logic [2:0]         l3_tick,
    output logic               l3_busy,
    output logic               v_l3
);

    logic signed [15:0] l2_out [0:31];
    generate
        for (genvar j=0; j<32; j++) begin : UNPACK_L2
            assign l2_out[j] = l2_out_flat[j*16+15 : j*16];
        end
    endgenerate

    logic signed [15:0] l3_latched_in [0:31];

    // STRICT FSM (with re-latch for back-to-back throughput)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l3_tick <= 0; l3_busy <= 0; v_l3 <= 0;
        end else begin
            v_l3 <= 0;
            if (v_l2 && !l3_busy) begin
                l3_busy <= 1; l3_tick <= 1;
                for (int i = 0; i < 32; i++) l3_latched_in[i] <= l2_out[i];
            end else if (l3_busy) begin
                if (l3_tick == 6) begin
                    v_l3 <= 1;
                    if (v_l2) begin
                        l3_tick <= 1;
                        for (int i = 0; i < 32; i++) l3_latched_in[i] <= l2_out[i];
                    end else begin
                        l3_busy <= 0;
                    end
                end else l3_tick <= l3_tick + 1;
            end
        end
    end

    // Reuse L2 MUX logic structure but for L3 inputs
    always_comb begin
        if (l3_busy) begin
            case (l3_tick)
                1: begin
                    {l3a_in1, l3a_in2, l3a_in3} = {l3_latched_in[0],  l3_latched_in[1],  l3_latched_in[2]};
                    {l3b_in1, l3b_in2, l3b_in3} = {l3_latched_in[16], l3_latched_in[17], l3_latched_in[18]};
                end
                2: begin
                    {l3a_in1, l3a_in2, l3a_in3} = {l3_latched_in[3],  l3_latched_in[4],  l3_latched_in[5]};
                    {l3b_in1, l3b_in2, l3b_in3} = {l3_latched_in[19], l3_latched_in[20], l3_latched_in[21]};
                end
                3: begin
                    {l3a_in1, l3a_in2, l3a_in3} = {l3_latched_in[6],  l3_latched_in[7],  l3_latched_in[8]};
                    {l3b_in1, l3b_in2, l3b_in3} = {l3_latched_in[22], l3_latched_in[23], l3_latched_in[24]};
                end
                4: begin
                    {l3a_in1, l3a_in2, l3a_in3} = {l3_latched_in[9],  l3_latched_in[10], l3_latched_in[11]};
                    {l3b_in1, l3b_in2, l3b_in3} = {l3_latched_in[25], l3_latched_in[26], l3_latched_in[27]};
                end
                5: begin
                    {l3a_in1, l3a_in2, l3a_in3} = {l3_latched_in[12], l3_latched_in[13], l3_latched_in[14]};
                    {l3b_in1, l3b_in2, l3b_in3} = {l3_latched_in[28], l3_latched_in[29], l3_latched_in[30]};
                end
                6: begin
                    {l3a_in1, l3a_in2, l3a_in3} = {l3_latched_in[15], 16'd0,             16'd0};
                    {l3b_in1, l3b_in2, l3b_in3} = {l3_latched_in[31], 16'd0,             16'd0};
                end
                default: begin {l3a_in1, l3a_in2, l3a_in3} = 48'd0; {l3b_in1, l3b_in2, l3b_in3} = 48'd0; end
            endcase
        end else begin
            {l3a_in1, l3a_in2, l3a_in3} = 48'd0; {l3b_in1, l3b_in2, l3b_in3} = 48'd0;
        end
    end

endmodule
