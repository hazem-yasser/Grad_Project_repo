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

# FIXED: Removed the * 5.0 to prevent 16-bit integer overflow wrap-around
inputs = np.loadtxt(f"{TXT_DIR}/input_stimuli.txt")
with open(f"{HEX_DIR}/input_stimuli.hex", 'w') as f:
    for val in inputs:
        f.write(to_hex_16b(val) + '\n')
print(" -> Generated input_stimuli.hex (16-bit Q1.14)")
