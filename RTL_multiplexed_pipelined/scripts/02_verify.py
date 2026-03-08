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

# 4. SER / BER (Gray-coded 16-QAM)
# 16-QAM ideal levels (normalised to +/-1, +/-3 volts)
qam_levels = np.array([-3.0, -1.0, 1.0, 3.0])

# Gray code mapping for each PAM-4 axis (2 bits per axis)
#   level -3 -> 00,  -1 -> 01,  +1 -> 11,  +3 -> 10
gray_map = {0: 0b00, 1: 0b01, 2: 0b11, 3: 0b10}

def nearest_level_idx(vals):
    """Return index into qam_levels for each value."""
    # vals shape (N,), returns (N,) of int indices 0-3
    dists = np.abs(vals[:, None] - qam_levels[None, :])   # (N,4)
    return np.argmin(dists, axis=1)

# Decide target and RTL symbol indices (I and Q independently)
t_I_idx = nearest_level_idx(aligned_t.real)
t_Q_idx = nearest_level_idx(aligned_t.imag)
r_I_idx = nearest_level_idx(aligned_r.real)
r_Q_idx = nearest_level_idx(aligned_r.imag)

# Symbol error: symbol wrong if either axis wrong
sym_errors = np.sum((t_I_idx != r_I_idx) | (t_Q_idx != r_Q_idx))
ser = sym_errors / len(aligned_t)

# Bit errors using Gray mapping (2 bits per axis, 4 bits per symbol)
bit_errors = 0
for i in range(len(aligned_t)):
    bit_errors += bin(gray_map[t_I_idx[i]] ^ gray_map[r_I_idx[i]]).count('1')
    bit_errors += bin(gray_map[t_Q_idx[i]] ^ gray_map[r_Q_idx[i]]).count('1')

total_bits = len(aligned_t) * 4
ber = bit_errors / total_bits

print(f"Symbol Errors : {sym_errors} / {len(aligned_t)}")
print(f"SER           : {ser:.6e}")
print(f"Bit Errors    : {bit_errors} / {total_bits}")
print(f"BER (Gray)    : {ber:.6e}")
print("-" * 30)

# 5. PLOTTING
plt.figure(figsize=(12, 5))

plt.subplot(1, 2, 1)
plt.scatter(aligned_t.real, aligned_t.imag, c='blue', s=50, alpha=0.2, label='Target')
plt.scatter(aligned_r.real, aligned_r.imag, c='lime', s=15, label='RTL Output')
plt.title(f"16-QAM Constellation\nMSE={best_mse:.5f}  SER={ser:.2e}  BER={ber:.2e}")
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
plt.savefig("../sim_data/constellation.png", dpi=200)
print(f"[SAVED] ../sim_data/constellation.png")
plt.show()