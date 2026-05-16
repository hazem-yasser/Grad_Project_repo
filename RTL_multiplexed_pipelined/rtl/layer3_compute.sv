`timescale 1ns / 1ps

module layer3_compute (
    input  logic clk, rst_n,
    input  logic valid_in,
    input  logic signed [15:0] l2_out [0:31],
    output logic signed [15:0] l3_out [0:1],
    output logic valid_out
);
    
    logic [2:0] l3_tick;
    logic l3_busy;
    
    // Explicit Latch
    logic signed [15:0] l3_latched_in [0:31];
    logic signed [15:0] l3_out_reg [0:1];



    // STRICT FSM (with re-latch for back-to-back throughput)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l3_tick <= 0; l3_busy <= 0; valid_out <= 0;
        end else begin
            valid_out <= 0;
            if (valid_in && !l3_busy) begin
                l3_busy <= 1; 
                l3_tick <= 1;
                for (int i = 0; i < 32; i++) l3_latched_in[i] <= l2_out[i];
            end else if (l3_busy) begin
                if (l3_tick == 6) begin
                    valid_out <= 1;
                    if (valid_in) begin
                        l3_tick <= 1;
                        for (int i = 0; i < 32; i++) l3_latched_in[i] <= l2_out[i];
                    end else begin
                        l3_busy <= 0;
                    end
                end else begin
                    l3_tick <= l3_tick + 1;
                end
            end
        end
    end

    logic signed [15:0] l3a_in1, l3a_in2, l3a_in3;
    logic signed [15:0] l3b_in1, l3b_in2, l3b_in3;

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

    genvar i;
    generate
        for (i = 0; i < 2; i++) begin : L3_MAC
            logic [47:0] w_bus_a, w_bus_b;
            logic [47:0] w_bus_a_raw, w_bus_b_raw;
            logic [3:0] w_addr;
            logic [0:0] b_addr;

            assign w_addr = 4'((i*6) + int'(l3_tick) - 1);
            assign b_addr = 1'(i);

            rom_L3A_W u_rom_w_a (
                .addr(w_addr),
                .data(w_bus_a_raw)
            );
            rom_L3B_W u_rom_w_b (
                .addr(w_addr),
                .data(w_bus_b_raw)
            );
            assign w_bus_a = (l3_busy) ? w_bus_a_raw : 48'd0;
            assign w_bus_b = (l3_busy) ? w_bus_b_raw : 48'd0;
            
            logic signed [15:0] b_raw;
            rom_L3_b u_rom_b (
                .addr(b_addr),
                .data(b_raw)
            );
            
            logic signed [39:0] acc;
            logic signed [31:0] p1, p2, p3, p4, p5, p6;
            logic signed [39:0] final_acc;
            logic signed [39:0] tmp;

            assign p1 = l3a_in1 * $signed(w_bus_a[47:32]);
            assign p2 = l3a_in2 * $signed(w_bus_a[31:16]);
            assign p3 = l3a_in3 * $signed(w_bus_a[15:0]);
            
            assign p4 = l3b_in1 * $signed(w_bus_b[47:32]);
            assign p5 = l3b_in2 * $signed(w_bus_b[31:16]);
            assign p6 = l3b_in3 * $signed(w_bus_b[15:0]);

            assign final_acc = acc + (p1 + p2) + (p3 + p4) + (p5 + p6);
            assign tmp = (final_acc >>> 14) + b_raw;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) acc <= 0;
                else if (valid_in && !l3_busy) acc <= 0;
                else if (l3_busy && l3_tick == 6 && valid_in) acc <= 0;
                else if (l3_busy) acc <= acc + (p1 + p2) + (p3 + p4) + (p5 + p6);
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) l3_out_reg[i] <= 0;
                else if (l3_busy && l3_tick == 6) begin
                    // No ReLU for layer 3 (linear activation)
                    if (tmp > 32767) l3_out_reg[i] <= 32767;
                    else if (tmp < -32768) l3_out_reg[i] <= -32768;
                    else l3_out_reg[i] <= tmp[15:0];
                end
            end
        end
    endgenerate

    always_comb begin
        for (int o3 = 0; o3 < 2; o3++) begin
            l3_out[o3] = l3_out_reg[o3];
        end
    end

endmodule
