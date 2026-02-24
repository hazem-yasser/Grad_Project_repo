import numpy as np
import os

TXT_DIR = "../sim_data"
HEX_DIR = "../hex_files"
os.makedirs(HEX_DIR, exist_ok=True)

def to_hex_16b(val):
    v = int(np.round(val))
    if v < 0: v = (1 << 16) + v
    return f"{v & 0xFFFF:04X}"

def save_triple_width_hex(filename, weights, inputs, neurons, cycles):
    W = weights.reshape(inputs, neurons).T
    with open(f"{HEX_DIR}/{filename}", 'w') as f:
        for n in range(neurons):
            for i in range(0, cycles * 3, 3):
                group = W[n, i:min(i+3, inputs)] if i < inputs else []
                row_hex = ""
                for val in reversed(group):
                    row_hex += to_hex_16b(val)
                if len(group) < 3:
                    row_hex = ("0000" * (3 - len(group))) + row_hex
                f.write(row_hex + '\n')
    print(f" -> Generated {filename}")

def save_bias(filename, data):
    with open(f"{HEX_DIR}/{filename}", 'w') as f:
        for val in data:
            f.write(to_hex_16b(val) + '\n')
    print(f" -> Generated {filename}")

print("=== RESTRUCTURING FOR 1D-ROM TRIPLE-MAC ===")
save_triple_width_hex("L1_W.hex", np.loadtxt(f"{TXT_DIR}/L1_W.txt"), 10, 32, 4)

L2_W = np.loadtxt(f"{TXT_DIR}/L2_W.txt").reshape(32, 32)
save_triple_width_hex("L2A_W.hex", L2_W[:16, :], 16, 32, 6)
save_triple_width_hex("L2B_W.hex", L2_W[16:, :], 16, 32, 6)

L3_W = np.loadtxt(f"{TXT_DIR}/L3_W.txt").reshape(32, 2)
save_triple_width_hex("L3A_W.hex", L3_W[:16, :], 16, 2, 6)
save_triple_width_hex("L3B_W.hex", L3_W[16:, :], 16, 2, 6)

save_bias("L1_b.hex", np.loadtxt(f"{TXT_DIR}/L1_b.txt"))
save_bias("L2_b.hex", np.loadtxt(f"{TXT_DIR}/L2_b.txt"))
save_bias("L3_b.hex", np.loadtxt(f"{TXT_DIR}/L3_b.txt"))
# =============================================================================
# FIXED STIMULI: Extract Index 2 (I) and Index 7 (Q) from each 10-value block
# =============================================================================
inputs = np.loadtxt(f"{TXT_DIR}/input_stimuli.txt")

# Reshape the 20,000 lines into 2,000 distinct blocks of 10
blocks = inputs.reshape(-1, 10)

# The Golden Model window is: [I-2, I-1, I_target, I+1, I+2, Q-2, Q-1, Q_target, Q+1, Q+2]
# Index 2 is the pure I_target. Index 7 is the pure Q_target.
stream_I = blocks[:, 2]
stream_Q = blocks[:, 7]

# Interleave them for the existing hardware testbench: [I0, Q0, I1, Q1, I2, Q2...]
raw_stream = np.empty((stream_I.size + stream_Q.size,), dtype=stream_I.dtype)
raw_stream[0::2] = stream_I
raw_stream[1::2] = stream_Q

with open(f"{HEX_DIR}/input_stimuli.hex", 'w') as f:
    for val in raw_stream:
        f.write(to_hex_16b(val) + '\n')
        
print(f" -> Generated input_stimuli.hex: Reduced {len(inputs)} lines to {len(raw_stream)} lines!")
