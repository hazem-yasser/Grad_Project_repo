#!/usr/bin/env python3
"""
Verify RTL output against C++ golden model output for BiLSTM-CNN equalizer.
Compares sim_data/rtl_bilstm_output.txt vs sim_data/weights_bilstm/output_integers.txt
"""
import numpy as np
import os, sys

def read_iq_pairs(path):
    """Read file with 'I Q' pairs, one per line."""
    pairs = []
    with open(path) as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) >= 2:
                pairs.append((int(parts[0]), int(parts[1])))
    return pairs

def main():
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    
    rtl_path = os.path.join(base, 'sim_data', 'rtl_bilstm_output.txt')
    golden_path = os.path.join(base, 'sim_data', 'weights_bilstm', 'output_integers.txt')
    
    if not os.path.exists(rtl_path):
        print(f"[ERR] RTL output not found: {rtl_path}")
        sys.exit(1)
    if not os.path.exists(golden_path):
        print(f"[ERR] Golden output not found: {golden_path}")
        sys.exit(1)

    rtl    = read_iq_pairs(rtl_path)
    golden = read_iq_pairs(golden_path)

    print("=" * 60)
    print("  BiLSTM-CNN Equalizer: RTL vs Golden Model Comparison")
    print("=" * 60)
    print(f"  RTL outputs   : {len(rtl)} pairs")
    print(f"  Golden outputs: {len(golden)} pairs")

    n = min(len(rtl), len(golden))
    if n == 0:
        print("[ERR] No data to compare!")
        sys.exit(1)

    # Compare
    exact_match = 0
    within_1    = 0
    within_5    = 0
    max_err_I   = 0
    max_err_Q   = 0
    sum_err_I   = 0
    sum_err_Q   = 0
    
    mismatches = []
    
    for i in range(n):
        ei = abs(rtl[i][0] - golden[i][0])
        eq = abs(rtl[i][1] - golden[i][1])
        
        max_err_I = max(max_err_I, ei)
        max_err_Q = max(max_err_Q, eq)
        sum_err_I += ei
        sum_err_Q += eq

        if ei == 0 and eq == 0:
            exact_match += 1
        if ei <= 1 and eq <= 1:
            within_1 += 1
        if ei <= 5 and eq <= 5:
            within_5 += 1
        
        if ei > 5 or eq > 5:
            if len(mismatches) < 20:
                mismatches.append((i, rtl[i], golden[i], ei, eq))

    avg_err_I = sum_err_I / n
    avg_err_Q = sum_err_Q / n

    print(f"\n  Compared      : {n} pairs")
    print(f"  Exact matches : {exact_match}/{n} ({100*exact_match/n:.1f}%)")
    print(f"  Within ±1     : {within_1}/{n} ({100*within_1/n:.1f}%)")
    print(f"  Within ±5     : {within_5}/{n} ({100*within_5/n:.1f}%)")
    print(f"  Max error I   : {max_err_I}")
    print(f"  Max error Q   : {max_err_Q}")
    print(f"  Avg error I   : {avg_err_I:.2f}")
    print(f"  Avg error Q   : {avg_err_Q:.2f}")

    if mismatches:
        print(f"\n  First {len(mismatches)} large mismatches (>5):")
        print(f"  {'Idx':>6}  {'RTL_I':>8} {'RTL_Q':>8}  {'GOL_I':>8} {'GOL_Q':>8}  {'ErrI':>5} {'ErrQ':>5}")
        for idx, rv, gv, ei, eq in mismatches:
            print(f"  {idx:6d}  {rv[0]:8d} {rv[1]:8d}  {gv[0]:8d} {gv[1]:8d}  {ei:5d} {eq:5d}")

    # Verdict
    print()
    if exact_match == n:
        print("  ✓ PERFECT MATCH — RTL is bit-exact with golden model!")
    elif within_1 / n > 0.99:
        print("  ✓ NEAR-PERFECT — >99% within ±1 (rounding differences expected)")
    elif within_5 / n > 0.95:
        print("  ~ ACCEPTABLE — >95% within ±5 (minor quantization differences)")
    else:
        print("  ✗ SIGNIFICANT DIFFERENCES — debug needed")
    print("=" * 60)

if __name__ == '__main__':
    main()
