## TO DO 

- first create the system model for 16 QAM that generate the I & Q signals from the actual non noisy ones. 
- try to generate the channel effects of the fiber dual channel that is being modeled
- the actual haedware make use of paralelism to increase BW and takes input as FP
- i need to read both the IQ of each symbol from the ADC as a float in python and add activation functions and what not 

### **this doesnt qualify as good data set** it is only AWGN

```python
import numpy as np
import matplotlib.pyplot as plt

# ---------------------------------------------------------
# 1. System Parameters (إعدادات النظام)
# ---------------------------------------------------------
M = 16          # Modulation Order (16-QAM)
num_symbols = 5000  # عدد الرموز اللي هنبعتها
SNR_dB = 15     # مستوى جودة الإشارة (كل ما الرقم ده يقل، التشويش يزيد)

# ---------------------------------------------------------
# 2. Transmitter (توليد الداتا النضيفة)
# ---------------------------------------------------------
# 16-QAM Constellation Points (Standard Grid: -3, -1, 1, 3)
# بنعمل Grid من الأرقام المركبة (Real & Imaginary)
points = np.array([-3, -1, 1, 3])
constellation = []
for r in points:
    for i in points:
        constellation.append(r + 1j*i)
constellation = np.array(constellation)

# Generate random indices (0 to 15)
random_indices = np.random.randint(0, M, num_symbols)

# Map indices to symbols (This is the Clean TX Data)
tx_symbols = constellation[random_indices]

# ---------------------------------------------------------
# 3. Channel (إضافة التشويش)
# ---------------------------------------------------------
# حساب قوة الضوضاء بناءً على الـ SNR
# Calculate Noise Power
signal_power = np.mean(np.abs(tx_symbols)**2)
snr_linear = 10**(SNR_dB / 10.0)
noise_power = signal_power / snr_linear

# Generate Complex Gaussian Noise (AWGN)
noise = np.sqrt(noise_power/2) * (np.random.randn(num_symbols) + 1j * np.random.randn(num_symbols))

# The Received Signal (Noisy Data)
rx_symbols = tx_symbols + noise

# ---------------------------------------------------------
# 4. Visualization (الرسم)
# ---------------------------------------------------------
plt.figure(figsize=(10, 5))

# Plot 1: Clean Transmitted Symbols
plt.subplot(1, 2, 1)
plt.scatter(tx_symbols.real, tx_symbols.imag, c='blue', marker='o', s=10)
plt.title("Transmitted (Clean 16QAM)")
plt.grid(True)
plt.xlim(-5, 5)
plt.ylim(-5, 5)
plt.xlabel("In-Phase (I)")
plt.ylabel("Quadrature (Q)")

# Plot 2: Noisy Received Symbols
plt.subplot(1, 2, 2)
plt.scatter(rx_symbols.real, rx_symbols.imag, c='red', marker='.', s=1, alpha=0.5)
plt.title(f"Received (Noisy 16QAM @ {SNR_dB}dB)")
plt.grid(True)
plt.xlim(-5, 5)
plt.ylim(-5, 5)
plt.xlabel("In-Phase (I)")

plt.tight_layout()
plt.show()

print("Simulation Done! Check the plots.")

```

## **i need a more elaborate dataset**

**Optical Fiber** problems like **Chromatic Dispersion (CD)** and **Nonlinearities (Kerr Effect)**. A Neural Network is overkill for just AWGN; you need to add the "messy" physics to justify using AI.

Here is the **Advanced Data Generation Script**. It adds the specific "Optical Physics" equations layer by layer.

### **The Advanced "Optical Channel" Generator**

This script adds three specific effects mentioned in your proposal:

1. **Chromatic Dispersion (CD):** Causes Inter-Symbol Interference (ISI). Modeled as a **FIR Filter**
2. **Kerr Nonlinearity (SPM):** High power signals warp their own phase. Modeled as **Phase Rotation proportional to Power**.
3. **Phase Noise:** Laser instability. Modeled as a **Random Walk**.
## New code

1. **The Spiral Effect (Stage B):** Look at Plot 2. Do you see how the corner points are "twisted" or rotated more than the center points? That is the **Kerr Nonlinearity**. A linear equalizer _cannot_ fix this. Only your Neural Network can. This proves you are solving the specific problem in the PDF.
    
2. **The Smearing (Stage A):** The points are not just noisy; they are "smeared" into their neighbors. This is **ISI/Dispersion**.
    
3. **The Jitter (Stage C):** The entire constellation rotates slightly over time. This mimics **Laser Phase Noise**.

