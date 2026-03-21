`timescale 1ns / 1ps

module tb_layer1_compute ();

    logic clk, rst_n;
    logic valid_in;
    logic signed [15:0] win_I [0:4];
    logic signed [15:0] win_Q [0:4];
    wire signed [15:0] l1_out [0:31];
    wire valid_out;

    int errors = 0;
    int expected_outputs = 0;
    int seen_outputs = 0;

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

    task automatic send_window(input int seed);
        int timeout;
        begin
            for (int i = 0; i < 5; i++) begin
                win_I[i] = seed + (i * 11);
                win_Q[i] = -seed - (i * 7);
            end
            valid_in = 1;
            @(posedge clk);
            #1;
            valid_in = 0;
            expected_outputs++;

            // Deterministic handshake: wait for this transaction output pulse
            timeout = 0;
            while (!valid_out && timeout < 20) begin
                @(posedge clk);
                #1;
                timeout++;
            end
            if (!valid_out) begin
                $display("ERROR: Timeout waiting for L1 valid_out pulse after seed=%0d", seed);
                errors++;
            end
        end
    endtask

    always @(posedge clk) begin
        #1;
        if (valid_out) begin
            seen_outputs++;
            for (int i = 0; i < 32; i++) begin
                if (^l1_out[i] === 1'bx) begin
                    $display("ERROR: L1 output[%0d] is X at t=%0t", i, $time);
                    errors++;
                end
                if ($signed(l1_out[i]) < 0) begin
                    $display("ERROR: L1 output[%0d] is negative (%0d), ReLU expected", i, $signed(l1_out[i]));
                    errors++;
                end
            end
        end
    end

    initial begin
        rst_n = 0; valid_in = 0;
        for (int i = 0; i < 5; i++) begin
            win_I[i] = 0; win_Q[i] = 0;
        end
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Send deterministic windows with proper spacing
        send_window(100);
        send_window(300);
        send_window(500);
        send_window(700);

        repeat (10) @(posedge clk);

        if (seen_outputs != expected_outputs) begin
            $display("ERROR: L1 valid_out count mismatch. expected=%0d seen=%0d", expected_outputs, seen_outputs);
            errors++;
        end

        if (errors == 0) begin
            $display("PASS: LAYER1_COMPUTE unit test passed (outputs=%0d)", seen_outputs);
            $finish;
        end else begin
            $fatal(1, "FAIL: LAYER1_COMPUTE unit test failed with %0d errors", errors);
        end
    end

endmodule
