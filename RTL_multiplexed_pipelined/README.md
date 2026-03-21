# RTL Multiplexed Pipelined Neural Equalizer

This repository contains a pipelined RTL implementation of a neural equalizer with:
- Input window generation
- Layer 1 compute
- Layer 2 compute
- Layer 3 compute
- Top-level integration and full-flow verification

## Project Structure

- `rtl/`: synthesizable RTL modules
- `tb/`: unit and top-level testbenches
- `scripts/`: data preparation and verification scripts
- `hex_files/`: generated fixed-point `.hex` memories
- `sim_data/`: simulation artifacts, logs, and outputs

## Verification Flow

Use the following Make targets.

| Command | Purpose | Main Output |
|---|---|---|
| `make prep` | Generate `.hex` weights/biases/stimuli | `hex_files/*.hex` |
| `make compile` | Compile top-level simulation | `sim_data/sim.vvp` |
| `make sim` | Run top-level simulation | `sim_data/rtl_output.txt`, `sim_data/debug.vcd` |
| `make verify` | Compare RTL output vs target and plot | verification plot/log from `scripts/02_verify.py` |
| `make unit` | Run all unit testbenches (self-checking) | `sim_data/unit/*.log` |
| `make unit-input` | Run input window unit test | `sim_data/unit/tb_input_window_ctrl.log` |
| `make unit-l1` | Run layer 1 unit test | `sim_data/unit/tb_layer1_compute.log` |
| `make unit-l2` | Run layer 2 unit test | `sim_data/unit/tb_layer2_compute.log` |
| `make unit-l3` | Run layer 3 unit test | `sim_data/unit/tb_layer3_compute.log` |
| `make clean-debug` | Remove temporary debug artifacts | cleaned `sim_data/` debug files |
| `make clean` | Remove generated simulation + hex outputs | cleaned build/generated outputs |

## What Each Testbench Verifies

### Unit Testbenches

- `tb/tb_input_window_ctrl.sv`
  - Reset initialization of window buffers
  - Valid pulse behavior during warmup and streaming
  - Timeout flush behavior when input is idle

- `tb/tb_layer1_compute.sv`
  - Handshake behavior (one output event per transaction)
  - Output validity (no unknown/X values)
  - Activation property (ReLU: no negative outputs)

- `tb/tb_layer2_compute.sv`
  - Pipeline transaction timing
  - Output validity (no unknown/X values)
  - Activation property (ReLU: no negative outputs)

- `tb/tb_layer3_compute.sv`
  - Pipeline transaction timing
  - Output validity (no unknown/X values)
  - Sensitivity to changing input vectors

### Top-Level Testbench

- `tb/tb_neural_eq_top.sv`
  - Full dataflow and throughput through all stages
  - Produces `sim_data/rtl_output.txt` for numerical comparison in `make verify`

## Typical Usage

```bash
make unit
make sim
make verify
```

For quick cleanup of temporary debug files:

```bash
make clean-debug
```
