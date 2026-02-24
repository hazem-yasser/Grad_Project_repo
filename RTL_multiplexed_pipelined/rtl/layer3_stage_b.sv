`timescale 1ns / 1ps

module layer3_stage_b (
    input  logic clk, rst_n,
    input  logic [3:0] tick_cnt,
    input  logic signed [15:0] l2b_reg [0:31],
    input  logic signed [39:0] l3a_reg [0:1],
    output logic signed [15:0] l3b_out [0:1]
);
    // FIX: Flattened 1D ROM (2 neurons * 6 rows = 12)
    logic [47:0] W_ROM [0:11];
    logic signed [15:0] b_ROM [0:1];
    
    initial begin
        $readmemh("hex_files/L3B_W.hex", W_ROM);
        $readmemh("hex_files/L3_b.hex", b_ROM);
    end

    logic acc_clr, mac_en, apply_act;
    assign acc_clr = (tick_cnt == 0);
    assign mac_en  = (tick_cnt >= 1 && tick_cnt <= 6);
    assign apply_act = (tick_cnt == 8);

    logic signed [15:0] m_in1, m_in2, m_in3;
    always_comb begin
        case (tick_cnt)
            1: {m_in1, m_in2, m_in3} = {l2b_reg[16], l2b_reg[17], l2b_reg[18]};
            2: {m_in1, m_in2, m_in3} = {l2b_reg[19], l2b_reg[20], l2b_reg[21]};
            3: {m_in1, m_in2, m_in3} = {l2b_reg[22], l2b_reg[23], l2b_reg[24]};
            4: {m_in1, m_in2, m_in3} = {l2b_reg[25], l2b_reg[26], l2b_reg[27]};
            5: {m_in1, m_in2, m_in3} = {l2b_reg[28], l2b_reg[29], l2b_reg[30]};
            6: {m_in1, m_in2, m_in3} = {l2b_reg[31], 16'd0,       16'd0};
            default: {m_in1, m_in2, m_in3} = {16'd0, 16'd0, 16'd0};
        endcase
    end

    logic [3:0] rom_idx;
    always_comb rom_idx = (tick_cnt >= 1) ? (tick_cnt - 1) : 4'd0;

    genvar i;
    generate
        for (i = 0; i < 2; i++) begin : NEURONS
            logic [47:0] m_w;
            always_comb begin
                if (mac_en) m_w = W_ROM[(i * 6) + rom_idx];
                else        m_w = 48'd0;
            end
            
            neuron_triple_stage_B #(.USE_RELU(0)) unit (
                .clk(clk), .rst_n(rst_n), .acc_clear(acc_clr), .mac_en(mac_en), .apply_act(apply_act),
                .in1(m_in1), .in2(m_in2), .in3(m_in3), .w_triple(m_w), .bias(b_ROM[i]), 
                .partial_acc_in(l3a_reg[i]), .out_val(l3b_out[i])
            );
        end
    endgenerate
endmodule
