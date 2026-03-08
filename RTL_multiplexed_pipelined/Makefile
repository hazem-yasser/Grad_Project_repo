# RTL Verification Makefile
RTL_SRC = rtl/*.sv
# TB_SRC  = tb/tb_neural_eq.sv
# تحديث هذا السطر فقط
TB_SRC  = tb/tb_neural_eq_top.sv
SIM_OUT = sim_data/sim.vvp
VCD_OUT = sim_data/debug.vcd

all: prep compile sim verify wave

prep:
	@echo "==> Restructuring TXT to HEX for Quad-MAC..."
	cd scripts && python3 01_prep_hex.py

compile:
	@echo "==> Compiling SystemVerilog..."
	iverilog -g2012 -o $(SIM_OUT) $(TB_SRC) $(RTL_SRC)

sim: compile
	@echo "==> Running Simulation..."
	vvp $(SIM_OUT)

verify:
	@echo "==> Plotting Results..."
	cd scripts && python3 02_verify.py

wave:
	surfer $(VCD_OUT) &

clean:
	rm -rf hex_files/*.hex sim_data/sim.vvp sim_data/dump.vcd sim_data/rtl_output.txt
	@echo "Cleanup Complete."
