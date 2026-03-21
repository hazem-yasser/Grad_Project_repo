`timescale 1ns / 1ps

module tb_input_window_ctrl ();

    logic clk, rst_n;
    logic signed [15:0] in_I, in_Q;
    logic valid_in;
    wire signed [15:0] win_I [0:4];
    wire signed [15:0] win_Q [0:4];
    wire valid_out;

    int errors = 0;
    int pulses_during_stream = 0;
    int pulses_during_idle = 0;
    localparam signed [15:0] INIT_VAL = 16'shD99A;

    input_window_ctrl DUT (
        .clk(clk), .rst_n(rst_n),
        .in_I(in_I), .in_Q(in_Q), .valid_in(valid_in),
        .win_I(win_I), .win_Q(win_Q), .valid_out(valid_out)
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
        repeat (3) @(posedge clk);
        #1;

        // Reset check: window must initialize to INIT_VAL and valid_out must be low
        for (int i = 0; i < 5; i++) begin
            if (win_I[i] !== INIT_VAL || win_Q[i] !== INIT_VAL) begin
                $display("ERROR: Reset init mismatch at index %0d: win_I=%0d win_Q=%0d", i, win_I[i], win_Q[i]);
                errors++;
            end
        end
        if (valid_out !== 1'b0) begin
            $display("ERROR: valid_out must be 0 during reset");
            errors++;
        end

        rst_n = 1;
        @(posedge clk);

        // Stream 5 valid samples: expected pulses on sample 3,4,5 => 3 pulses
        for (int s = 0; s < 5; s++) begin
            in_I = 16'sd100 + s;
            in_Q = -16'sd200 - s;
            valid_in = 1;
            @(posedge clk);
            #1;

            if (valid_out === 1'b1) pulses_during_stream++;
            if ((^win_I[4] === 1'bx) || (^win_Q[4] === 1'bx)) begin
                $display("ERROR: Unknown value detected in output window at sample %0d", s);
                errors++;
            end
        end

        valid_in = 0;
        in_I = 0;
        in_Q = 0;

        // Idle for timeout-driven flush window
        repeat (65) begin
            @(posedge clk);
            #1;
            if (valid_out === 1'b1) pulses_during_idle++;
        end

        if (pulses_during_stream < 3 || pulses_during_stream > 5) begin
            $display("ERROR: Unexpected stream pulse count: got %0d (expected in range 3..5)", pulses_during_stream);
            errors++;
        end

        if (pulses_during_idle != 2) begin
            $display("ERROR: Expected 2 timeout flush pulses during idle, got %0d", pulses_during_idle);
            errors++;
        end

        if (errors == 0) begin
            $display("PASS: INPUT_WINDOW_CTRL unit test passed");
            $finish;
        end else begin
            $fatal(1, "FAIL: INPUT_WINDOW_CTRL unit test failed with %0d errors", errors);
        end
    end

endmodule
