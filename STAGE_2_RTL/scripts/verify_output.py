import numpy as np
import matplotlib.pyplot as plt

# Config
FRAC_BITS = 14
SCALE     = 1 << FRAC_BITS
MAX_VAL   = 5.0

print("--- VERIFYING RTL OUTPUT ---")

# 1. Load RTL Output
try:
    rtl_data = np.loadtxt("rtl_output.txt")
    rtl_complex = (rtl_data[:,0] + 1j*rtl_data[:,1]) / SCALE * MAX_VAL
except:
    print("[ERR] rtl_output.txt not found. Run 'make run' first.")
    exit()

# 2. Load Ground Truth (From Golden Model)
try:
    # Need to reshape because target_voltages might be flat or columns
    target_data = np.loadtxt("sim_data/target_voltages.txt")
    # Take first 100 samples to match RTL
    target_data = target_data[:100] 
    target_complex = target_data[:,0] + 1j*target_data[:,1]
except:
    print("[ERR] sim_data/target_voltages.txt not found.")
    exit()

# 3. Calculate Error
error = np.abs(target_complex - rtl_complex)
mse = np.mean(error**2)
print(f"MSE: {mse:.6f}")

if mse < 0.01:
    print("[PASS] RTL Matches Golden Model!")
else:
    print("[FAIL] Significant Deviation Detected.")

# 4. Plot
plt.figure(figsize=(10,5))
plt.subplot(1,2,1)
plt.plot(target_complex.real, label="Target I")
plt.plot(rtl_complex.real, '--', label="RTL I")
plt.legend()
plt.title("Waveform Comparison (I)")

plt.subplot(1,2,2)
plt.scatter(target_complex.real, target_complex.imag, c='b', alpha=0.5, label='Target')
plt.scatter(rtl_complex.real, rtl_complex.imag, c='r', marker='x', label='RTL')
plt.legend()
plt.title("Constellation Check")
plt.savefig("rtl_verification.png")
print("Plot saved to rtl_verification.png")