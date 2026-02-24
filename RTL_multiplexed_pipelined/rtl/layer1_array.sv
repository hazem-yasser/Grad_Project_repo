`timescale 1ns / 1ps

module layer1_array (
    input  logic clk, rst_n,
    input  logic [3:0] tick_cnt,
    input  logic signed [15:0] window [0:9],
    output logic signed [15:0] l1_out [0:31]
);
    // FIX: Flattened 1D ROM (32 neurons * 4 rows = 128)
    logic [47:0] W_ROM [0:127];
    logic signed [15:0] b_ROM [0:31];
    
    initial begin
        $readmemh("hex_files/L1_W.hex", W_ROM);
        $readmemh("hex_files/L1_b.hex", b_ROM);
    end

    logic acc_clr, mac_en, apply_act;
    assign acc_clr = (tick_cnt == 0);
    assign mac_en  = (tick_cnt >= 1 && tick_cnt <= 4);
    assign apply_act = (tick_cnt == 8);

    logic signed [15:0] m_in1, m_in2, m_in3;
    always_comb begin
        case (tick_cnt)
            1: {m_in1, m_in2, m_in3} = {window[0], window[1], window[2]};
            2: {m_in1, m_in2, m_in3} = {window[3], window[4], window[5]};
            3: {m_in1, m_in2, m_in3} = {window[6], window[7], window[8]};
            4: {m_in1, m_in2, m_in3} = {window[9], 16'd0,     16'd0};
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
                if (mac_en) m_w = W_ROM[(i * 4) + rom_idx];
                else        m_w = 48'd0;
            end
            
            neuron_triple_mac #(.USE_RELU(1)) unit (
                .clk(clk), .rst_n(rst_n), .acc_clear(acc_clr), .mac_en(mac_en), .apply_act(apply_act),
                .in1(m_in1), .in2(m_in2), .in3(m_in3), .w_triple(m_w), .bias(b_ROM[i]), .out_val(l1_out[i])
            );
        end
    endgenerate
endmodule
