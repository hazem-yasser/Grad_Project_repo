`timescale 1ns / 1ps

module neural_eq_top (
    input  logic        clk,
    input  logic        rst_n,
    input  logic signed [15:0] in_I,
    input  logic signed [15:0] in_Q,
    output logic signed [15:0] out_I,
    output logic signed [15:0] out_Q,
    output logic               valid_out
);

    // --- 1. Global Pacing & Window ---
    logic [3:0] tick_cnt;
    logic [3:0] fill_cnt;
    logic signed [15:0] window [0:9];

    // ROM Declarations (48-bit triple width weights)
    logic [47:0] L1_W_ROM  [0:31][0:3];  
    logic [47:0] L2A_W_ROM [0:31][0:5];  
    logic [47:0] L2B_W_ROM [0:31][0:5];
    logic [47:0] L3A_W_ROM [0:1][0:5];   
    logic [47:0] L3B_W_ROM [0:1][0:5];
    
    logic signed [15:0] L1_b_ROM [0:31];
    logic signed [15:0] L2_b_ROM [0:31];
    logic signed [15:0] L3_b_ROM [0:1];

    // Pipeline Nets
    logic signed [15:0] l1_out [0:31];
    logic signed [15:0] l1_reg [0:31];
    logic signed [39:0] l2a_out [0:31];
    logic signed [39:0] l2a_reg [0:31];
    logic signed [15:0] l2b_out [0:31];
    logic signed [15:0] l2b_reg [0:31];
    logic signed [39:0] l3a_out [0:1];
    logic signed [39:0] l3a_reg [0:1];

    // --- 2. ROM Loading (Paths Fixed for Project Root) ---
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

    // --- 3. FSM & Window Logic ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_cnt <= 0;
            fill_cnt <= 0;
            for (int i=0; i<10; i++) window[i] <= -16'sd9830; 
        end else begin
            tick_cnt <= (tick_cnt == 8) ? 0 : tick_cnt + 1;
            if (tick_cnt == 8) begin
                if (fill_cnt < 6) fill_cnt <= fill_cnt + 1;
                for (int i=0; i<8; i++) window[i] <= window[i+2];
                window[8] <= in_I; window[9] <= in_Q;
                
                // Pipeline Latching
                for (int i=0; i<32; i++) begin
                    l1_reg[i]  <= l1_out[i];
                    l2a_reg[i] <= l2a_out[i];
                    l2b_reg[i] <= l2b_out[i];
                end
                for (int i=0; i<2; i++) l3a_reg[i] <= l3a_out[i];
            end
        end
    end

    // --- 4. Layer 1 (32 neurons) ---
    genvar i;
    generate
        for (i = 0; i < 32; i++) begin : L1_GEN
            logic signed [15:0] m_in1, m_in2, m_in3;
            logic [47:0] m_w;
            always_comb begin
                case (tick_cnt)
                    1: {m_in1, m_in2, m_in3} = {window[0], window[1], window[2]};
                    2: {m_in1, m_in2, m_in3} = {window[3], window[4], window[5]};
                    3: {m_in1, m_in2, m_in3} = {window[6], window[7], window[8]};
                    4: {m_in1, m_in2, m_in3} = {window[9], 16'd0,     16'd0};
                    default: {m_in1, m_in2, m_in3} = '0;
                endcase
                m_w = (tick_cnt >= 1 && tick_cnt <= 4) ? L1_W_ROM[i][tick_cnt-1] : '0;
            end
            neuron_triple_mac #(.USE_RELU(1)) l1_unit (
                .clk(clk), .rst_n(rst_n),
                .acc_clear(tick_cnt == 0),
                .mac_en(tick_cnt >= 1 && tick_cnt <= 4),
                .apply_act(tick_cnt == 8),
                .in1(m_in1), .in2(m_in2), .in3(m_in3),
                .w_triple(m_w),
                .bias(L1_b_ROM[i]),
                .out_val(l1_out[i])
            );
        end
    endgenerate

    // --- 5. Layer 2 Stage A ---
    generate
        for (i = 0; i < 32; i++) begin : L2A_GEN
            logic signed [15:0] m_in1, m_in2, m_in3;
            logic [47:0] m_w;
            always_comb begin
                case (tick_cnt)
                    1: {m_in1, m_in2, m_in3} = {l1_reg[0],  l1_reg[1],  l1_reg[2]};
                    2: {m_in1, m_in2, m_in3} = {l1_reg[3],  l1_reg[4],  l1_reg[5]};
                    3: {m_in1, m_in2, m_in3} = {l1_reg[6],  l1_reg[7],  l1_reg[8]};
                    4: {m_in1, m_in2, m_in3} = {l1_reg[9],  l1_reg[10], l1_reg[11]};
                    5: {m_in1, m_in2, m_in3} = {l1_reg[12], l1_reg[13], l1_reg[14]};
                    6: {m_in1, m_in2, m_in3} = {l1_reg[15], 16'd0,      16'd0};
                    default: {m_in1, m_in2, m_in3} = '0;
                endcase
                m_w = (tick_cnt >= 1 && tick_cnt <= 6) ? L2A_W_ROM[i][tick_cnt-1] : '0;
            end
            neuron_triple_stage_A l2a_unit (
                .clk(clk), .rst_n(rst_n),
                .acc_clear(tick_cnt == 0),
                .mac_en(tick_cnt >= 1 && tick_cnt <= 6),
                .in1(m_in1), .in2(m_in2), .in3(m_in3),
                .w_triple(m_w),
                .partial_acc(l2a_out[i])
            );
        end
    endgenerate

    // --- 6. Layer 2 Stage B ---
    generate
        for (i = 0; i < 32; i++) begin : L2B_GEN
            logic signed [15:0] m_in1, m_in2, m_in3;
            logic [47:0] m_w;
            always_comb begin
                case (tick_cnt)
                    1: {m_in1, m_in2, m_in3} = {l1_reg[16], l1_reg[17], l1_reg[18]};
                    2: {m_in1, m_in2, m_in3} = {l1_reg[19], l1_reg[20], l1_reg[21]};
                    3: {m_in1, m_in2, m_in3} = {l1_reg[22], l1_reg[23], l1_reg[24]};
                    4: {m_in1, m_in2, m_in3} = {l1_reg[25], l1_reg[26], l1_reg[27]};
                    5: {m_in1, m_in2, m_in3} = {l1_reg[28], l1_reg[29], l1_reg[30]};
                    6: {m_in1, m_in2, m_in3} = {l1_reg[31], 16'd0,      16'd0};
                    default: {m_in1, m_in2, m_in3} = '0;
                endcase
                m_w = (tick_cnt >= 1 && tick_cnt <= 6) ? L2B_W_ROM[i][tick_cnt-1] : '0;
            end
            neuron_triple_stage_B #(.USE_RELU(1)) l2b_unit (
                .clk(clk), .rst_n(rst_n),
                .acc_clear(tick_cnt == 0),
                .mac_en(tick_cnt >= 1 && tick_cnt <= 6),
                .apply_act(tick_cnt == 8),
                .in1(m_in1), .in2(m_in2), .in3(m_in3),
                .w_triple(m_w),
                .bias(L2_b_ROM[i]),
                .partial_acc_in(l2a_reg[i]),
                .out_val(l2b_out[i])
            );
        end
    endgenerate

    // --- 7. Layer 3 Stage A ---
    generate
        for (i = 0; i < 2; i++) begin : L3A_GEN
            logic signed [15:0] m_in1, m_in2, m_in3;
            logic [47:0] m_w;
            always_comb begin
                case (tick_cnt)
                    1: {m_in1, m_in2, m_in3} = {l2b_reg[0],  l2b_reg[1],  l2b_reg[2]};
                    2: {m_in1, m_in2, m_in3} = {l2b_reg[3],  l2b_reg[4],  l2b_reg[5]};
                    3: {m_in1, m_in2, m_in3} = {l2b_reg[6],  l2b_reg[7],  l2b_reg[8]};
                    4: {m_in1, m_in2, m_in3} = {l2b_reg[9],  l2b_reg[10], l2b_reg[11]};
                    5: {m_in1, m_in2, m_in3} = {l2b_reg[12], l2b_reg[13], l2b_reg[14]};
                    6: {m_in1, m_in2, m_in3} = {l2b_reg[15], 16'd0,      16'd0};
                    default: {m_in1, m_in2, m_in3} = '0;
                endcase
                m_w = (tick_cnt >= 1 && tick_cnt <= 6) ? L3A_W_ROM[i][tick_cnt-1] : '0;
            end
            neuron_triple_stage_A l3a_unit (
                .clk(clk), .rst_n(rst_n),
                .acc_clear(tick_cnt == 0),
                .mac_en(tick_cnt >= 1 && tick_cnt <= 6),
                .in1(m_in1), .in2(m_in2), .in3(m_in3),
                .w_triple(m_w),
                .partial_acc(l3a_out[i])
            );
        end
    endgenerate

    // --- 8. Layer 3 Stage B ---
    generate
        for (i = 0; i < 2; i++) begin : L3B_GEN
            logic signed [15:0] m_in1, m_in2, m_in3;
            logic [47:0] m_w;
            always_comb begin
                case (tick_cnt)
                    1: {m_in1, m_in2, m_in3} = {l2b_reg[16], l2b_reg[17], l2b_reg[18]};
                    2: {m_in1, m_in2, m_in3} = {l2b_reg[19], l2b_reg[20], l2b_reg[21]};
                    3: {m_in1, m_in2, m_in3} = {l2b_reg[22], l2b_reg[23], l2b_reg[24]};
                    4: {m_in1, m_in2, m_in3} = {l2b_reg[25], l2b_reg[26], l2b_reg[27]};
                    5: {m_in1, m_in2, m_in3} = {l2b_reg[28], l2b_reg[29], l2b_reg[30]};
                    6: {m_in1, m_in2, m_in3} = {l2b_reg[31], 16'd0,      16'd0};
                    default: {m_in1, m_in2, m_in3} = '0;
                endcase
                m_w = (tick_cnt >= 1 && tick_cnt <= 6) ? L3B_W_ROM[i][tick_cnt-1] : '0;
            end
            if (i == 0) begin : CONNECT_I
                neuron_triple_stage_B #(.USE_RELU(0)) l3b_unit_I (
                    .clk(clk), .rst_n(rst_n), .acc_clear(tick_cnt == 0),
                    .mac_en(tick_cnt >= 1 && tick_cnt <= 6), .apply_act(tick_cnt == 8),
                    .in1(m_in1), .in2(m_in2), .in3(m_in3),
                    .w_triple(m_w), .bias(L3_b_ROM[0]), .partial_acc_in(l3a_reg[0]),
                    .out_val(out_I)
                );
            end else begin : CONNECT_Q
                neuron_triple_stage_B #(.USE_RELU(0)) l3b_unit_Q (
                    .clk(clk), .rst_n(rst_n), .acc_clear(tick_cnt == 0),
                    .mac_en(tick_cnt >= 1 && tick_cnt <= 6), .apply_act(tick_cnt == 8),
                    .in1(m_in1), .in2(m_in2), .in3(m_in3),
                    .w_triple(m_w), .bias(L3_b_ROM[1]), .partial_acc_in(l3a_reg[1]),
                    .out_val(out_Q)
                );
            end
        end
    endgenerate

    assign valid_out = (tick_cnt == 8 && fill_cnt == 6);
endmodule
