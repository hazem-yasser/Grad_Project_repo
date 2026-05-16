#!/usr/bin/env python3
"""
Generate hex files for BiLSTM-CNN Equalizer RTL simulation.
Converts decimal weight text files to hex and generates tanh/sigmoid LUT hex files.
"""
import numpy as np
import os, math

FRAC_BITS = 14
SCALE_Q   = 1 << FRAC_BITS
LUT_SIZE  = 512
LUT_MIN   = -8
LUT_MAX   =  8

def sat16(x):
    return int(max(-32768, min(32767, x)))

def to_hex16(val):
    """Convert signed 16-bit integer to 4-digit hex string."""
    v = val & 0xFFFF
    return f"{v:04X}"

def read_ints(path):
    with open(path) as f:
        return [int(x) for x in f.read().split()]

def write_hex(path, vals):
    with open(path, 'w') as f:
        for v in vals:
            f.write(to_hex16(sat16(v)) + '\n')

def gen_luts(out_dir):
    """Generate sigmoid and tanh LUT hex files (512 entries each)."""
    tanh_vals = []
    sigm_vals = []
    for i in range(LUT_SIZE):
        x = LUT_MIN + i * (LUT_MAX - LUT_MIN) / (LUT_SIZE - 1)
        tanh_vals.append(sat16(round(math.tanh(x) * SCALE_Q)))
        sigm_vals.append(sat16(round(1.0 / (1.0 + math.exp(-x)) * SCALE_Q)))
    write_hex(os.path.join(out_dir, 'tanh_lut.hex'), tanh_vals)
    write_hex(os.path.join(out_dir, 'sigmoid_lut.hex'), sigm_vals)
    print(f"  LUTs: tanh_lut.hex ({LUT_SIZE}), sigmoid_lut.hex ({LUT_SIZE})")

def convert_weight_file(src_path, dst_path):
    vals = read_ints(src_path)
    write_hex(dst_path, vals)
    print(f"  {os.path.basename(dst_path)}: {len(vals)} entries")

def convert_stimuli(src_path, dst_path):
    vals = read_ints(src_path)
    write_hex(dst_path, vals)
    print(f"  {os.path.basename(dst_path)}: {len(vals)} entries")

def main():
    base    = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    wt_dir  = os.path.join(base, 'sim_data', 'weights_bilstm')
    hex_dir = os.path.join(base, 'hex_files_bilstm')
    os.makedirs(hex_dir, exist_ok=True)

    print("=== Generating BiLSTM-CNN Hex Files ===")
    print(f"Source: {wt_dir}")
    print(f"Output: {hex_dir}")

    # Weight files to convert
    weight_files = [
        'L1_forward_W', 'L1_forward_RW', 'L1_forward_b',
        'L1_backward_W', 'L1_backward_RW', 'L1_backward_b',
        'L2_forward_W', 'L2_forward_RW', 'L2_forward_b',
        'L2_backward_W', 'L2_backward_RW', 'L2_backward_b',
        'L3_W', 'L3_b',
    ]

    print("\n--- Weight Files ---")
    for wf in weight_files:
        convert_weight_file(
            os.path.join(wt_dir, wf + '.txt'),
            os.path.join(hex_dir, wf + '.hex')
        )

    print("\n--- Activation LUTs ---")
    gen_luts(hex_dir)

    print("\n--- Stimuli ---")
    convert_stimuli(
        os.path.join(wt_dir, 'input_stimuli.txt'),
        os.path.join(hex_dir, 'input_stimuli.hex')
    )

    # Also convert expected outputs if available
    exp_path = os.path.join(wt_dir, 'expected_outputs.txt')
    if os.path.exists(exp_path):
        convert_stimuli(exp_path, os.path.join(hex_dir, 'expected_outputs.hex'))

    print("\n=== Done ===")

if __name__ == '__main__':
    main()