```python 
import numpy as np
import matplotlib.pyplot as plt

# =============================================================================
# 1. PARAMETERS (Specific to Optical Fiber)
# =============================================================================
M = 16              # 16-QAM
num_symbols = 10000 # More symbols to see the statistical effects
SNR_dB = 20         # Higher SNR because Distortion is now the main enemy

# --- Physics Parameters ---
# Chromatic Dispersion (ISI Strength)
# "0.0" means perfect channel. "0.5" is heavy ISI.
CD_strength = 0.3   

# Nonlinearity (Gamma) - The "Kerr Effect"
# "0.0" is linear. High values twist the outer constellation points.
gamma = 0.05        

# Phase Noise (Laser Linewidth)
phase_noise_strength = 0.02 

# =============================================================================
# 2. TRANSMITTER (Clean 16-QAM)
# =============================================================================
points = np.array([-3, -1, 1, 3])
constellation = np.array([r + 1j*i for r in points for i in points])
random_indices = np.random.randint(0, M, num_symbols)
tx_symbols = constellation[random_indices]

# =============================================================================
# 3. OPTICAL CHANNEL SIMULATION (The "Complex Equations")
# =============================================================================

# --- Stage A: Chromatic Dispersion (CD) -> Adds Memory/ISI ---
# In fiber, different colors travel at different speeds, blurring pulses.
# We model this as a Complex FIR Filter (Convolution).
# Filter Tap: [Small, Big (Main), Small] -> Smears energy to neighbors.
cd_impulse_response = np.array([CD_strength * 0.5j,  # Previous symbol effect
                                1.0 + 0j,            # Current symbol (Main)
                                CD_strength * 0.5j]) # Next symbol effect

# Normalize energy so we don't accidentally amplify the signal
cd_impulse_response /= np.sqrt(np.sum(np.abs(cd_impulse_response)**2))

# Apply Convolution (The ISI Equation)
rx_stage1_cd = np.convolve(tx_symbols, cd_impulse_response, mode='same')

# --- Stage B: Fiber Nonlinearity (Self-Phase Modulation - SPM) ---
# Equation: signal * exp(j * gamma * Power)
# High power symbols (corners) rotate more than low power symbols (center).
signal_power_instant = np.abs(rx_stage1_cd)**2
nonlinear_phase_shift = gamma * signal_power_instant
rx_stage2_nonlinear = rx_stage1_cd * np.exp(1j * nonlinear_phase_shift)

# --- Stage C: Laser Phase Noise ---
# Random walk of the phase angle.
random_phase_walk = np.cumsum(np.random.normal(0, phase_noise_strength, num_symbols))
rx_stage3_phased = rx_stage2_nonlinear * np.exp(1j * random_phase_walk)

# --- Stage D: Amplified Spontaneous Emission (AWGN) ---
# Standard noise from optical amplifiers.
signal_power_avg = np.mean(np.abs(tx_symbols)**2)
snr_linear = 10**(SNR_dB / 10.0)
noise_power = signal_power_avg / snr_linear
awgn = np.sqrt(noise_power/2) * (np.random.randn(num_symbols) + 1j * np.random.randn(num_symbols))

rx_final = rx_stage3_phased + awgn

# =============================================================================
# 4. VISUALIZATION (Compare Stages)
# =============================================================================
plt.figure(figsize=(15, 5))

# Plot 1: Clean
plt.subplot(1, 3, 1)
plt.scatter(tx_symbols.real, tx_symbols.imag, c='blue', s=5)
plt.title("1. Clean Transmitted Data")
plt.grid(True); plt.xlim(-5,5); plt.ylim(-5,5)

# Plot 2: After Physics (CD + Nonlinearity)
plt.subplot(1, 3, 2)
plt.scatter(rx_stage2_nonlinear.real, rx_stage2_nonlinear.imag, c='orange', s=5, alpha=0.6)
plt.title("2. After Fiber Physics (CD + Kerr)")
plt.grid(True); plt.xlim(-5,5); plt.ylim(-5,5)
# Notice: The constellation is twisted/spiral (Nonlinearity) and smeared (CD).

# Plot 3: Final Received (Plus Noise)
plt.subplot(1, 3, 3)
plt.scatter(rx_final.real, rx_final.imag, c='red', s=5, alpha=0.5)
plt.title(f"3. Final RX (With Noise & Phase Jitter)")
plt.grid(True); plt.xlim(-5,5); plt.ylim(-5,5)

plt.tight_layout()
plt.show()

print("Data Generation Complete. Use 'rx_final' as input to your Neural Network.")
```