`timescale 1ns / 1ps

module neural_eq_top (
    input  logic clk, rst_n,
    input  logic valid_in,
    input  logic signed [15:0] in_I, in_Q,
    output logic signed [15:0] out_I, out_Q,
    output logic valid_out
);

    // ========================================================================
    // 1. SMART INPUT WINDOW
    // ========================================================================
    localparam signed [15:0] INIT_VAL = 16'shD99A; // -9830
    localparam int TIMEOUT_CYCLES = 50;

    logic signed [15:0] win_I [0:4];
    logic signed [15:0] win_Q [0:4];
    logic v_win;
    
    logic [2:0] fill_cnt;
    logic [2:0] flush_cnt;
    logic [7:0] silence_timer;
    logic flushing_active;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fill_cnt <= 0; flush_cnt <= 0; silence_timer <= 0; flushing_active <= 0;
            v_win <= 0;
            for (int i=0; i<5; i++) begin win_I[i] <= INIT_VAL; win_Q[i] <= INIT_VAL; end
        end else begin
            v_win <= 0; // Default: Pulse Low

            if (valid_in) silence_timer <= 0;
            else if (fill_cnt >= 3 && !flushing_active && flush_cnt == 0) begin
                if (silence_timer < TIMEOUT_CYCLES) silence_timer <= silence_timer + 1;
                else flushing_active <= 1;
            end

            if (valid_in) begin
                for (int i=0; i<4; i++) begin win_I[i] <= win_I[i+1]; win_Q[i] <= win_Q[i+1]; end
                win_I[4] <= in_I; win_Q[4] <= in_Q;

                if (fill_cnt < 3) begin
                    fill_cnt <= fill_cnt + 1;
                    if (fill_cnt == 2) v_win <= 1; // Pulse ONCE on 3rd symbol
                end else v_win <= 1; // Pulse ONCE per symbol
            end 
            else if (flushing_active) begin
                if (flush_cnt == 0 || flush_cnt == 6) begin
                    for (int i=0; i<4; i++) begin win_I[i] <= win_I[i+1]; win_Q[i] <= win_Q[i+1]; end
                    win_I[4] <= INIT_VAL; win_Q[4] <= INIT_VAL;
                    v_win <= 1; 
                end
                if (flush_cnt < 7)
                    flush_cnt <= flush_cnt + 1;
                else
                    flushing_active <= 0;
            end
        end
    end

    // ========================================================================
    // 2. LAYER 1 (10 Inputs -> 32 Neurons) | Latency: 4 Cycles
    // ========================================================================
    logic signed [15:0] l1_out [0:31]; 
    logic v_l1;
    
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
            l1_tick <= 0; l1_busy <= 0; v_l1 <= 0;
        end else begin
            v_l1 <= 0; // Pulse logic
            
            if (v_win && !l1_busy) begin
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
                    v_l1 <= 1; // FIRE VALID only after 4 ticks
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
                else if (v_win && !l1_busy) acc <= 0; // Clear on start
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

    // ========================================================================
    // 3. LAYER 2 (32 Inputs -> 32 Neurons) | Latency: 6 Cycles
    // ========================================================================
    logic signed [15:0] l2_out [0:31];
    logic v_l2;
    logic [2:0] l2_tick;
    logic l2_busy;
    
    // Explicit Latch
    logic signed [15:0] l2_latched_in [0:31];

    logic [47:0] L2A_W_ROM [0:191]; 
    logic [47:0] L2B_W_ROM [0:191]; 
    logic signed [15:0] L2_b_ROM [0:31];
    initial begin
        $readmemh("hex_files/L2A_W.hex", L2A_W_ROM);
        $readmemh("hex_files/L2B_W.hex", L2B_W_ROM);
        $readmemh("hex_files/L2_b.hex", L2_b_ROM);
    end

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

    logic signed [15:0] l2a_in1, l2a_in2, l2a_in3;
    logic signed [15:0] l2b_in1, l2b_in2, l2b_in3;

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

    generate
        for (i = 0; i < 32; i++) begin : L2_MAC
            logic [47:0] w_bus_a, w_bus_b;
            assign w_bus_a = (l2_busy) ? L2A_W_ROM[(i*6) + (l2_tick-1)] : 48'd0;
            assign w_bus_b = (l2_busy) ? L2B_W_ROM[(i*6) + (l2_tick-1)] : 48'd0;
            
            logic signed [39:0] acc;
            logic signed [31:0] p1, p2, p3, p4, p5, p6;

            assign p1 = l2a_in1 * $signed(w_bus_a[47:32]);
            assign p2 = l2a_in2 * $signed(w_bus_a[31:16]);
            assign p3 = l2a_in3 * $signed(w_bus_a[15:0]);
            
            assign p4 = l2b_in1 * $signed(w_bus_b[47:32]);
            assign p5 = l2b_in2 * $signed(w_bus_b[31:16]);
            assign p6 = l2b_in3 * $signed(w_bus_b[15:0]);

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) acc <= 0;
                else if (v_l1 && !l2_busy) acc <= 0;
                else if (l2_busy && l2_tick == 6 && v_l1) acc <= 0;
                else if (l2_busy) acc <= acc + (p1 + p2) + (p3 + p4) + (p5 + p6);
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) l2_out[i] <= 0;
                else if (l2_busy && l2_tick == 6) begin
                    logic signed [39:0] final_acc;
                    logic signed [39:0] tmp;
                    final_acc = acc + (p1 + p2) + (p3 + p4) + (p5 + p6);
                    tmp = (final_acc >>> 14) + L2_b_ROM[i];
                    if (tmp < 0) tmp = 0; // ReLU
                    if (tmp > 32767) l2_out[i] <= 32767;
                    else if (tmp < -32768) l2_out[i] <= -32768;
                    else l2_out[i] <= tmp[15:0];
                end
            end
        end
    endgenerate

    // ========================================================================
    // 4. LAYER 3 (32 Inputs -> 2 Neurons) | Latency: 6 Cycles
    // ========================================================================
    logic [2:0] l3_tick;
    logic l3_busy;
    logic signed [15:0] l3_latched_in [0:31];

    logic [47:0] L3A_W_ROM [0:11]; 
    logic [47:0] L3B_W_ROM [0:11]; 
    logic signed [15:0] L3_b_ROM [0:1];
    initial begin
        $readmemh("hex_files/L3A_W.hex", L3A_W_ROM);
        $readmemh("hex_files/L3B_W.hex", L3B_W_ROM);
        $readmemh("hex_files/L3_b.hex", L3_b_ROM);
    end

    // STRICT FSM (with re-latch for back-to-back throughput)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l3_tick <= 0; l3_busy <= 0; valid_out <= 0;
            out_I <= 0; out_Q <= 0;
        end else begin
            valid_out <= 0;
            if (v_l2 && !l3_busy) begin
                l3_busy <= 1; l3_tick <= 1;
                for (int i = 0; i < 32; i++) l3_latched_in[i] <= l2_out[i];
            end else if (l3_busy) begin
                if (l3_tick == 6) begin
                    valid_out <= 1;
                    if (v_l2) begin
                        l3_tick <= 1;
                        for (int i = 0; i < 32; i++) l3_latched_in[i] <= l2_out[i];
                    end else begin
                        l3_busy <= 0;
                    end
                end else l3_tick <= l3_tick + 1;
            end
        end
    end

    logic signed [15:0] l3a_in1, l3a_in2, l3a_in3;
    logic signed [15:0] l3b_in1, l3b_in2, l3b_in3;

    // Reuse L2 MUX logic structure but for L3 Inputs
    always_comb begin
        if (l3_busy) begin
            case (l3_tick)
                1: begin 
                    {l3a_in1, l3a_in2, l3a_in3} = {l3_latched_in[0],  l3_latched_in[1],  l3_latched_in[2]};
                    {l3b_in1, l3b_in2, l3b_in3} = {l3_latched_in[16], l3_latched_in[17], l3_latched_in[18]};
                end
                2: begin 
                    {l3a_in1, l3a_in2, l3a_in3} = {l3_latched_in[3],  l3_latched_in[4],  l3_latched_in[5]};
                    {l3b_in1, l3b_in2, l3b_in3} = {l3_latched_in[19], l3_latched_in[20], l3_latched_in[21]};
                end
                3: begin 
                    {l3a_in1, l3a_in2, l3a_in3} = {l3_latched_in[6],  l3_latched_in[7],  l3_latched_in[8]};
                    {l3b_in1, l3b_in2, l3b_in3} = {l3_latched_in[22], l3_latched_in[23], l3_latched_in[24]};
                end
                4: begin 
                    {l3a_in1, l3a_in2, l3a_in3} = {l3_latched_in[9],  l3_latched_in[10], l3_latched_in[11]};
                    {l3b_in1, l3b_in2, l3b_in3} = {l3_latched_in[25], l3_latched_in[26], l3_latched_in[27]};
                end
                5: begin 
                    {l3a_in1, l3a_in2, l3a_in3} = {l3_latched_in[12], l3_latched_in[13], l3_latched_in[14]};
                    {l3b_in1, l3b_in2, l3b_in3} = {l3_latched_in[28], l3_latched_in[29], l3_latched_in[30]};
                end
                6: begin 
                    {l3a_in1, l3a_in2, l3a_in3} = {l3_latched_in[15], 16'd0,             16'd0};
                    {l3b_in1, l3b_in2, l3b_in3} = {l3_latched_in[31], 16'd0,             16'd0};
                end
                default: begin {l3a_in1, l3a_in2, l3a_in3} = 48'd0; {l3b_in1, l3b_in2, l3b_in3} = 48'd0; end
            endcase
        end else begin
            {l3a_in1, l3a_in2, l3a_in3} = 48'd0; {l3b_in1, l3b_in2, l3b_in3} = 48'd0;
        end
    end

    generate
        for (i = 0; i < 2; i++) begin : L3_MAC
            logic [47:0] w_bus_a, w_bus_b;
            assign w_bus_a = (l3_busy) ? L3A_W_ROM[(i*6) + (l3_tick-1)] : 48'd0;
            assign w_bus_b = (l3_busy) ? L3B_W_ROM[(i*6) + (l3_tick-1)] : 48'd0;
            
            logic signed [39:0] acc;
            logic signed [31:0] p1, p2, p3, p4, p5, p6;

            assign p1 = l3a_in1 * $signed(w_bus_a[47:32]);
            assign p2 = l3a_in2 * $signed(w_bus_a[31:16]);
            assign p3 = l3a_in3 * $signed(w_bus_a[15:0]);
            assign p4 = l3b_in1 * $signed(w_bus_b[47:32]);
            assign p5 = l3b_in2 * $signed(w_bus_b[31:16]);
            assign p6 = l3b_in3 * $signed(w_bus_b[15:0]);

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) acc <= 0;
                else if (v_l2 && !l3_busy) acc <= 0;
                else if (l3_busy && l3_tick == 6 && v_l2) acc <= 0;
                else if (l3_busy) acc <= acc + (p1 + p2) + (p3 + p4) + (p5 + p6);
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin end 
                else if (l3_busy && l3_tick == 6) begin
                    logic signed [39:0] final_acc;
                    logic signed [39:0] tmp;
                    final_acc = acc + (p1 + p2) + (p3 + p4) + (p5 + p6);
                    tmp = (final_acc >>> 14) + L3_b_ROM[i];
                    
                    // SATURATE ONLY (No ReLU for Output)
                    if (tmp > 32767) tmp = 32767;
                    else if (tmp < -32768) tmp = -32768;
                    
                    if (i == 0) out_I <= tmp[15:0];
                    else out_Q <= tmp[15:0];
                end
            end
        end
    endgenerate

endmodule