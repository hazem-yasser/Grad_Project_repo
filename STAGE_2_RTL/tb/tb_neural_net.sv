`timescale 1ns / 1ps

module tb_neural_net;

    logic clk;
    logic signed [15:0] test_input [10];
    logic signed [15:0] i_out, q_out;
    logic signed [15:0] input_rom [20000]; // Make it huge to fit any input file
    int file_handle;

    Neural_Network dut (.*, .flattened_input(test_input));

    initial begin
        // Load Input Stimuli
        // $readmemh("hex_files/input_stimuli.hex", input_rom);

        // // Open Output File
        // file_handle = $fopen("rtl_output.txt", "w");
        
        // ... inside initial begin ...
    
        $readmemh("hex_files/input_stimuli.hex", input_rom);
        file_handle = $fopen("rtl_output.txt", "w");

        // --- ADD THIS DEBUG BLOCK ---
        $display("DEBUG: First 5 ROM Inputs:");
        for(int k=0; k<5; k++) $display("ROM[%0d] = %d (Hex: %h)", k, input_rom[k], input_rom[k]);
        // ----------------------------

        for (int s = 0; s < 100; s++) begin
            // ... rest of your loop ...
            
            #10;
            
            // --- ADD THIS DEBUG PRINT FOR FIRST SAMPLE ---
            if (s == 0) begin
                $display("DEBUG: Sample 0 Output -> I: %d, Q: %d", i_out, q_out);
            end
            // ---------------------------------------------
            
            $fdisplay(file_handle, "%d %d", i_out, q_out);
        end
        // Loop 100 samples
        for (int s = 0; s < 100; s++) begin
            for (int k = 0; k < 10; k++) test_input[k] = input_rom[s*10 + k];
            
            #10; // Propagate
            
            // Save to Text file (Decimal for Python)
            $fdisplay(file_handle, "%d %d", i_out, q_out);
        end

        $fclose(file_handle);
        $finish;
    end

endmodule