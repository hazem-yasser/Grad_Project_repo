`timescale 1ns / 1ps

module tb_neural_eq_top();
    logic clk, rst_n;
    logic signed [15:0] in_I, in_Q, out_I, out_Q;
    logic valid_out;

    int i, out_file;
    logic signed [31:0] stimuli_mem [0:19999];

    neural_eq_top DUT (
        .clk(clk), .rst_n(rst_n),
        .in_I(in_I), .in_Q(in_Q),
        .out_I(out_I), .out_Q(out_Q),
        .valid_out(valid_out)
    );

    initial clk = 0;
    always #0.94 clk = ~clk;

    initial begin
        $readmemh("hex_files/input_stimuli.hex", stimuli_mem);
        out_file = $fopen("sim_data/rtl_output.txt", "w");
        
        rst_n = 0; in_I = 0; in_Q = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;

        $display("--- Starting Simulation ---");

        for (i = 0; i < 5000; i++) begin
            in_I = stimuli_mem[i*2][15:0];   
            in_Q = stimuli_mem[i*2+1][15:0]; 
            repeat(9) @(posedge clk);
        end

        repeat(100) @(posedge clk);
        $fclose(out_file);
        $display("--- Simulation Finished ---");
        $finish;
    end

    always @(posedge clk) begin
        if (rst_n && valid_out) begin
            $fdisplay(out_file, "%d %d", out_I, out_Q);
        end
    end

    initial begin
        $dumpfile("sim_data/dump.vcd");
        $dumpvars(0, tb_neural_eq_top);
    end
endmodule
