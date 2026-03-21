`timescale 1ns / 1ps

module tb_layer2_compute ();

    logic clk, rst_n;
    logic valid_in;
    logic signed [15:0] l1_out [0:31];
    wire signed [15:0] l2_out [0:31];
    wire valid_out;

    layer2_compute DUT (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in),
        .l1_out(l1_out),
        .l2_out(l2_out), .valid_out(valid_out)
    );

    initial begin
        $dumpfile("sim_data/tb_layer2.vcd");
        $dumpvars(0, tb_layer2_compute);
    end

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0; valid_in = 0;
        for (int i = 0; i < 32; i++) l1_out[i] = 0;
        #20 rst_n = 1;
        
        // Test: Send simple test vectors
        repeat (10) begin
            @(posedge clk);
            valid_in <= 1;
            // Simple ramp pattern
            for (int i = 0; i < 32; i++) l1_out[i] <= i - 16;
        end
        
        valid_in = 0;
        
        // Wait for pipeline and outputs
        repeat (100) begin
            @(posedge clk);
            if (valid_out) begin
                $display("[%0t] L2 Output: out[0]=%d out[31]=%d (should have ReLU)", 
                         $time, l2_out[0], l2_out[31]);
                if (l2_out[0] === 16'hxxxx || l2_out[31] === 16'hxxxx) begin
                    $display("ERROR: Undefined output values detected!");
                end
            end
        end
        
        $display("===== LAYER2_COMPUTE UNIT TEST COMPLETE =====");
        $finish;
    end

endmodule
