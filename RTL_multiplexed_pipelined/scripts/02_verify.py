import numpy as np
import matplotlib.pyplot as plt
import os

SCALE = 16384.0 
VOLT_MULTIPLIER = 5.0

print("=== DEEP SEARCH AUTO-ALIGNMENT VERIFIER ===")
if not os.path.exists("../sim_data/rtl_output.txt"):
    print("[ERR] rtl_output.txt not found!")
    exit(1)

rtl_int = np.loadtxt("../sim_data/rtl_output.txt")
target_volt = np.loadtxt("../sim_data/target_voltages.txt")

# Convert Q1.14 back to Voltage
rtl_volt = (rtl_int / SCALE) * VOLT_MULTIPLIER 
target_complex = target_volt[:, 0] + 1j * target_volt[:, 1]

# Generate possible hardware mix-ups
configs = {
    "Normal": rtl_volt[:, 0] + 1j * rtl_volt[:, 1],
    "Swapped I/Q": rtl_volt[:, 1] + 1j * rtl_volt[:, 0],
    "Inverted Signs": -rtl_volt[:, 0] - 1j * rtl_volt[:, 1]
}

best_mse = float('inf')
best_delay = 0
best_config = ""
r_best_aligned = []
t_best_aligned = []

print("-> Sweeping time delays (-80 to +90 symbols) across all I/Q configurations...")

for name, r_complex in configs.items():
    # EXPANDED SEARCH RANGE: -80 to 90
    for delay in range(-80, 91):
        if delay > 0:
            t_slice = target_complex[delay : delay + len(r_complex)]
            r_slice = r_complex[:len(t_slice)]
        elif delay < 0:
            abs_d = abs(delay)
            r_slice = r_complex[abs_d : abs_d + len(target_complex)]
            t_slice = target_complex[:len(r_slice)]
        else:
            t_slice = target_complex[:len(r_complex)]
            r_slice = r_complex[:len(t_slice)]
            
        if len(t_slice) == 0: continue
        
        mse = np.mean(np.abs(t_slice - r_slice)**2)
        if mse < best_mse:
            best_mse = mse
            best_delay = delay
            best_config = name
            r_best_aligned = r_slice
            t_best_aligned = t_slice

print("-" * 40)
print(f"-> Optimal Configuration Found: {best_config}")
print(f"-> Optimal Pipeline Shift: {best_delay} symbols")
print(f"-> True Mean Squared Error (MSE): {best_mse:.6f}")
print("-" * 40)

# =========================================================
# PLOTTING
# =========================================================
plt.figure(figsize=(12, 5))
plt.subplot(1, 2, 1)
plt.scatter(t_best_aligned.real, t_best_aligned.imag, c='blue', s=80, alpha=0.3, label='Target')
plt.scatter(r_best_aligned.real, r_best_aligned.imag, c='lime', s=10, label=f'RTL ({best_config})')
plt.title(f"Constellation (MSE = {best_mse:.6f})")
plt.grid(True)
plt.legend()

plt.subplot(1, 2, 2)
plt.scatter(t_best_aligned.real, t_best_aligned.imag, c='blue', s=800, alpha=0.1)
plt.scatter(r_best_aligned.real, r_best_aligned.imag, c='red', s=20)
plt.xlim(2, 4)
plt.ylim(2, 4)
plt.title(f"Zoom (+3, +3) [Delay: {best_delay}]")
plt.grid(True)
plt.show()
