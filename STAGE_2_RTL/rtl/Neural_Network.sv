`timescale 1ns / 1ps

module Neural_Network (
    input  logic        clk, 
    input  logic signed [15:0] flattened_input [10], 
    output logic signed [15:0] i_out,
    output logic signed [15:0] q_out
);

    // --- MEMORIES ---
    // Unpacked Arrays [Rows][Cols]
    logic signed [15:0] L1_W [32][10];
    logic signed [15:0] L1_b [32];
    
    logic signed [15:0] L2_W [32][32];
    logic signed [15:0] L2_b [32];

    logic signed [15:0] L3_W [2][32];
    logic signed [15:0] L3_b [2];

    // Load Hex Files
    initial begin
        $readmemh("hex_files/L1_W.hex", L1_W);
        $readmemh("hex_files/L1_b.hex", L1_b);
        $readmemh("hex_files/L2_W.hex", L2_W);
        $readmemh("hex_files/L2_b.hex", L2_b);
        $readmemh("hex_files/L3_W.hex", L3_W);
        $readmemh("hex_files/L3_b.hex", L3_b);
    end

    // --- INTERCONNECTS ---
    logic signed [15:0] l1_res [32];
    logic signed [15:0] l2_res [32];
    logic signed [15:0] l3_res [2];

    genvar i;
    
    // --- LAYER 1 ---
    generate
        for (i=0; i<32; i=i+1) begin : L1
            // 1. Create a temporary wire for THIS neuron's weights
            logic signed [15:0] w_row [10];
            
            // 2. Manually copy the row from Memory to Wire (Bypasses Slice Error)
            always_comb begin
                for (int k=0; k<10; k++) w_row[k] = L1_W[i][k];
            end

            // 3. Instantiate using the clean wire
            Neuron #(.N_INPUTS(10)) n1 (
                .inputs   (flattened_input), 
                .weights  (w_row),       // No slicing here!
                .bias     (L1_b[i]), 
                .use_relu (1'b1),        // Fixed warning (1'b1)
                .out_val  (l1_res[i])
            );
        end
    endgenerate

    // --- LAYER 2 ---
    generate
        for (i=0; i<32; i=i+1) begin : L2
            logic signed [15:0] w_row [32];
            
            always_comb begin
                for (int k=0; k<32; k++) w_row[k] = L2_W[i][k];
            end

            Neuron #(.N_INPUTS(32)) n2 (
                .inputs   (l1_res), 
                .weights  (w_row), 
                .bias     (L2_b[i]), 
                .use_relu (1'b1), 
                .out_val  (l2_res[i])
            );
        end
    endgenerate

    // --- LAYER 3 ---
    generate
        for (i=0; i<2; i=i+1) begin : L3
            logic signed [15:0] w_row [32];
            
            always_comb begin
                for (int k=0; k<32; k++) w_row[k] = L3_W[i][k];
            end

            Neuron #(.N_INPUTS(32)) n3 (
                .inputs   (l2_res), 
                .weights  (w_row), 
                .bias     (L3_b[i]), 
                .use_relu (1'b0), // Linear
                .out_val  (l3_res[i])
            );
        end
    endgenerate

    assign i_out = l3_res[0];
    assign q_out = l3_res[1];

endmodule