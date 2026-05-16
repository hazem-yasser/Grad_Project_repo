`timescale 1ns / 1ps

// ============================================================================
// Module: layer2_fsm
// Description: Layer-2 FSM controller and dual-bank input mux
//              (32 inputs split into bank-A [0:15] and bank-B [16:31]),
//              6-cycle latency. Supports back-to-back throughput re-latching.
// ============================================================================
module layer2_fsm (
    input  logic clk, rst_n,
    // From layer1_mac
    input  logic [511:0] l1_out_flat,
    input  logic               v_l1,
    // To layer2_mac
    output logic signed [15:0] l2a_in1, l2a_in2, l2a_in3,
    output logic signed [15:0] l2b_in1, l2b_in2, l2b_in3,
    output logic [2:0]         l2_tick,
    output logic               l2_busy,
    output logic               v_l2
);

    logic signed [15:0] l1_out [0:31];
    generate
        for (genvar j=0; j<32; j++) begin : UNPACK_L1
            assign l1_out[j] = l1_out_flat[j*16+15 : j*16];
        end
    endgenerate

    logic signed [15:0] l2_latched_in [0:31];

    // STRICT FSM (with re-latch for back-to-back throughput)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l2_tick <= 0; l2_busy <= 0; v_l2 <= 0;
        end else begin
            v_l2 <= 0;
            if (v_l1 && !l2_busy) begin
                l2_busy <= 1;
                l2_tick <= 1;
                for (int i = 0; i < 32; i++) l2_latched_in[i] <= l1_out[i];
            end else if (l2_busy) begin
                if (l2_tick == 6) begin
                    v_l2 <= 1;
                    if (v_l1) begin
                        l2_tick <= 1;
                        for (int i = 0; i < 32; i++) l2_latched_in[i] <= l1_out[i];
                    end else begin
                        l2_busy <= 0;
                    end
                end else begin
                    l2_tick <= l2_tick + 1;
                end
            end
        end
    end

    // Dual-bank input mux
    always_comb begin
        if (l2_busy) begin
            case (l2_tick)
                1: begin
                    {l2a_in1, l2a_in2, l2a_in3} = {l2_latched_in[0],  l2_latched_in[1],  l2_latched_in[2]};
                    {l2b_in1, l2b_in2, l2b_in3} = {l2_latched_in[16], l2_latched_in[17], l2_latched_in[18]};
                end
                2: begin
                    {l2a_in1, l2a_in2, l2a_in3} = {l2_latched_in[3],  l2_latched_in[4],  l2_latched_in[5]};
                    {l2b_in1, l2b_in2, l2b_in3} = {l2_latched_in[19], l2_latched_in[20], l2_latched_in[21]};
                end
                3: begin
                    {l2a_in1, l2a_in2, l2a_in3} = {l2_latched_in[6],  l2_latched_in[7],  l2_latched_in[8]};
                    {l2b_in1, l2b_in2, l2b_in3} = {l2_latched_in[22], l2_latched_in[23], l2_latched_in[24]};
                end
                4: begin
                    {l2a_in1, l2a_in2, l2a_in3} = {l2_latched_in[9],  l2_latched_in[10], l2_latched_in[11]};
                    {l2b_in1, l2b_in2, l2b_in3} = {l2_latched_in[25], l2_latched_in[26], l2_latched_in[27]};
                end
                5: begin
                    {l2a_in1, l2a_in2, l2a_in3} = {l2_latched_in[12], l2_latched_in[13], l2_latched_in[14]};
                    {l2b_in1, l2b_in2, l2b_in3} = {l2_latched_in[28], l2_latched_in[29], l2_latched_in[30]};
                end
                6: begin
                    {l2a_in1, l2a_in2, l2a_in3} = {l2_latched_in[15], 16'd0,             16'd0};
                    {l2b_in1, l2b_in2, l2b_in3} = {l2_latched_in[31], 16'd0,             16'd0};
                end
                default: begin {l2a_in1, l2a_in2, l2a_in3} = 48'd0; {l2b_in1, l2b_in2, l2b_in3} = 48'd0; end
            endcase
        end else begin
            {l2a_in1, l2a_in2, l2a_in3} = 48'd0; {l2b_in1, l2b_in2, l2b_in3} = 48'd0;
        end
    end

endmodule
