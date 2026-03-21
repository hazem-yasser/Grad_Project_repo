`timescale 1ns / 1ps

module tb_layer3_compute ();

    logic clk, rst_n;
    logic valid_in;
    logic signed [15:0] l2_out [0:31];
    wire signed [15:0] l3_out [0:1];
    wire valid_out;

    int errors = 0;
    int expected_outputs = 0;
    int seen_outputs = 0;
    logic signed [15:0] first_i, first_q;
    logic first_captured = 0;
    int changed_outputs = 0;

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

    task automatic send_vector(input int seed);
        begin
            for (int i = 0; i < 32; i++) begin
                l2_out[i] = (seed * 3) - i;
            end
            valid_in = 1;
            @(posedge clk);
            #1;
            valid_in = 0;
            // Layer3 consumes 6 ticks
            repeat (5) @(posedge clk);
            expected_outputs++;
        end
    endtask

    always @(posedge clk) begin
        #1;
        if (valid_out) begin
            seen_outputs++;

            if ((^l3_out[0] === 1'bx) || (^l3_out[1] === 1'bx)) begin
                $display("ERROR: L3 output contains X at t=%0t", $time);
                errors++;
            end

            if (!first_captured) begin
                first_i = l3_out[0];
                first_q = l3_out[1];
                first_captured = 1;
            end else if (l3_out[0] != first_i || l3_out[1] != first_q) begin
                changed_outputs++;
            end
        end
    end

    initial begin
        rst_n = 0; valid_in = 0;
        for (int i = 0; i < 32; i++) l2_out[i] = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        send_vector(20);
        send_vector(80);
        send_vector(140);
        send_vector(200);

        repeat (20) @(posedge clk);

        if (seen_outputs != expected_outputs) begin
            $display("ERROR: L3 valid_out count mismatch. expected=%0d seen=%0d", expected_outputs, seen_outputs);
            errors++;
        end

        if (changed_outputs == 0) begin
            $display("ERROR: L3 outputs did not react to input variation");
            errors++;
        end

        if (errors == 0) begin
            $display("PASS: LAYER3_COMPUTE unit test passed (outputs=%0d)", seen_outputs);
            $finish;
        end else begin
            $fatal(1, "FAIL: LAYER3_COMPUTE unit test failed with %0d errors", errors);
        end
    end

endmodule
