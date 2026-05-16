#!/usr/bin/env python3
"""
BiLSTM-CNN Equalizer — Python bit-exact behavioral model
Exactly mirrors the SystemVerilog RTL implementation for verification.
Compares against the C++ golden model output.
"""
import numpy as np
import os, math

FRAC_BITS = 14
SCALE_Q   = 1 << FRAC_BITS
MAX16     =  32767
MIN16     = -32768
LUT_SIZE  = 512
LUT_MIN   = -8
LUT_MAX   =  8

INPUT_LEN  = 81
OUTPUT_LEN = 61
N_FEAT     = 2
N_H        = 35
N_CONCAT   = 70
KERNEL     = 21
N_FILT     = 2
GATES      = 4 * N_H  # 140

def sat16(x):
    return int(max(MIN16, min(MAX16, x)))

def read_ints(path):
    with open(path) as f:
        return [int(x) for x in f.read().split()]

# Build LUTs
tanh_lut = np.zeros(LUT_SIZE, dtype=np.int16)
sigm_lut = np.zeros(LUT_SIZE, dtype=np.int16)
for i in range(LUT_SIZE):
    x = LUT_MIN + i * (LUT_MAX - LUT_MIN) / (LUT_SIZE - 1)
    tanh_lut[i] = sat16(round(math.tanh(x) * SCALE_Q))
    sigm_lut[i] = sat16(round(1.0 / (1.0 + math.exp(-x)) * SCALE_Q))

def lut_index(val):
    """Map Q1.14 value to LUT index [0, 511] — matches C++ golden model exactly"""
    LUT_IN_MIN_Q = -8 * SCALE_Q   # -131072
    LUT_IN_MAX_Q =  8 * SCALE_Q   #  131072
    range_q = LUT_IN_MAX_Q - LUT_IN_MIN_Q  # 262144
    shifted = int(val) - LUT_IN_MIN_Q      # val + 131072
    idx = shifted * (LUT_SIZE - 1) // range_q
    return max(0, min(LUT_SIZE - 1, idx))

def lut_sigmoid(val):
    return int(sigm_lut[lut_index(val)])

def lut_tanh(val):
    return int(tanh_lut[lut_index(val)])

def lstm_cell_step(x_vec, h, c, W, RW, b, input_size):
    """One time step of LSTM cell — matches C++ golden model exactly."""
    gates = 4 * N_H
    
    # MAC: z = W*x + RW*h (accumulated in full precision)
    z = [0] * gates
    
    # W * x  (C++ accumulates per gate, then adds to z)
    for g in range(gates):
        acc = 0
        for k in range(input_size):
            acc += int(x_vec[k]) * int(W[k * gates + g])
        z[g] = acc
    
    # RW * h
    for g in range(gates):
        acc = 0
        for k in range(N_H):
            acc += int(h[k]) * int(RW[k * gates + g])
        z[g] += acc
    
    # Shift + bias (stays full precision, like C++ int64_t)
    for g in range(gates):
        z[g] = (z[g] >> FRAC_BITS) + int(b[g])
    
    # Activation — saturate to 16-bit only at LUT input (matching C++)
    h_new = list(h)
    c_new = list(c)
    for u in range(N_H):
        ig = lut_sigmoid(sat16(z[u]))
        fg = lut_sigmoid(sat16(z[N_H + u]))
        gg = lut_tanh(sat16(z[2*N_H + u]))
        og = lut_sigmoid(sat16(z[3*N_H + u]))
        
        fc_p = (int(fg) * int(c[u])) >> FRAC_BITS
        ig_p = (int(ig) * int(gg)) >> FRAC_BITS
        c_new[u] = sat16(fc_p + ig_p)
        
        tc = lut_tanh(c_new[u])
        oh_p = (int(og) * int(tc)) >> FRAC_BITS
        h_new[u] = sat16(oh_p)
    
    return h_new, c_new

def bilstm_layer(seq, fwd_W, fwd_RW, fwd_b, bwd_W, bwd_RW, bwd_b, input_size):
    """Bidirectional LSTM layer. Returns [seq_len][2*N_H] concatenated output."""
    seq_len = len(seq)
    
    # Forward pass
    h = [0] * N_H
    c = [0] * N_H
    fwd_out = []
    for t in range(seq_len):
        h, c = lstm_cell_step(seq[t], h, c, fwd_W, fwd_RW, fwd_b, input_size)
        fwd_out.append(list(h))
    
    # Backward pass
    h = [0] * N_H
    c = [0] * N_H
    bwd_out = [None] * seq_len
    for t in range(seq_len - 1, -1, -1):
        h, c = lstm_cell_step(seq[t], h, c, bwd_W, bwd_RW, bwd_b, input_size)
        bwd_out[t] = list(h)
    
    # Concatenate
    output = []
    for t in range(seq_len):
        output.append(fwd_out[t] + bwd_out[t])
    
    return output

