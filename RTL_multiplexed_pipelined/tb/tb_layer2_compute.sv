`timescale 1ns / 1ps

module tb_layer2_compute ();

    logic clk, rst_n;
    logic valid_in;
    logic signed [15:0] l1_out [0:31];
    wire signed [15:0] l2_out [0:31];
    wire valid_out;

    int errors = 0;
    int expected_outputs = 0;
    int seen_outputs = 0;

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

    task automatic send_vector(input int seed);
        begin
            for (int i = 0; i < 32; i++) begin
                l1_out[i] = (seed + i) - 64;
            end
            valid_in = 1;
            @(posedge clk);
            #1;
            valid_in = 0;
            // Layer2 consumes 6 ticks
            repeat (5) @(posedge clk);
            expected_outputs++;
        end
    endtask

    always @(posedge clk) begin
        #1;
        if (valid_out) begin
            seen_outputs++;
            for (int i = 0; i < 32; i++) begin
                if (^l2_out[i] === 1'bx) begin
                    $display("ERROR: L2 output[%0d] is X at t=%0t", i, $time);
                    errors++;
                end
                if ($signed(l2_out[i]) < 0) begin
                    $display("ERROR: L2 output[%0d] is negative (%0d), ReLU expected", i, $signed(l2_out[i]));
                    errors++;
                end
            end
        end
    end

    initial begin
        rst_n = 0; valid_in = 0;
        for (int i = 0; i < 32; i++) l1_out[i] = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        send_vector(10);
        send_vector(70);
        send_vector(130);
        send_vector(190);

        repeat (20) @(posedge clk);

        if (seen_outputs != expected_outputs) begin
            $display("ERROR: L2 valid_out count mismatch. expected=%0d seen=%0d", expected_outputs, seen_outputs);
            errors++;
        end

        if (errors == 0) begin
            $display("PASS: LAYER2_COMPUTE unit test passed (outputs=%0d)", seen_outputs);
            $finish;
        end else begin
            $fatal(1, "FAIL: LAYER2_COMPUTE unit test failed with %0d errors", errors);
        end
    end

endmodule
