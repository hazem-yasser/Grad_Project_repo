That is the perfect mindset. You have the advanced physics simulation (the "Problem"), and now you are about to build the AI (the "Solution").

Since you have the **Advanced Optical Channel** code running, we just need to make **one tiny adjustment** to **Sprint Block 1** to ensure it uses your new variable name `rx_final` (from the advanced code) instead of the old `rx_symbols`.

Here is the exact code for **Sprint Block 1, 2, and 3** adjusted for your new optical dataset.

### **Sprint Block 1: Data Preparation (The "Sliding Window")**

_Time Estimate: 1 Hour_

This block takes your `rx_final` (the twisted spiral data) and `tx_symbols` (the clean grid) and cuts them into windows of 5 samples so the AI can learn the context.

**Action:** Paste this directly after your "Visualization" block.



```Python
# =============================================================================
# BLOCK 1: DATA PREPARATION (Sliding Window & Feature Engineering)
# =============================================================================
from sklearn.model_selection import train_test_split
import tensorflow as tf # Import tensorflow here for later blocks

def prepare_data(rx_signal, tx_signal, window_size=5):
    X = []
    y = []
    
    # Pad the signal so we don't lose the first few symbols
    pad_width = window_size // 2
    rx_padded = np.pad(rx_signal, (pad_width, pad_width), mode='constant')
    
    for i in range(len(rx_signal)):
        # 1. Grab the window (Context)
        # e.g., if i=10, window is from 8 to 12 (centered on 10)
        window = rx_padded[i : i + window_size]
        
        # 2. Separate Real and Imaginary parts (The "Flattening")
        # Input Vector: [Re(t-2), Im(t-2), ..., Re(t), Im(t), ..., Re(t+2), Im(t+2)]
        features = np.concatenate([window.real, window.imag])
        X.append(features)
        
        # 3. Grab the Target (The clean center symbol)
        target = [tx_signal[i].real, tx_signal[i].imag]
        y.append(target)
        
    return np.array(X), np.array(y)

# --- Configuration ---
WINDOW_SIZE = 5  # Context window

# Run the function using your NEW variables (rx_final)
print("Preparing Dataset...")
X_data, y_data = prepare_data(rx_final, tx_symbols, WINDOW_SIZE)

# Split into Training (80%) and Testing (20%)
X_train, X_test, y_train, y_test = train_test_split(X_data, y_data, test_size=0.2, random_state=42)

print(f"Data Ready!")
print(f"Input Shape: {X_train.shape} (Samples, Features)")
print(f"Target Shape: {y_train.shape} (Samples, Real/Imag)")
```

- **Checkpoint:** Run this. It should print `Input Shape: (8000, 10)` (since you generated 10,000 symbols in the advanced code).
    

---

### **Sprint Block 2: The Brain (Model Architecture)**

_Time Estimate: 2 Hours_

We are building a small MLP. I kept it lightweight (32 neurons) so it translates easily to Verilog later.

**Action:** Paste this next.

Python

```
# =============================================================================
# BLOCK 2: MODEL ARCHITECTURE (The Neural Network)
# =============================================================================
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense

# Define the Model
model = Sequential([
    # Hidden Layer 1: 32 Neurons, Tanh activation (Good for signals between -1 and 1)
    Dense(32, activation='tanh', input_shape=(WINDOW_SIZE * 2,)), 
    
    # Hidden Layer 2: 32 Neurons, Tanh activation
    Dense(32, activation='tanh'),
    
    # Output Layer: 2 Neurons (I & Q), Linear activation (Raw voltage values)
    Dense(2, activation='linear') 
])

# Compile the model
# Optimizer: Adam (Standard robust optimizer)
# Loss: MSE (Mean Squared Error) - minimizes the Euclidean distance
model.compile(optimizer='adam', loss='mse')

model.summary()
```

- **Checkpoint:** Run this. Look for "Total params: ~1,500".
    

---

### **Sprint Block 3: Training & The "Magical" Plot**

_Time Estimate: 2 Hours_

This is the moment of truth. We train for 50 epochs and then plot the result.

**Action:** Paste this final block.

Python

```
# =============================================================================
# BLOCK 3: TRAINING & VISUALIZATION
# =============================================================================

# 1. Train the Model
print("Starting Training...")
history = model.fit(X_train, y_train, 
                    epochs=50,           
                    batch_size=32,       
                    validation_split=0.1, 
                    verbose=1)

# 2. Predict (Inference) on Test Data
print("Running Inference...")
y_pred = model.predict(X_test)

# Convert predictions back to Complex numbers for plotting
y_pred_complex = y_pred[:, 0] + 1j * y_pred[:, 1]
y_target_complex = y_test[:, 0] + 1j * y_test[:, 1]

# 3. VISUALIZATION (Comparison)
plt.figure(figsize=(12, 6))

# Plot 1: The Input (The Twisted Spiral we saw earlier)
# We reconstruct the center sample from X_test to show what the NN saw
# (Indices 4 and 9 correspond to the real/imag of the center sample in a window of 5)
center_real = X_test[:, 4] 
center_imag = X_test[:, 9]
rx_center_complex = center_real + 1j * center_imag

plt.subplot(1, 3, 1)
plt.scatter(rx_center_complex.real, rx_center_complex.imag, c='red', s=5, alpha=0.3)
plt.title("Input to NN (Distorted)")
plt.grid(True); plt.xlim(-5, 5); plt.ylim(-5, 5)

# Plot 2: The NN Output (Hopefully Clean)
plt.subplot(1, 3, 2)
plt.scatter(y_pred_complex.real, y_pred_complex.imag, c='green', s=5, alpha=0.5)
plt.title("NN Output (Equalized)")
plt.grid(True); plt.xlim(-5, 5); plt.ylim(-5, 5)

# Plot 3: The Target (Perfect Grid)
plt.subplot(1, 3, 3)
plt.scatter(y_target_complex.real, y_target_complex.imag, c='blue', s=5, alpha=0.5)
plt.title("Target (Ideal)")
plt.grid(True); plt.xlim(-5, 5); plt.ylim(-5, 5)

plt.tight_layout()
plt.show()

# 4. Calculate MSE Improvement
input_mse = np.mean(np.abs(y_target_complex - rx_center_complex)**2)
output_mse = np.mean(np.abs(y_target_complex - y_pred_complex)**2)

print(f"MSE Before Equalization: {input_mse:.4f}")
print(f"MSE After Equalization:  {output_mse:.4f}")
print(f"Improvement Factor:      {input_mse/output_mse:.2f}x")
```

### **What to look for:**

1. **Plot 1 (Red):** Should look like that messy spiral.
    
2. **Plot 2 (Green):** Should look like **16 tight clusters**. If you see 16 distinct blobs, **YOU WON!** The AI learned to untwist the spiral.
    
3. **Improvement Factor:** Look at the print output. If it says something like "Improvement Factor: 10x" or higher, you have solid proof for your graduation project.
    

**Go run it!** Tell me if you see the green clusters.