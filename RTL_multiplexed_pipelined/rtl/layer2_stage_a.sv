`timescale 1ns / 1ps

module layer2_stage_a (
    input  logic clk, rst_n,
    input  logic [3:0] tick_cnt,
    input  logic signed [15:0] l1_reg [0:31],
    output logic signed [39:0] l2a_out [0:31]
);
    // FIX: Flattened 1D ROM (32 neurons * 6 rows = 192)
    logic [47:0] W_ROM [0:191];
    initial $readmemh("hex_files/L2A_W.hex", W_ROM);

    logic acc_clr, mac_en;
    assign acc_clr = (tick_cnt == 0);
    assign mac_en  = (tick_cnt >= 1 && tick_cnt <= 6);

    logic signed [15:0] m_in1, m_in2, m_in3;
    always_comb begin
        case (tick_cnt)
            1: {m_in1, m_in2, m_in3} = {l1_reg[0],  l1_reg[1],  l1_reg[2]};
            2: {m_in1, m_in2, m_in3} = {l1_reg[3],  l1_reg[4],  l1_reg[5]};
            3: {m_in1, m_in2, m_in3} = {l1_reg[6],  l1_reg[7],  l1_reg[8]};
            4: {m_in1, m_in2, m_in3} = {l1_reg[9],  l1_reg[10], l1_reg[11]};
            5: {m_in1, m_in2, m_in3} = {l1_reg[12], l1_reg[13], l1_reg[14]};
            6: {m_in1, m_in2, m_in3} = {l1_reg[15], 16'd0,      16'd0};
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
                // FIX: 1D Indexing
                if (mac_en) m_w = W_ROM[(i * 6) + rom_idx];
                else        m_w = 48'd0;
            end
            
            neuron_triple_stage_A unit (
                .clk(clk), .rst_n(rst_n), .acc_clear(acc_clr), .mac_en(mac_en),
                .in1(m_in1), .in2(m_in2), .in3(m_in3), .w_triple(m_w), .partial_acc(l2a_out[i])
            );
        end
    endgenerate
endmodule
