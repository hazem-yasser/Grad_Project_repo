import numpy as np
import matplotlib.pyplot as plt
import os

# =============================================================================
# CONFIGURATION & PARAMETERS
# =============================================================================
FILE_PATHS = {
    'target': 'sim_data/target_voltages.txt',
    'python': 'sim_data/python_bilstm_output.txt',
    'cpp':    'sim_data/output_integers.txt',
    'rtl':    'sim_data/rtl_bilstm_output.txt'
}

# Scale factor for Q1.14 fixed point
SCALE = 16384.0

# 16-QAM Constellation Points
POINTS = np.array([-3, -1, 1, 3])

def load_iq_data(file_path, is_integer=True):
    """Loads I Q pairs from a text file."""
    if not os.path.exists(file_path):
        print(f"Warning: File {file_path} not found.")
        return None
    
    try:
        # Read the file and strip null bytes
        with open(file_path, 'rb') as f:
            content = f.read().replace(b'\x00', b'').decode('utf-8', errors='ignore')
        
        # Filter lines to ensure they have two numeric components
        lines = []
        for line in content.splitlines():
            parts = line.split()
            if len(parts) >= 2:
                try:
                    float(parts[0])
                    float(parts[1])
                    lines.append(parts[:2])
                except ValueError:
                    continue
        
        if not lines:
            return None
            
        data = np.array(lines, dtype=float)
        if is_integer:
            data = data / SCALE
        return data
    except Exception as e:
        print(f"Error loading {file_path}: {e}")
        return None

def demap_16qam(iq_data):
    """Maps I and Q components to the nearest 16-QAM levels (-3, -1, 1, 3)."""
    # Round to nearest odd integer in the range [-3, 3]
    # For values between -inf and -2 -> -3
    # Between -2 and 0 -> -1
    # Between 0 and 2 -> 1
    # Between 2 and inf -> 3
    demapped = np.zeros_like(iq_data)
    demapped[iq_data < -2] = -3
    demapped[(iq_data >= -2) & (iq_data < 0)] = -1
    demapped[(iq_data >= 0) & (iq_data < 2)] = 1
    demapped[iq_data >= 2] = 3
    return demapped

def calculate_metrics(pred, target):
    """Calculates SER, BER, Accuracy, MSE, and EVM."""
    # Ensure they have the same length
    n = min(len(pred), len(target))
    p = pred[:n]
    t = target[:n]
    
    # Demap to get symbols
    p_sym = demap_16qam(p)
    t_sym = demap_16qam(t)
    
    # Symbol Error Rate (SER)
    # A symbol error occurs if either I or Q is wrong
    symbol_errors = np.any(p_sym != t_sym, axis=1)
    ser = np.mean(symbol_errors)
    
    # Accuracy
    accuracy = 1.0 - ser
    
    # Mean Squared Error (MSE)
    mse = np.mean((p - t)**2)
    
    # Error Vector Magnitude (EVM)
    # EVM = sqrt(mean(|p-t|^2) / mean(|t|^2))
    p_complex = p[:, 0] + 1j * p[:, 1]
    t_complex = t[:, 0] + 1j * t[:, 1]
    evm = np.sqrt(np.mean(np.abs(p_complex - t_complex)**2) / np.mean(np.abs(t_complex)**2)) * 100
    
    # Bit Error Rate (BER) - Simplistic estimation for 16-QAM (4 bits/symbol)
    # Mapping levels to bits (Gray coding)
    def level_to_bits(val):
        # -3 -> 00, -1 -> 01, 1 -> 11, 3 -> 10 (Gray mapping for levels)
        mapping = {-3: [0,0], -1: [0,1], 1: [1,1], 3: [1,0]}
        # Apply to each value
        bits = []
        for v in val.flatten():
            bits.extend(mapping.get(int(v), [0,0]))
        return np.array(bits)

    p_bits = level_to_bits(p_sym)
    t_bits = level_to_bits(t_sym)
    ber = np.mean(p_bits != t_bits)
    
    return {
        'SER': ser,
        'BER': ber,
        'Accuracy': accuracy,
        'MSE': mse,
        'EVM': evm,
        'Count': n
    }

