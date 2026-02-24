`timescale 1ns / 1ps

module Neuron #(
    parameter int N_INPUTS = 10,
    parameter int DATA_W   = 16,
    parameter int FRAC_B   = 14
)(
    input  logic signed [DATA_W-1:0] inputs [N_INPUTS],
    input  logic signed [DATA_W-1:0] weights [N_INPUTS],
    input  logic signed [DATA_W-1:0] bias,
    input  logic                     use_relu,
    output logic signed [DATA_W-1:0] out_val
);

    logic signed [39:0] accumulator;
    logic signed [39:0] acc_shifted;
    
    // Intermediate variables for robust multiplication
    logic signed [31:0] input_32;
    logic signed [31:0] weight_32;
    logic signed [31:0] product_32;

    always_comb begin
        accumulator = 0;
        
        for (int i = 0; i < N_INPUTS; i++) begin
            // 1. Force Sign Extension to 32-bit
            input_32  = inputs[i];
            weight_32 = weights[i];
            
            // 2. Multiply safely in 32-bit domain
            product_32 = input_32 * weight_32;
            
            // 3. Accumulate
            accumulator += product_32;
        end

        // 4. Shift & Bias
        acc_shifted = accumulator >>> FRAC_B;
        acc_shifted += bias;

        // 5. ReLU
        if (use_relu && acc_shifted < 0) 
            acc_shifted = 0;

        // 6. Saturation (Clamping)
        if (acc_shifted > 32767)      out_val = 32767;
        else if (acc_shifted < -32768) out_val = -32768;
        else                           out_val = 16'(acc_shifted);
    end

endmodule