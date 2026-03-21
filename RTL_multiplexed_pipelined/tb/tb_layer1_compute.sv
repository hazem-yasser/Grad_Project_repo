`timescale 1ns / 1ps

module tb_layer1_compute ();

    logic clk, rst_n;
    logic valid_in;
    logic signed [15:0] win_I [0:4];
    logic signed [15:0] win_Q [0:4];
    logic signed [15:0] l1_out [0:31];
    logic valid_out;

    layer1_compute DUT (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in),
        .win_I(win_I), .win_Q(win_Q),
        .l1_out(l1_out), .valid_out(valid_out)
    );

    initial begin
        $dumpfile("sim_data/tb_layer1.vcd");
        $dumpvars(0, tb_layer1_compute);
    end

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    integer out_count = 0;

    initial begin
        rst_n = 0; valid_in = 0;
        for (int i = 0; i < 5; i++) begin
            win_I[i] = 0; win_Q[i] = 0;
        end
        #20 rst_n = 1;
        
        // Test: Send 10 valid windows
        repeat (10) begin
            @(posedge clk);
            valid_in <= 1;
            // Simple test pattern: increment
            for (int i = 0; i < 5; i++) begin
                win_I[i] <= out_count * 100 + i * 10;
                win_Q[i] <= out_count * 100 - i * 10;
            end
            out_count++;
        end
        
        // Wait for outputs
        repeat (40) @(posedge clk);
        valid_in = 0;
        repeat (100) begin
            @(posedge clk);
            if (valid_out) begin
                $display("[%0t] L1 Output #%0d valid: out[0]=%d out[31]=%d", 
                         $time, out_count, l1_out[0], l1_out[31]);
            end
        end
        
        $display("===== LAYER1_COMPUTE UNIT TEST COMPLETE =====");
        $finish;
    end

endmodule
