`timescale 1ns / 1ps

module tb_neural_eq_top();
    logic clk = 0, rst_n = 0;
    logic valid_in = 0;
    logic valid_out;
    logic signed [15:0] in_I, in_Q, out_I, out_Q;

    int out_file;
    logic signed [15:0] stimuli_mem [0:3999]; 

    neural_eq_top DUT (
        .clk(clk), .rst_n(rst_n), 
        .valid_in(valid_in), 
        .in_I(in_I), .in_Q(in_Q), 
        .out_I(out_I), .out_Q(out_Q), 
        .valid_out(valid_out)
    );

    always #5 clk = ~clk; 

    initial begin
        $dumpfile("sim_data/debug.vcd");
        $dumpvars(0, tb_neural_eq_top);

        for (int i=0; i<4000; i++) stimuli_mem[i] = 16'sd0;
        
        $readmemh("hex_files/input_stimuli.hex", stimuli_mem);
        out_file = $fopen("sim_data/rtl_output.txt", "w");
        
        rst_n = 0;
        in_I = 0; in_Q = 0; valid_in = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        $display("--- Starting Data Stream (2000 Symbols) ---");
        
        for (int i = 0; i < 2000; i++) begin
            valid_in = 1;
            in_I = stimuli_mem[i*2];   
            in_Q = stimuli_mem[i*2+1]; 
            @(posedge clk);
            
            valid_in = 0; 
            repeat(5) @(posedge clk); // 1+5 = 6-cycle period (bottleneck rate)
        end
        
        // Wait for pipeline to drain + auto-flush timeout
        $display("--- Waiting for Auto-Flush... ---");
        repeat(200) @(posedge clk); 
        
        $fclose(out_file);
        $display("--- Simulation Finished ---");
        $finish;
    end

    always @(posedge clk) begin
        if (valid_out) $fdisplay(out_file, "%d %d", out_I, out_Q);
    end
endmodule