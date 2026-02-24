import numpy as np
import matplotlib.pyplot as plt
import os

SCALE = 16384.0 
VOLT_MULTIPLIER = 5.0

print("=== ANALYZING SYSTEMVERILOG RTL RESULTS ===")

if not os.path.exists("../sim_data/rtl_output.txt"):
    print("[ERR] rtl_output.txt not found!")
    exit(1)

rtl_int = np.loadtxt("../sim_data/rtl_output.txt")
target_volt = np.loadtxt("../sim_data/target_voltages.txt")

# Strict Q1.14 logic mapping back to voltage space
rtl_volt = (rtl_int / SCALE) * VOLT_MULTIPLIER

rtl_complex = rtl_volt[:, 0] + 1j * rtl_volt[:, 1]
target_complex = target_volt[:, 0] + 1j * target_volt[:, 1]

num_samples = min(len(rtl_complex), len(target_complex))
rtl_complex = rtl_complex[:num_samples]
target_complex = target_complex[:num_samples]

mse = np.mean(np.abs(target_complex - rtl_complex)**2)
print(f"Mean Squared Error (MSE): {mse:.6f}")

plt.figure(figsize=(12, 5))
plt.subplot(1, 2, 1)
plt.scatter(target_complex.real, target_complex.imag, c='blue', s=80, alpha=0.3, label='Target')
plt.scatter(rtl_complex.real, rtl_complex.imag, c='lime', s=10, label='RTL')
plt.title(f"Constellation (MSE = {mse:.6f})")
plt.grid(True); plt.legend()

plt.subplot(1, 2, 2)
plt.scatter(target_complex.real, target_complex.imag, c='blue', s=800, alpha=0.1)
plt.scatter(rtl_complex.real, rtl_complex.imag, c='red', s=20)
plt.xlim(2, 4); plt.ylim(2, 4)
plt.title("Zoom (+3, +3 Quadrant)")
plt.grid(True)
plt.show()
