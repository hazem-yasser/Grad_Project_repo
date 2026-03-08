import numpy as np
import os

TXT_DIR = "../sim_data"       
HEX_DIR = "../hex_files"      
os.makedirs(HEX_DIR, exist_ok=True)

def to_hex_16b(val):
    v = int(np.round(val))
    if v < 0: v = (1 << 16) + v
    return f"{v & 0xFFFF:04X}"

def save_triple_width_hex(filename, weights_flat, num_inputs, num_neurons, num_cycles):
    W = weights_flat.reshape(num_inputs, num_neurons)
    with open(f"{HEX_DIR}/{filename}", 'w') as f:
        for n in range(num_neurons):
            for i in range(0, num_cycles * 3, 3):
                # Grab group of 3 weights [w0, w1, w2]
                group = W[i:min(i+3, num_inputs), n] 
                row_hex = ""
                
                # FIX: DO NOT REVERSE. Write w0, then w1, then w2.
                # Resulting Hex String: [Hex(w0) Hex(w1) Hex(w2)]
                # Verilog [47:32] will be w0.
                for val in group:
                    row_hex += to_hex_16b(val)
                
                # Pad at the END if group < 3 (e.g. w0, w1, 0000)
                if len(group) < 3:
                    row_hex += ("0000" * (3 - len(group)))
                
                f.write(row_hex + '\n')
    print(f" -> Generated {filename}")

def save_bias(filename, data):
    with open(f"{HEX_DIR}/{filename}", 'w') as f:
        for val in data: f.write(to_hex_16b(val) + '\n')
    print(f" -> Generated {filename}")

print("=== 1. PROCESSING WEIGHTS (FIXED ORDERING) ===")
# L1: 10 Inputs -> 4 Cycles
save_triple_width_hex("L1_W.hex", np.loadtxt(f"{TXT_DIR}/L1_W.txt"), 10, 32, 4)

# L2
L2_W_all = np.loadtxt(f"{TXT_DIR}/L2_W.txt").reshape(32, 32)
save_triple_width_hex("L2A_W.hex", L2_W_all[0:16, :].flatten(), 16, 32, 6)
save_triple_width_hex("L2B_W.hex", L2_W_all[16:32, :].flatten(), 16, 32, 6)

# L3
L3_W_all = np.loadtxt(f"{TXT_DIR}/L3_W.txt").reshape(32, 2)
save_triple_width_hex("L3A_W.hex", L3_W_all[0:16, :].flatten(), 16, 2, 6)
save_triple_width_hex("L3B_W.hex", L3_W_all[16:32, :].flatten(), 16, 2, 6)

# Biases
save_bias("L1_b.hex", np.loadtxt(f"{TXT_DIR}/L1_b.txt"))
save_bias("L2_b.hex", np.loadtxt(f"{TXT_DIR}/L2_b.txt"))
save_bias("L3_b.hex", np.loadtxt(f"{TXT_DIR}/L3_b.txt"))

print("=== 2. PROCESSING STIMULI ===")
# Extract Indices 2 & 7
inputs = np.loadtxt(f"{TXT_DIR}/input_stimuli.txt")
blocks = inputs.reshape(-1, 10)
stream_I = blocks[:, 2] 
stream_Q = blocks[:, 7] 

raw_stream = np.empty((stream_I.size + stream_Q.size,), dtype=stream_I.dtype)
raw_stream[0::2] = stream_I
raw_stream[1::2] = stream_Q

with open(f"{HEX_DIR}/input_stimuli.hex", 'w') as f:
    for val in raw_stream: f.write(to_hex_16b(val) + '\n')

print(f" -> Generated input_stimuli.hex: {len(raw_stream)} lines.")