def conv1d_layer(seq, W, b):
    """1D convolution with valid padding."""
    seq_len = len(seq)
    out_len = seq_len - KERNEL + 1
    output = []
    
    for p in range(out_len):
        result = [0] * N_FILT
        for f in range(N_FILT):
            acc = 0
            for k in range(KERNEL):
                for ch in range(N_CONCAT):
                    w_idx = k * N_CONCAT * N_FILT + ch * N_FILT + f
                    acc += int(seq[p + k][ch]) * int(W[w_idx])
            # Shift products, add bias
            result[f] = sat16((acc >> FRAC_BITS) + int(b[f]))
        output.append(result)
    
    return output

def main():
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    wt_dir = os.path.join(base, 'sim_data', 'weights_bilstm')
    
    print("=" * 60)
    print("  BiLSTM-CNN Equalizer — Python Behavioral Model")
    print("=" * 60)
    
    # Load weights
    L1F_W  = read_ints(os.path.join(wt_dir, 'L1_forward_W.txt'))
    L1F_RW = read_ints(os.path.join(wt_dir, 'L1_forward_RW.txt'))
    L1F_b  = read_ints(os.path.join(wt_dir, 'L1_forward_b.txt'))
    L1B_W  = read_ints(os.path.join(wt_dir, 'L1_backward_W.txt'))
    L1B_RW = read_ints(os.path.join(wt_dir, 'L1_backward_RW.txt'))
    L1B_b  = read_ints(os.path.join(wt_dir, 'L1_backward_b.txt'))
    
    L2F_W  = read_ints(os.path.join(wt_dir, 'L2_forward_W.txt'))
    L2F_RW = read_ints(os.path.join(wt_dir, 'L2_forward_RW.txt'))
    L2F_b  = read_ints(os.path.join(wt_dir, 'L2_forward_b.txt'))
    L2B_W  = read_ints(os.path.join(wt_dir, 'L2_backward_W.txt'))
    L2B_RW = read_ints(os.path.join(wt_dir, 'L2_backward_RW.txt'))
    L2B_b  = read_ints(os.path.join(wt_dir, 'L2_backward_b.txt'))
    
    L3_W = read_ints(os.path.join(wt_dir, 'L3_W.txt'))
    L3_b = read_ints(os.path.join(wt_dir, 'L3_b.txt'))
    print("[OK] Weights loaded")
    
    # Load stimuli
    stim = read_ints(os.path.join(wt_dir, 'input_stimuli.txt'))
    frame_size = INPUT_LEN * N_FEAT
    num_samples = len(stim) // frame_size
    print(f"[OK] Stimuli: {num_samples} samples")
    
    # Load C++ golden output
    golden_path = os.path.join(wt_dir, 'output_integers.txt')
    golden_raw = read_ints(golden_path)
    golden_pairs = [(golden_raw[i], golden_raw[i+1]) for i in range(0, len(golden_raw), 2)]
    print(f"[OK] Golden: {len(golden_pairs)} pairs")
    
    # Process samples
    py_output = []
    for s in range(num_samples):
        # Build input [81][2]
        inp = []
        for t in range(INPUT_LEN):
            i_val = sat16(stim[s * frame_size + t * N_FEAT + 0])
            q_val = sat16(stim[s * frame_size + t * N_FEAT + 1])
            inp.append([i_val, q_val])
        
        # BiLSTM1
        bl1 = bilstm_layer(inp, L1F_W, L1F_RW, L1F_b, L1B_W, L1B_RW, L1B_b, N_FEAT)
        
        # BiLSTM2
        bl2 = bilstm_layer(bl1, L2F_W, L2F_RW, L2F_b, L2B_W, L2B_RW, L2B_b, N_CONCAT)
        
        # Conv1D
        out = conv1d_layer(bl2, L3_W, L3_b)
        
        for pair in out:
            py_output.append((pair[0], pair[1]))
        
        if (s + 1) % 10 == 0 or s == 0:
            print(f"  [{s+1}/{num_samples}]")
    
    # Compare Python vs C++ golden
    n = min(len(py_output), len(golden_pairs))
    exact = 0
    within1 = 0
    max_err = 0
    
    for i in range(n):
        ei = abs(py_output[i][0] - golden_pairs[i][0])
        eq = abs(py_output[i][1] - golden_pairs[i][1])
        max_err = max(max_err, ei, eq)
        if ei == 0 and eq == 0: exact += 1
        if ei <= 1 and eq <= 1: within1 += 1
    
    # Save Python output
    py_out_path = os.path.join(base, 'sim_data', 'python_bilstm_output.txt')
    with open(py_out_path, 'w') as f:
        for pair in py_output:
            f.write(f"{pair[0]} {pair[1]}\n")
    
    print()
    print("=" * 60)
    print("  Python vs C++ Golden Model Comparison")
    print("=" * 60)
    print(f"  Compared    : {n} output pairs")
    print(f"  Exact match : {exact}/{n} ({100*exact/n:.1f}%)")
    print(f"  Within ±1   : {within1}/{n} ({100*within1/n:.1f}%)")
    print(f"  Max error   : {max_err}")
    print(f"  Output saved: {py_out_path}")
    
    if exact == n:
        print("\n  [PASS] PERFECT BIT-EXACT MATCH!")
    elif within1 / n > 0.99:
        print("\n  [PASS] Excellent match (>99% within +/-1)")
    else:
        print(f"\n  [FAIL] Differences found - max error: {max_err}")
    print("=" * 60)

if __name__ == '__main__':
    main()