def main():
    print("Loading data files...")
    # Change CWD to script directory to find sim_data
    os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    
    target_data = load_iq_data(FILE_PATHS['target'], is_integer=False)
    python_data = load_iq_data(FILE_PATHS['python'], is_integer=True)
    cpp_data    = load_iq_data(FILE_PATHS['cpp'],    is_integer=True)
    rtl_data    = load_iq_data(FILE_PATHS['rtl'],    is_integer=True)
    
    if target_data is None:
        print("Error: Target data is missing. Cannot continue.")
        return

    sources = []
    if python_data is not None: sources.append(('Python', python_data))
    if cpp_data is not None:    sources.append(('C++', cpp_data))
    if rtl_data is not None:    sources.append(('RTL', rtl_data))
    
    results = {}
    for name, data in sources:
        results[name] = calculate_metrics(data, target_data)
        print(f"Metrics for {name} ({results[name]['Count']} symbols):")
        print(f"  SER: {results[name]['SER']:.5f}")
        print(f"  BER: {results[name]['BER']:.6f}")
        print(f"  Acc: {results[name]['Accuracy']:.4%}")
        print(f"  MSE: {results[name]['MSE']:.5f}")
        print(f"  EVM: {results[name]['EVM']:.2f}%")

    # =========================================================================
    # PLOTTING
    # =========================================================================
    if not results:
        print("No results to plot.")
        return

    labels = list(results.keys())
    metrics_to_plot = ['SER', 'BER', 'Accuracy', 'MSE', 'EVM']
    colors = ['#1f77b4', '#ff7f0e', '#2ca02c']
    
    fig, axs = plt.subplots(1, 5, figsize=(18, 5))
    fig.suptitle('BiLSTM+CNN — Implementation Comparison', fontsize=14, fontweight='bold')
    
    for i, m in enumerate(metrics_to_plot):
        vals = [results[lbl][m] for lbl in labels]
        axs[i].bar(labels, vals, color=colors[:len(labels)], alpha=0.8)
        axs[i].set_title(m)
        if m in ['SER', 'BER', 'MSE'] and any(v > 0 for v in vals):
            axs[i].set_yscale('log')
        # Add labels on top
        for j, v in enumerate(vals):
            fmt = ".4f" if m != 'Accuracy' else ".2%"
            axs[i].text(j, v, f"{v:{fmt}}", ha='center', va='bottom', fontsize=8)

    plt.tight_layout(rect=[0, 0.03, 1, 0.95])
    plt.savefig('all_metrics_comparison.png')
    print("Saved: all_metrics_comparison.png")

    # Trace comparison (First 100 symbols)
    n_trace = min(100, target_data.shape[0])
    fig, (ax_i, ax_q) = plt.subplots(2, 1, figsize=(14, 8), sharex=True)
    fig.suptitle('Output Trace Comparison (First 100 Symbols)', fontsize=14)
    
    t = np.arange(n_trace)
    ax_i.step(t, target_data[:n_trace, 0], 'k-', label='Target', where='mid', alpha=0.5)
    ax_q.step(t, target_data[:n_trace, 1], 'k-', label='Target', where='mid', alpha=0.5)
    
    lstyles = ['--', ':', '-.']
    for idx, (name, data) in enumerate(sources):
        ax_i.plot(t, data[:n_trace, 0], label=name, ls=lstyles[idx % 3])
        ax_q.plot(t, data[:n_trace, 1], label=name, ls=lstyles[idx % 3])
        
    ax_i.set_ylabel('I Component')
    ax_q.set_ylabel('Q Component')
    ax_q.set_xlabel('Symbol Index')
    ax_i.legend()
    ax_i.grid(True, alpha=0.3)
    ax_q.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('output_trace_comparison.png')
    print("Saved: output_trace_comparison.png")

    # Scatter Plot (Constellation)
    fig, axes = plt.subplots(1, len(sources) + 1, figsize=(4 * (len(sources) + 1), 4), sharex=True, sharey=True)
    fig.suptitle('Constellation Diagrams', fontsize=14)
    
    axes[0].scatter(target_data[:, 0], target_data[:, 1], s=10, alpha=0.5, c='black')
    axes[0].set_title('Target')
    axes[0].grid(True, alpha=0.3)
    
    for i, (name, data) in enumerate(sources):
        axes[i+1].scatter(data[:, 0], data[:, 1], s=5, alpha=0.3, c=colors[i])
        axes[i+1].set_title(name)
        axes[i+1].grid(True, alpha=0.3)
        
    for ax in axes:
        ax.set_aspect('equal')
        ax.set_xlim([-5, 5])
        ax.set_ylim([-5, 5])

    plt.tight_layout()
    plt.savefig('constellation_comparison.png')
    print("Saved: constellation_comparison.png")
    
    # plt.show() # Uncomment if running in interactive env

if __name__ == "__main__":
    main()
