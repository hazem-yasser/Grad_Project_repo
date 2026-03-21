`timescale 1ns / 1ps

module tb_input_window_ctrl ();

    logic clk, rst_n;
    logic signed [15:0] in_I, in_Q;
    logic valid_in;
    logic signed [15:0] out_I [0:4];
    logic signed [15:0] out_Q [0:4];
    logic valid_out;

    input_window_ctrl DUT (
        .clk(clk), .rst_n(rst_n),
        .in_I(in_I), .in_Q(in_Q), .valid_in(valid_in),
        .out_I(out_I), .out_Q(out_Q), .valid_out(valid_out)
    );

    initial begin
        $dumpfile("sim_data/tb_input_window.vcd");
        $dumpvars(0, tb_input_window_ctrl);
    end

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0; in_I = 0; in_Q = 0; valid_in = 0;
        #20 rst_n = 1;
        
        // Test: Send 5 samples, should warmup for 3, then fire every one
        repeat (50) begin
            @(posedge clk);
            in_I <= in_I + 1;
            in_Q <= in_Q + 2;
            valid_in <= 1;
            if (valid_out) $display("[%0t] Output window fire: I[0]=%d Q[0]=%d", $time, out_I[0], out_Q[0]);
        end
        
        // Test: Timeout flush (50 cycles idle)
        @(posedge clk);
        valid_in = 0; in_I = 0; in_Q = 0;
        repeat (60) @(posedge clk);
        
        $display("===== INPUT_WINDOW_CTRL UNIT TEST COMPLETE =====");
        $finish;
    end

endmodule
