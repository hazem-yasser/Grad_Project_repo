This is the perfect moment to pause and justify your engineering decisions. In your defense, the professors will ask: _"Why did you pick 2 layers? Why 32 neurons? Why not a Transformer or LSTM?"_

Here is your **Defense Strategy**, the **Visual Architecture**, and the code to generate the professional "Sci-Fi" plot.

### **1. The Architecture Blueprint (The "Sci-Fi" Drawing)**

You are building a **Feed-Forward Multi-Layer Perceptron (MLP)**.

Imagine it as a funnel: it takes a wide view of the past/future (Window) and compresses it down to a single clean truth (The Center Symbol).

**Here is the specific topology of YOUR network:**

Plaintext

```
       [ INPUT LAYER ]             [ HIDDEN LAYER 1 ]          [ HIDDEN LAYER 2 ]          [ OUTPUT ]
      (The Context Window)        (Feature Extraction)        (Non-linear Solving)       (Clean Symbol)

          (Re_t-2) ● ───┐
          (Im_t-2) ● ───┤
          (Re_t-1) ● ───┤             ● (N_1)                     ● (N_1)
          (Im_t-1) ● ───┤           /   \                       /   \
          (Re_t)   ● ───┼───────── ● (N_2) ─────────────────── ● (N_2) ─────────────── ● (Real_Out)
          (Im_t)   ● ───┤           \   /                       \   /                    \
          (Re_t+1) ● ───┤             ● (N_3)                     ● (N_3)                 ● (Imag_Out)
          (Im_t+1) ● ───┤             .                           .
          (Re_t+2) ● ───┤             .                           .
          (Im_t+2) ● ───┘             ● (N_32)                    ● (N_32)

      [10 Neurons]               [32 Neurons]                [32 Neurons]               [2 Neurons]
      Raw Noisy Data              tanh activation             tanh activation             Linear
```

---

### **2. Design Justification (The "Why")**

Here is exactly what you tell the judges when they ask why you didn't make it "bigger and better":

#### **Q1: Why this specific size (32 neurons)?**

- **The Answer:** "Hardware Efficiency."
    
- **The Logic:** In FPGA/ASIC design, we love **Powers of 2** (16, 32, 64). Using 32 neurons aligns perfectly with memory addressing and binary buses.
    
- **The Trade-off:**
    
    - _Too Small (e.g., 8 neurons):_ Cannot learn the complex "Spiral" shape of the Kerr effect.
        
    - _Too Big (e.g., 128 neurons):_ It consumes 4x the area on the chip for only 1% better accuracy. It kills the **Throughput**.
        
    - _32 Neurons:_ The "Goldilocks Zone" – accurate enough for 16QAM, small enough to run at Giga-speeds.
        

#### **Q2: Why `tanh` activation? Why not ReLU?**

- **The Answer:** "Signal Symmetry."
    
- **The Logic:**
    
    - **ReLU** (`max(0, x)`) kills all negative numbers. But in 16QAM, the signal goes from **-3 to +3**. Negative values are just as important as positive ones!
        
    - **Tanh** (`-1 to +1`) is symmetric. It preserves the "sign" of the signal while squashing outliers. It mimics the behavior of physical amplifiers (saturation).
        

#### **Q3: Why not a Recurrent Network (LSTM/GRU)?**

- **The Answer:** "Latency."
    
- **The Logic:** LSTMs are great for time, but they must process symbols _one by one_ in a sequence. You cannot parallelize them easily.
    
- **Your MLP:** We can instantiate 64 copies of this MLP and process 64 symbols **at the exact same nanosecond**. This is the only way to reach **34 Gbaud**.
    

---

### **_

### **4. Next Steps (Actionable)**

Now that you understand the "Why" and have fixed the `protobuf` error:

1. **Restart Kernel & Run:** Execute the full script (Blocks 1, 2, 3) with the `protobuf` fix.
    
2. **Verify the Clusters:** Confirm you see the "Green Dots" forming clusters.
    
3. **Phase 2 Preview:** Once you confirm the cleanup works, we need to convert these "Float32" weights (which take huge space) into "Fixed-Point Integers" (which fit on the chip).
    

**Are you running the training now? Tell me the "MSE Improvement" number you get!**

### **The Real Problem: "Abysmal Results"**

Since the code is running, let's fix the **actual** problem you mentioned: the bad results.

The reason your Neural Network failed to converge (bad MSE) is likely **Normalization**.

- **The Physics:** Your 16QAM signals range from **-3 to +3**.
    
- **The Math:** Neural Networks (especially with `tanh`) love numbers between **-1 and +1**. When inputs are large (like 3.0), the `tanh` function "saturates" (flattens out), and the gradient becomes zero. The network stops learning.
    

**The Fix:**

We need to **Scale** your data before feeding it to the network.

Add this small "Block 1.5" **before** you split the data:

Python

```
# =============================================================================
# BLOCK 1.5: NORMALIZATION (Crucial for Convergence)
# =============================================================================
# We divide by the max value (approx 3.0 for 16QAM) to squash data into -1 to 1 range
max_val = np.max(np.abs(X_data))
print(f"Scaling data by factor: {max_val}")

X_data_scaled = X_data / max_val
y_data_scaled = y_data / max_val

# Now split the SCALED data
X_train, X_test, y_train, y_test = train_test_split(X_data_scaled, y_data_scaled, test_size=0.2, random_state=42)
```

**Next Step:**

1. Add this scaling block.
    
2. Run the training again.
    
3. **Important:** When plotting the final graph, remember to multiply the output by `max_val` to get the original numbers back!
    

Do you want me to give you the updated "Block 3" that includes this **Un-scaling** for the plot?