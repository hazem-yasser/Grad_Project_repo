`timescale 1ns / 1ps

module layer2_stage_b (
    input  logic clk, rst_n,
    input  logic [3:0] tick_cnt,
    input  logic signed [15:0] l1_reg [0:31],
    input  logic signed [39:0] l2a_reg [0:31],
    output logic signed [15:0] l2b_out [0:31]
);
    // FIX: Flattened 1D ROM (32 neurons * 6 rows = 192)
    logic [47:0] W_ROM [0:191];
    logic signed [15:0] b_ROM [0:31];
    
    initial begin
        $readmemh("hex_files/L2B_W.hex", W_ROM);
        $readmemh("hex_files/L2_b.hex", b_ROM);
    end

    logic acc_clr, mac_en, apply_act;
    assign acc_clr = (tick_cnt == 0);
    assign mac_en  = (tick_cnt >= 1 && tick_cnt <= 6);
    assign apply_act = (tick_cnt == 8);

    logic signed [15:0] m_in1, m_in2, m_in3;
    always_comb begin
        case (tick_cnt)
            1: {m_in1, m_in2, m_in3} = {l1_reg[16], l1_reg[17], l1_reg[18]};
            2: {m_in1, m_in2, m_in3} = {l1_reg[19], l1_reg[20], l1_reg[21]};
            3: {m_in1, m_in2, m_in3} = {l1_reg[22], l1_reg[23], l1_reg[24]};
            4: {m_in1, m_in2, m_in3} = {l1_reg[25], l1_reg[26], l1_reg[27]};
            5: {m_in1, m_in2, m_in3} = {l1_reg[28], l1_reg[29], l1_reg[30]};
            6: {m_in1, m_in2, m_in3} = {l1_reg[31], 16'd0,      16'd0};
            default: {m_in1, m_in2, m_in3} = {16'd0, 16'd0, 16'd0};
        endcase
    end

    logic [3:0] rom_idx;
    always_comb rom_idx = (tick_cnt >= 1) ? (tick_cnt - 1) : 4'd0;

    genvar i;
    generate
        for (i = 0; i < 32; i++) begin : NEURONS
            logic [47:0] m_w;
            always_comb begin
                if (mac_en) m_w = W_ROM[(i * 6) + rom_idx];
                else        m_w = 48'd0;
            end
            
            neuron_triple_stage_B #(.USE_RELU(1)) unit (
                .clk(clk), .rst_n(rst_n), .acc_clear(acc_clr), .mac_en(mac_en), .apply_act(apply_act),
                .in1(m_in1), .in2(m_in2), .in3(m_in3), .w_triple(m_w), .bias(b_ROM[i]), 
                .partial_acc_in(l2a_reg[i]), .out_val(l2b_out[i])
            );
        end
    endgenerate
endmodule
