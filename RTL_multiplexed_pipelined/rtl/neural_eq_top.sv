`timescale 1ns / 1ps

// ============================================================================
// MATH CORES
// ============================================================================

module neuron_triple_mac #(parameter bit USE_RELU = 1) (
    input  logic        clk, rst_n, acc_clear, mac_en, apply_act,
    input  logic signed [15:0] in1, in2, in3,
    input  logic [47:0]        w_triple,
    input  logic signed [15:0] bias,
    output logic signed [15:0] out_val
);
    logic signed [39:0] acc;
    logic signed [15:0] w1, w2, w3;
    assign {w3, w2, w1} = w_triple;

    logic signed [31:0] p1, p2, p3;
    assign p1 = in1 * w1;
    assign p2 = in2 * w2;
    assign p3 = in3 * w3;

    logic signed [39:0] bias_ext;
    assign bias_ext = bias; 
    
    logic signed [39:0] act_v;
    assign act_v = (acc >>> 14) + bias_ext; 

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            acc <= 40'sd0; out_val <= 16'sd0; 
        end else begin
            if (acc_clear)      acc <= 40'sd0;
            else if (mac_en)    acc <= acc + p1 + p2 + p3;
            
            if (apply_act) begin
                if (USE_RELU && act_v < 0) out_val <= 16'sd0;
                else if (act_v > 32767)    out_val <= 16'sd32767;
                else if (act_v < -32768)   out_val <= -16'sd32768;
                else                       out_val <= act_v[15:0];
            end
        end
    end
endmodule

module neuron_triple_stage_A (
    input  logic        clk, rst_n, acc_clear, mac_en,
    input  logic signed [15:0] in1, in2, in3,
    input  logic [47:0]        w_triple,
    output logic signed [39:0] partial_acc
);
    logic signed [15:0] w1, w2, w3;
    assign {w3, w2, w1} = w_triple;

    logic signed [31:0] p1, p2, p3;
    assign p1 = in1 * w1;
    assign p2 = in2 * w2;
    assign p3 = in3 * w3;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)          partial_acc <= 40'sd0;
        else if (acc_clear)  partial_acc <= 40'sd0;
        else if (mac_en)     partial_acc <= partial_acc + p1 + p2 + p3;
    end
endmodule

module neuron_triple_stage_B #(parameter bit USE_RELU = 1) (
    input  logic        clk, rst_n, acc_clear, mac_en, apply_act,
    input  logic signed [15:0] in1, in2, in3,
    input  logic [47:0]        w_triple,
    input  logic signed [15:0] bias,
    input  logic signed [39:0] partial_acc_in,
    output logic signed [15:0] out_val
);
    logic signed [39:0] acc;
    logic signed [15:0] w1, w2, w3;
    assign {w3, w2, w1} = w_triple;

    logic signed [31:0] p1, p2, p3;
    assign p1 = in1 * w1;
    assign p2 = in2 * w2;
    assign p3 = in3 * w3;

    logic signed [39:0] bias_ext;
    assign bias_ext = bias;
    
    // FIX: Add Stage A and Stage B together COMBINATIONALLY. 
    // This removes the 1-symbol delay and fixes the desynchronization.
    logic signed [39:0] act_v;
    assign act_v = ((acc + partial_acc_in) >>> 14) + bias_ext;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            acc <= 40'sd0; out_val <= 16'sd0; 
        end else begin
            if (acc_clear)      acc <= 40'sd0; // Start at 0, process in parallel with Stage A
            else if (mac_en)    acc <= acc + p1 + p2 + p3;
            
            if (apply_act) begin
                if (USE_RELU && act_v < 0) out_val <= 16'sd0;
                else if (act_v > 32767)    out_val <= 16'sd32767;
                else if (act_v < -32768)   out_val <= -16'sd32768;
                else                       out_val <= act_v[15:0];
            end
        end
    end
endmodule

// ============================================================================
// TOP LEVEL MACRO-PIPELINE (Monolithic to defeat iverilog 'x' bug)
// ============================================================================

module neural_eq_top (
    input  logic        clk, rst_n,
    input  logic signed [15:0] in_I, in_Q,
    output logic signed [15:0] out_I, out_Q,
    output logic               valid_out
);

    logic [3:0] tick_cnt, fill_cnt;
    
    logic signed [15:0] window [0:9];
    logic signed [15:0] l1_out [0:31],  l1_reg [0:31];
    logic signed [39:0] l2a_out [0:31];
    logic signed [15:0] l2b_out [0:31], l2b_reg [0:31];
    logic signed [39:0] l3a_out [0:1];
    logic signed [15:0] l3b_out [0:1];

    logic [47:0] L1_W_ROM  [0:127]; 
    logic [47:0] L2A_W_ROM [0:191]; 
    logic [47:0] L2B_W_ROM [0:191];
    logic [47:0] L3A_W_ROM [0:11];  
    logic [47:0] L3B_W_ROM [0:11];  
    
    logic signed [15:0] L1_b_ROM [0:31];
    logic signed [15:0] L2_b_ROM [0:31];
    logic signed [15:0] L3_b_ROM [0:1];

    initial begin
        $readmemh("hex_files/L1_W.hex",  L1_W_ROM);
        $readmemh("hex_files/L2A_W.hex", L2A_W_ROM);
        $readmemh("hex_files/L2B_W.hex", L2B_W_ROM);
        $readmemh("hex_files/L3A_W.hex", L3A_W_ROM);
        $readmemh("hex_files/L3B_W.hex", L3B_W_ROM);
        $readmemh("hex_files/L1_b.hex",  L1_b_ROM);
        $readmemh("hex_files/L2_b.hex",  L2_b_ROM);
        $readmemh("hex_files/L3_b.hex",  L3_b_ROM);
    end

    logic [3:0] rom_idx;
    always_comb rom_idx = (tick_cnt >= 1) ? (tick_cnt - 1) : 4'd0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_cnt <= 4'd0; fill_cnt <= 4'd0;
            for (int i=0; i<10; i++) window[i] <= -16'sd9830; 
            for (int i=0; i<32; i++) begin
                l1_reg[i]  <= 16'sd0;
                l2b_reg[i] <= 16'sd0;
            end
        end else begin
            tick_cnt <= (tick_cnt == 8) ? 4'd0 : tick_cnt + 1;
            if (tick_cnt == 8) begin
                if (fill_cnt < 6) fill_cnt <= fill_cnt + 1;
                for (int i=0; i<8; i++) window[i] <= window[i+2];
                window[8] <= in_I; window[9] <= in_Q;

                for (int i=0; i<32; i++) begin
                    l1_reg[i]  <= l1_out[i];
                    l2b_reg[i] <= l2b_out[i];
                end
            end
        end
    end

    genvar i;

    // --- Layer 1 ---
    generate
        for (i = 0; i < 32; i++) begin : L1_GEN
            logic signed [15:0] m_in1, m_in2, m_in3;
            logic [47:0] m_w;
            logic mac_en;
            assign mac_en = (tick_cnt >= 1 && tick_cnt <= 4);

            always_comb begin
                case (tick_cnt)
                    1: {m_in1, m_in2, m_in3} = {window[0], window[1], window[2]};
                    2: {m_in1, m_in2, m_in3} = {window[3], window[4], window[5]};
                    3: {m_in1, m_in2, m_in3} = {window[6], window[7], window[8]};
                    4: {m_in1, m_in2, m_in3} = {window[9], 16'sd0,    16'sd0};
                    default: {m_in1, m_in2, m_in3} = {16'sd0, 16'sd0, 16'sd0};
                endcase
                m_w = (mac_en) ? L1_W_ROM[(i * 4) + rom_idx] : 48'd0;
            end

            neuron_triple_mac #(.USE_RELU(1)) u (
                .clk(clk), .rst_n(rst_n), .acc_clear(tick_cnt == 0), .mac_en(mac_en), .apply_act(tick_cnt == 8),
                .in1(m_in1), .in2(m_in2), .in3(m_in3), .w_triple(m_w), .bias(L1_b_ROM[i]), .out_val(l1_out[i])
            );
        end
    endgenerate

    // --- Layer 2 Stage A ---
    generate
        for (i = 0; i < 32; i++) begin : L2A_GEN
            logic signed [15:0] m_in1, m_in2, m_in3;
            logic [47:0] m_w;
            logic mac_en;
            assign mac_en = (tick_cnt >= 1 && tick_cnt <= 6);

            always_comb begin
                case (tick_cnt)
                    1: {m_in1, m_in2, m_in3} = {l1_reg[0],  l1_reg[1],  l1_reg[2]};
                    2: {m_in1, m_in2, m_in3} = {l1_reg[3],  l1_reg[4],  l1_reg[5]};
                    3: {m_in1, m_in2, m_in3} = {l1_reg[6],  l1_reg[7],  l1_reg[8]};
                    4: {m_in1, m_in2, m_in3} = {l1_reg[9],  l1_reg[10], l1_reg[11]};
                    5: {m_in1, m_in2, m_in3} = {l1_reg[12], l1_reg[13], l1_reg[14]};
                    6: {m_in1, m_in2, m_in3} = {l1_reg[15], 16'sd0,     16'sd0};
                    default: {m_in1, m_in2, m_in3} = {16'sd0, 16'sd0, 16'sd0};
                endcase
                m_w = (mac_en) ? L2A_W_ROM[(i * 6) + rom_idx] : 48'd0;
            end

            neuron_triple_stage_A u (
                .clk(clk), .rst_n(rst_n), .acc_clear(tick_cnt == 0), .mac_en(mac_en),
                .in1(m_in1), .in2(m_in2), .in3(m_in3), .w_triple(m_w), .partial_acc(l2a_out[i])
            );
        end
    endgenerate

    // --- Layer 2 Stage B ---
    generate
        for (i = 0; i < 32; i++) begin : L2B_GEN
            logic signed [15:0] m_in1, m_in2, m_in3;
            logic [47:0] m_w;
            logic mac_en;
            assign mac_en = (tick_cnt >= 1 && tick_cnt <= 6);

            always_comb begin
                case (tick_cnt)
                    1: {m_in1, m_in2, m_in3} = {l1_reg[16], l1_reg[17], l1_reg[18]};
                    2: {m_in1, m_in2, m_in3} = {l1_reg[19], l1_reg[20], l1_reg[21]};
                    3: {m_in1, m_in2, m_in3} = {l1_reg[22], l1_reg[23], l1_reg[24]};
                    4: {m_in1, m_in2, m_in3} = {l1_reg[25], l1_reg[26], l1_reg[27]};
                    5: {m_in1, m_in2, m_in3} = {l1_reg[28], l1_reg[29], l1_reg[30]};
                    6: {m_in1, m_in2, m_in3} = {l1_reg[31], 16'sd0,     16'sd0};
                    default: {m_in1, m_in2, m_in3} = {16'sd0, 16'sd0, 16'sd0};
                endcase
                m_w = (mac_en) ? L2B_W_ROM[(i * 6) + rom_idx] : 48'd0;
            end

            neuron_triple_stage_B #(.USE_RELU(1)) u (
                .clk(clk), .rst_n(rst_n), .acc_clear(tick_cnt == 0), .mac_en(mac_en), .apply_act(tick_cnt == 8),
                .in1(m_in1), .in2(m_in2), .in3(m_in3), .w_triple(m_w), .bias(L2_b_ROM[i]), 
                .partial_acc_in(l2a_out[i]), .out_val(l2b_out[i]) // DIRECT WIRE CONNECTION
            );
        end
    endgenerate

    // --- Layer 3 Stage A ---
    generate
        for (i = 0; i < 2; i++) begin : L3A_GEN
            logic signed [15:0] m_in1, m_in2, m_in3;
            logic [47:0] m_w;
            logic mac_en;
            assign mac_en = (tick_cnt >= 1 && tick_cnt <= 6);

            always_comb begin
                case (tick_cnt)
                    1: {m_in1, m_in2, m_in3} = {l2b_reg[0],  l2b_reg[1],  l2b_reg[2]};
                    2: {m_in1, m_in2, m_in3} = {l2b_reg[3],  l2b_reg[4],  l2b_reg[5]};
                    3: {m_in1, m_in2, m_in3} = {l2b_reg[6],  l2b_reg[7],  l2b_reg[8]};
                    4: {m_in1, m_in2, m_in3} = {l2b_reg[9],  l2b_reg[10], l2b_reg[11]};
                    5: {m_in1, m_in2, m_in3} = {l2b_reg[12], l2b_reg[13], l2b_reg[14]};
                    6: {m_in1, m_in2, m_in3} = {l2b_reg[15], 16'sd0,      16'sd0};
                    default: {m_in1, m_in2, m_in3} = {16'sd0, 16'sd0, 16'sd0};
                endcase
                m_w = (mac_en) ? L3A_W_ROM[(i * 6) + rom_idx] : 48'd0;
            end

            neuron_triple_stage_A u (
                .clk(clk), .rst_n(rst_n), .acc_clear(tick_cnt == 0), .mac_en(mac_en),
                .in1(m_in1), .in2(m_in2), .in3(m_in3), .w_triple(m_w), .partial_acc(l3a_out[i])
            );
        end
    endgenerate

    // --- Layer 3 Stage B ---
    generate
        for (i = 0; i < 2; i++) begin : L3B_GEN
            logic signed [15:0] m_in1, m_in2, m_in3;
            logic [47:0] m_w;
            logic mac_en;
            assign mac_en = (tick_cnt >= 1 && tick_cnt <= 6);

            always_comb begin
                case (tick_cnt)
                    1: {m_in1, m_in2, m_in3} = {l2b_reg[16], l2b_reg[17], l2b_reg[18]};
                    2: {m_in1, m_in2, m_in3} = {l2b_reg[19], l2b_reg[20], l2b_reg[21]};
                    3: {m_in1, m_in2, m_in3} = {l2b_reg[22], l2b_reg[23], l2b_reg[24]};
                    4: {m_in1, m_in2, m_in3} = {l2b_reg[25], l2b_reg[26], l2b_reg[27]};
                    5: {m_in1, m_in2, m_in3} = {l2b_reg[28], l2b_reg[29], l2b_reg[30]};
                    6: {m_in1, m_in2, m_in3} = {l2b_reg[31], 16'sd0,      16'sd0};
                    default: {m_in1, m_in2, m_in3} = {16'sd0, 16'sd0, 16'sd0};
                endcase
                m_w = (mac_en) ? L3B_W_ROM[(i * 6) + rom_idx] : 48'd0;
            end

            if (i == 0) begin : CONN_I
                neuron_triple_stage_B #(.USE_RELU(0)) u (
                    .clk(clk), .rst_n(rst_n), .acc_clear(tick_cnt == 0), .mac_en(mac_en), .apply_act(tick_cnt == 8),
                    .in1(m_in1), .in2(m_in2), .in3(m_in3), .w_triple(m_w), .bias(L3_b_ROM[0]), 
                    .partial_acc_in(l3a_out[0]), .out_val(out_I) // DIRECT WIRE CONNECTION
                );
            end else begin : CONN_Q
                neuron_triple_stage_B #(.USE_RELU(0)) u (
                    .clk(clk), .rst_n(rst_n), .acc_clear(tick_cnt == 0), .mac_en(mac_en), .apply_act(tick_cnt == 8),
                    .in1(m_in1), .in2(m_in2), .in3(m_in3), .w_triple(m_w), .bias(L3_b_ROM[1]), 
                    .partial_acc_in(l3a_out[1]), .out_val(out_Q) // DIRECT WIRE CONNECTION
                );
            end
        end
    endgenerate

    assign valid_out = (tick_cnt == 8 && fill_cnt == 6);

endmodule
