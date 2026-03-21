`timescale 1ns / 1ps

module layer1_compute (
    input  logic clk, rst_n,
    input  logic valid_in,
    input  logic signed [15:0] win_I [0:4],
    input  logic signed [15:0] win_Q [0:4],
    output logic signed [15:0] l1_out [0:31],
    output logic valid_out
);
    
    // Explicit Latch Registers (Stability)
    logic signed [15:0] l1_latched_I [0:4];
    logic signed [15:0] l1_latched_Q [0:4];
    logic [2:0] l1_tick;
    logic l1_busy;

    logic [47:0] L1_W_ROM [0:127]; 
    logic signed [15:0] L1_b_ROM [0:31];
    initial begin
        $readmemh("hex_files/L1_W.hex", L1_W_ROM);
        $readmemh("hex_files/L1_b.hex", L1_b_ROM);
    end

    // STRICT FSM: Idle -> Latch -> Compute (4) -> Fire
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l1_tick <= 0; l1_busy <= 0; valid_out <= 0;
        end else begin
            valid_out <= 0; // Pulse logic
            
            if (valid_in && !l1_busy) begin
                // START: Latch data and enter BUSY
                l1_busy <= 1; 
                l1_tick <= 1;
                for (int i = 0; i < 5; i++) begin
                    l1_latched_I[i] <= win_I[i];
                    l1_latched_Q[i] <= win_Q[i];
                end
            end else if (l1_busy) begin
                if (l1_tick == 4) begin
                    l1_busy <= 0; 
                    valid_out <= 1; // FIRE VALID only after 4 ticks
                end else begin
                    l1_tick <= l1_tick + 1;
                end
            end
        end
    end

    logic signed [15:0] l1_in1, l1_in2, l1_in3;
    always_comb begin
        case (l1_tick)
            1: {l1_in1, l1_in2, l1_in3} = {l1_latched_I[0], l1_latched_I[1], l1_latched_I[2]};
            2: {l1_in1, l1_in2, l1_in3} = {l1_latched_I[3], l1_latched_I[4], l1_latched_Q[0]};
            3: {l1_in1, l1_in2, l1_in3} = {l1_latched_Q[1], l1_latched_Q[2], l1_latched_Q[3]};
            4: {l1_in1, l1_in2, l1_in3} = {l1_latched_Q[4], 16'sd0,           16'sd0}; 
            default: {l1_in1, l1_in2, l1_in3} = 48'd0;
        endcase
    end

    genvar i;
    generate
        for (i = 0; i < 32; i++) begin : L1_MAC
            logic [47:0] w_bus;
            assign w_bus = (l1_busy) ? L1_W_ROM[(i*4) + (l1_tick-1)] : 48'd0;
            
            logic signed [39:0] acc;
            logic signed [31:0] p1, p2, p3;

            // CORRECT WEIGHT ORDERING: [47:32]=w0, [31:16]=w1, [15:0]=w2
            assign p1 = l1_in1 * $signed(w_bus[47:32]); 
            assign p2 = l1_in2 * $signed(w_bus[31:16]);
            assign p3 = l1_in3 * $signed(w_bus[15:0]);

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) acc <= 0;
                else if (valid_in && !l1_busy) acc <= 0; // Clear on start
                else if (l1_busy) acc <= (p1 + p2) + (p3 + acc);
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) l1_out[i] <= 0;
                else if (l1_busy && l1_tick == 4) begin
                    logic signed [39:0] final_acc;
                    logic signed [39:0] tmp;
                    final_acc = (p1 + p2) + (p3 + acc);
                    tmp = (final_acc >>> 14) + L1_b_ROM[i];
                    if (tmp < 0) tmp = 0; // ReLU
                    if (tmp > 32767) l1_out[i] <= 32767;
                    else if (tmp < -32768) l1_out[i] <= -32768;
                    else l1_out[i] <= tmp[15:0];
                end
            end
        end
    endgenerate

endmodule
