/* * BIT-EXACT NEURAL CORE SIMULATOR
 * Behavior: Reads Integers -> Fixed Point Math -> Writes Integers
 * No Floats allowed in the signal path.
 */

#include <iostream>
#include <vector>
#include <fstream>
#include <algorithm>

// --- HARDWARE CONFIGURATION ---
const int FRAC_BITS = 14;      // Q1.14 Format
const int MAX_INT   = 32767;   // 16-bit Signed Max
const int MIN_INT   = -32768;  // 16-bit Signed Min

// --- 1. DATA LOADER ---
std::vector<int> read_file(std::string filename) {
    std::vector<int> data;
    std::ifstream file("sim_data/" + filename);
    if (!file.is_open()) {
        std::cerr << "[ERR] Cannot open " << filename << std::endl;
        exit(1);
    }
    int val;
    while (file >> val) data.push_back(val);
    return data;
}

// --- 2. THE NEURON (DSP SLICE) ---
int dsp_mac_unit(const std::vector<int>& inputs, const std::vector<int>& weights, int bias, int neuron_idx, int n_inputs, bool use_relu) {
    long long accumulator = 0; // 64-bit Accumulator Register
    
    // A. MAC Loop
    for (int i = 0; i < n_inputs; i++) {
        // Calculate RAM address for weight
        // Python saves weights as [Input0_N0, Input0_N1...] (Row Major)
        // So Weight for Input 'i' and Neuron 'n' is at: i * N_NEURONS + n
        int w_idx = i * (weights.size() / n_inputs) + neuron_idx; 
        
        // 1. Multiply (16-bit * 16-bit = 32-bit)
        long long product = (long long)inputs[i] * (long long)weights[w_idx];
        
        // 2. Accumulate (No clipping yet)
        accumulator += product;
    }

    // B. Post-Processing
    // 1. Bit Shift (Scaling back to Q1.14)
    accumulator = accumulator >> FRAC_BITS;

    // 2. Add Bias
    accumulator += bias;

    // 3. ReLU (Activation Logic)
    if (use_relu && accumulator < 0) accumulator = 0;

    // 4. Saturation (Clamping to 16-bit Output Wire)
    if (accumulator > MAX_INT) accumulator = MAX_INT;
    if (accumulator < MIN_INT) accumulator = MIN_INT;

    return (int)accumulator;
}

// --- 3. MAIN TESTBENCH ---
int main() {
    std::cout << "--- HARDWARE SIMULATION START ---" << std::endl;

    // Load ROMs
    std::vector<int> L1_W = read_file("L1_W.txt");
    std::vector<int> L1_b = read_file("L1_b.txt");
    std::vector<int> L2_W = read_file("L2_W.txt");
    std::vector<int> L2_b = read_file("L2_b.txt");
    std::vector<int> L3_W = read_file("L3_W.txt");
    std::vector<int> L3_b = read_file("L3_b.txt");

    // Load Stimuli (Input Stream)
    std::vector<int> stream_in = read_file("input_stimuli.txt");
    
    // Open Output Stream
    std::ofstream file_out("sim_data/output_integers.txt");

    int INPUT_WIDTH = 10; // 5 Complex Symbols
    int num_cycles = stream_in.size() / INPUT_WIDTH;
    
    std::cout << "Processing " << num_cycles << " cycles..." << std::endl;

    for (int t = 0; t < num_cycles; t++) {
        // 1. Latch Input Window
        std::vector<int> window;
        for (int k = 0; k < INPUT_WIDTH; k++) {
            window.push_back(stream_in[t * INPUT_WIDTH + k]);
        }

        // 2. Layer 1 (Hidden)
        int L1_SIZE = L1_b.size();
        std::vector<int> L1_out;
        for (int n = 0; n < L1_SIZE; n++) {
            L1_out.push_back(dsp_mac_unit(window, L1_W, L1_b[n], n, INPUT_WIDTH, true));
        }

        // 3. Layer 2 (Hidden)
        int L2_SIZE = L2_b.size();
        std::vector<int> L2_out;
        for (int n = 0; n < L2_SIZE; n++) {
            L2_out.push_back(dsp_mac_unit(L1_out, L2_W, L2_b[n], n, L1_SIZE, true));
        }

        // 4. Layer 3 (Output)
        int L3_SIZE = L3_b.size();
        std::vector<int> L3_out;
        for (int n = 0; n < L3_SIZE; n++) {
            // No ReLU for output!
            L3_out.push_back(dsp_mac_unit(L2_out, L3_W, L3_b[n], n, L2_SIZE, false));
        }

        // 5. Write Result (I Q)
        file_out << L3_out[0] << " " << L3_out[1] << "\n";
    }

    file_out.close();
    std::cout << "--- SIMULATION COMPLETE ---" << std::endl;
    return 0;
}