`timescale 1ns / 1ps

module tb_layer3_compute ();

    logic clk, rst_n;
    logic valid_in;
    logic signed [15:0] l2_out [0:31];
    wire signed [15:0] l3_out [0:1];
    wire valid_out;

    layer3_compute DUT (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in),
        .l2_out(l2_out),
        .l3_out(l3_out),
        .valid_out(valid_out)
    );

    initial begin
        $dumpfile("sim_data/tb_layer3.vcd");
        $dumpvars(0, tb_layer3_compute);
    end

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0; valid_in = 0;
        for (int i = 0; i < 32; i++) l2_out[i] = 0;
        #20 rst_n = 1;
        
        // Test: Send simple test vectors
        repeat (5) begin
            @(posedge clk);
            valid_in <= 1;
            // Simple ramp pattern
            for (int i = 0; i < 32; i++) l2_out[i] <= i - 16;
        end
        
        valid_in = 0;
        
        // Wait for pipeline and outputs
        repeat (100) begin
            @(posedge clk);
            if (valid_out) begin
                $display("[%0t] L3 Output: l3_out[0]=%d (0x%04x) l3_out[1]=%d (0x%04x) valid=%b", 
                         $time, l3_out[0], l3_out[0], l3_out[1], l3_out[1], valid_out);
                if (l3_out[0] === 16'hxxxx || l3_out[1] === 16'hxxxx) begin
                    $display("ERROR: Undefined output values detected!");
                end
            end
        end
        
        $display("===== LAYER3_COMPUTE UNIT TEST COMPLETE =====");
        $finish;
    end

endmodule
