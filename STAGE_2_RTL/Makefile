# Compiler
IVERILOG = iverilog
VVP      = vvp
PYTHON   = python3

# Flags: Enable SystemVerilog 2012 standard
FLAGS    = -g2012 

# Files
RTL_SRC  = rtl/Neuron.sv rtl/Neural_Network.sv
TB_SRC   = tb/tb_neural_net.sv
OUT_BIN  = eq_sim.out
OUT_TXT  = rtl_output.txt

# Targets
.PHONY: all compile run verify clean

all: compile run verify

# 1. Compile Verilog to Executable
compile:
	@echo "[MAKE] Compiling SystemVerilog..."
	$(IVERILOG) $(FLAGS) -o $(OUT_BIN) $(RTL_SRC) $(TB_SRC)

# 2. Run Simulation
run:
	@echo "[MAKE] Running Simulation..."
	$(VVP) $(OUT_BIN)

# 3. Verify with Python
verify:
	@echo "[MAKE] Verifying Results..."
	$(PYTHON) scripts/verify_output.py

# Clean Up
clean:
	rm -f $(OUT_BIN) $(OUT_TXT) rtl_verification.png`