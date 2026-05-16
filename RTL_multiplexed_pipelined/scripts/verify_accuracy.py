import os
import sys

def read_iq_pairs(path):
    pairs = []
    if not os.path.exists(path):
        return []
    with open(path) as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) >= 2:
                pairs.append((int(parts[0]), int(parts[1])))
            elif len(parts) == 1:
                # Handle single column files if needed, but we expect IQ pairs
                pass
    return pairs

def read_targets(path):
    if not os.path.exists(path):
        return []
    with open(path) as f:
        vals = [int(line.strip()) for line in f if line.strip()]
    # Group into pairs
    pairs = []
    for i in range(0, len(vals), 2):
        if i+1 < len(vals):
            pairs.append((vals[i], vals[i+1]))
    return pairs

def slice_pam4(val):
    # PAM-4 levels: -9830, -3277, 3277, 9830
    # Thresholds: -6554, 0, 6554
    if val > 6554: return 9830
    if val > 0:    return 3277
    if val > -6554: return -3277
    return -9830

def calculate_ser(actual, target):
    if not actual or not target: return 0.0, 0
    n = min(len(actual), len(target))
    errors = 0
    for i in range(n):
        # Sliced comparison
        s_i_act = slice_pam4(actual[i][0])
        s_q_act = slice_pam4(actual[i][1])
        s_i_tar = slice_pam4(target[i][0])
        s_q_tar = slice_pam4(target[i][1])
        
        if s_i_act != s_i_tar or s_q_act != s_q_tar:
            errors += 1
    return (errors / n) * 100, n

def main():
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    
    python_out = read_iq_pairs(os.path.join(base, 'sim_data', 'python_bilstm_output.txt'))
    rtl_out    = read_iq_pairs(os.path.join(base, 'sim_data', 'rtl_bilstm_output.txt'))
    targets    = read_targets(os.path.join(base, 'sim_data', 'weights_bilstm', 'target_voltages.txt'))
    golden     = read_iq_pairs(os.path.join(base, 'sim_data', 'weights_bilstm', 'output_integers.txt'))

    print("=" * 60)
    print("  BiLSTM-CNN Equalizer: Accuracy & Performance Analysis")
    print("=" * 60)

    if golden:
        ser_gold, n_gold = calculate_ser(golden, targets)
        print(f"  Golden Model SER: {ser_gold:6.2f}%  (Reference)")

    if python_out:
        ser_py, n_py = calculate_ser(python_out, targets)
        print(f"  Python Model SER: {ser_py:6.2f}%")
        
        # Bit-exactness check vs Golden
        matches = 0
        n_cmp = min(len(python_out), len(golden))
        for i in range(n_cmp):
            if python_out[i] == golden[i]: matches += 1
        print(f"  Python vs Gold:   {100*matches/n_cmp if n_cmp>0 else 0:6.2f}% bit-exact")

    if rtl_out:
        ser_rtl, n_rtl = calculate_ser(rtl_out, targets)
        print(f"  RTL Model SER:    {ser_rtl:6.2f}%")
        
        # Bit-exactness check vs Python
        matches = 0
        n_cmp = min(len(rtl_out), len(python_out))
        for i in range(n_cmp):
            if rtl_out[i] == python_out[i]: matches += 1
        print(f"  RTL vs Python:    {100*matches/n_cmp if n_cmp>0 else 0:6.2f}% bit-exact")

    print("=" * 60)

if __name__ == "__main__":
    main()
