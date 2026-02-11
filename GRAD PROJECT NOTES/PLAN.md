# 16QAM Neural Equalizer Project - Master Plan

### The Goal
Design a **Hardware Accelerator (Chip)** that receives noisy/distorted **16QAM** signals, uses a Neural Network to clean them, and retrieves the original data, achieving a better BER than traditional linear equalizers.

---

### Phase 1: The Golden Reference (Python & Algorithm)
**Goal:** Build the full system in Software to verify the Neural Network can solve the problem.

1.  **System Simulation:**
    * Write Python code using `NumPy` to generate random **16QAM** symbols (Target).
    * Add the channel effects: **ISI** (Linear Filter), **Non-linearity** (Saturation/Kerr Effect), and **AWGN** (Noise).
    * **Result:** You will have two arrays: `clean_data` and `distorted_data`.

2.  **Data Preparation (Sliding Window):**
    * Prepare data using the **Sliding Window** technique.
    * Each Input to the NN will be a group of samples (e.g., 5 consecutive complex samples).
    * **Input Shape:** `(Batch_Size, Window_Size)`.

3.  **Model Training:**
    * Build a simple MLP (Multi-Layer Perceptron) using `Keras` or `PyTorch`.
    * **Input Layer:** 10 Neurons (5 Real + 5 Imaginary) — *or use complex numbers if supported*.
    * **Output Layer:** 2 Neurons (Predicted I, Predicted Q).
    * Train using **MSE Loss** (Mean Squared Error).

4.  **Performance Check:**
    * Plot the **Constellation Diagram** (Before vs. After).
    * Calculate **BER** (Bit Error Rate) and confirm it beats the traditional Linear Equalizer.

---

### Phase 2: Hardware-Aware Optimization (Quantization)
**Goal:** Convert the "Smooth" Float model into "Rough" Fixed-Point numbers for Hardware.

1.  **Fixed-Point Conversion:**
    * Verilog does not understand `0.12345`. Convert all numbers (Weights, Biases, Inputs) to **Integers**.
    * Example: Use **8-bit Fixed Point** (where 1.0 is represented as 127).
    * **Formula:** `Int_Value = round(Float_Value * 2^Scale_Factor)`.

2.  **Export Weights:**
    * Extract the trained weights from Python.
    * Save them into text files (`weights_layer1.txt`, `bias_layer1.txt`) in **Hex** or **Binary** format for easy copying to Verilog.

---

### Phase 3: RTL Design (The Core Work - Verilog)
**Goal:** Write the actual Hardware code that performs the math.

1.  **Architecture Design:**
    * Design the **Shift Register** to hold the Sliding Window (this is the input buffer).
    * *Note: This mimics the "Context" the network needs.*

2.  **The Compute Unit (MAC):**
    * Design a **Multiply-Accumulate (MAC)** unit.
    * Instantiate this unit for every Neuron in a layer to achieve **Parallelism**.

3.  **Activation Function:**
    * Since you are using `Tanh` or `ReLU`:
        * **For Tanh:** Design a small **Lookup Table (ROM)**.
        * **For ReLU:** Use a simple `if (x < 0) x = 0;` statement.

4.  **Control Unit:**
    * Design a simple **FSM (Finite State Machine)** to control the flow:
    * `Load Data` -> `Compute Layer 1` -> `Compute Layer 2` -> `Output Result`.

---

### Phase 4: Verification (Comparison)
**Goal:** Prove the Hardware output matches the Python output exactly.

1.  **Testbench Generation:**
    * Write a SystemVerilog Testbench that reads `distorted_data.txt`.
    * Feed the data into your Module.
    * Write the output to `verilog_output.txt`.

2.  **Bit-Exact Matching:**
    * Compare `verilog_output.txt` with the Python predictions.
    * They must match perfectly (bit-exact).

---

### Immediate Next Step (The Weekend Task)
To break the fear of starting, focus only on **Phase 1 (Step 1 & 2)** right now.

1.  Open Python.
2.  Generate a **16QAM signal**.
3.  Distort it with **Noise**.
4.  Plot it to see the "cloud" of points.
