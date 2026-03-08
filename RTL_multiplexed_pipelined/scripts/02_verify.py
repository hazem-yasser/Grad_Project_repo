import numpy as np
import matplotlib.pyplot as plt
import os

# --- CONFIGURATION ---
SCALE = 16384.0      
VOLT_MULTIPLIER = 5.0 

print("=== VERIFICATION: RTL vs TARGET ===")

if not os.path.exists("../sim_data/rtl_output.txt"):
    print("[ERROR] rtl_output.txt not found. Run simulation first!")
    exit(1)

# 1. LOAD DATA
rtl_int = np.loadtxt("../sim_data/rtl_output.txt")
target_volt = np.loadtxt("../sim_data/target_voltages.txt")

# Check Lengths (Should be exact match now!)
if len(rtl_int) != len(target_volt):
    print(f"[WARNING] Length Mismatch! RTL={len(rtl_int)}, Target={len(target_volt)}")
    # Truncate to match smallest to prevent crash
    min_len = min(len(rtl_int), len(target_volt))
    rtl_int = rtl_int[:min_len]
    target_volt = target_volt[:min_len]

# 2. CONVERT RTL TO VOLTAGE
rtl_volt = (rtl_int / SCALE) * VOLT_MULTIPLIER

# 3. AUTO-ALIGNMENT (Find Constant Pipeline Latency)
# We expect a fixed latency due to the pipeline stages.
# We compare the signals to find the shift that gives min MSE.
r_complex = rtl_volt[:, 0] + 1j * rtl_volt[:, 1]
t_complex = target_volt[:, 0] + 1j * target_volt[:, 1]

best_mse = float('inf')
best_delay = 0
aligned_r = []
aligned_t = []

# Search small window of possible hardware latency (0 to 20 cycles)
for delay in range(0, 20):
    # If RTL is delayed by N, we compare Target[0] with RTL[N]
    # BUT wait! Our Smart Window + Auto Flush guarantees 1:1 symbol match.
    # The "delay" here is PURELY the pipeline depth (Layer 1 + Layer 2 + Layer 3).
    # Since we flushed the pipe, the file should align almost perfectly at index 0 or small +N.
    
    # We slice the ends off to compare the overlapping middle section
    t_slice = t_complex[:len(r_complex)-delay]
    r_slice = r_complex[delay:]
    
    if len(t_slice) == 0: continue

    mse = np.mean(np.abs(t_slice - r_slice)**2)
    
    if mse < best_mse:
        best_mse = mse
        best_delay = delay
        aligned_r = r_slice
        aligned_t = t_slice

print("-" * 30)
print(f"Pipeline Latency Found: {best_delay} symbols")
print(f"FINAL MSE: {best_mse:.6f}")
print("-" * 30)

# 4. PLOTTING
plt.figure(figsize=(12, 5))

plt.subplot(1, 2, 1)
plt.scatter(aligned_t.real, aligned_t.imag, c='blue', s=50, alpha=0.2, label='Target')
plt.scatter(aligned_r.real, aligned_r.imag, c='lime', s=15, label='RTL Output')
plt.title(f"16-QAM Constellation\nMSE = {best_mse:.5f}")
plt.xlabel("In-Phase (I)")
plt.ylabel("Quadrature (Q)")
plt.grid(True, alpha=0.3)
plt.legend()

plt.subplot(1, 2, 2)
plt.scatter(aligned_t.real, aligned_t.imag, c='blue', s=100, alpha=0.2)
plt.scatter(aligned_r.real, aligned_r.imag, c='red', s=20)
plt.xlim(2, 4)
plt.ylim(2, 4)
plt.title("Zoomed Cluster (+3V, +3V)")
plt.grid(True, alpha=0.3)

plt.tight_layout()
plt.show()