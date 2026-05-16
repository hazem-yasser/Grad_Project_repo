# RTL Verification Makefile
RTL_SRC = rtl/*.sv
# TB_SRC  = tb/tb_neural_eq.sv
# تحديث هذا السطر فقط
TB_SRC  = tb/tb_neural_eq_top.sv
SIM_OUT = sim_data/sim.vvp
VCD_OUT = sim_data/debug.vcd
UNIT_DIR = sim_data/unit

UNIT_TB_INPUT  = tb/tb_input_window_ctrl.sv
UNIT_TB_L1     = tb/tb_layer1_compute.sv
UNIT_TB_L2     = tb/tb_layer2_compute.sv
UNIT_TB_L3     = tb/tb_layer3_compute.sv

all: prep compile sim verify unit wave

prep:
	@echo "==> Restructuring TXT to HEX for Quad-MAC..."
	cd scripts && python3 01_prep_hex.py

compile: prep
	@echo "==> Compiling SystemVerilog..."
	iverilog -g2012 -o $(SIM_OUT) $(TB_SRC) $(RTL_SRC)

sim: compile
	@echo "==> Running Simulation..."
	vvp $(SIM_OUT)

verify:
	@echo "==> Plotting Results..."
	cd scripts && python3 02_verify.py	# do 03_verify.py if you want to plot the stimuli

wave:
	surfer $(VCD_OUT) &

unit: prep unit-input unit-l1 unit-l2 unit-l3
	@echo "All unit tests passed."

unit-input:
	@echo "==> UNIT: input_window_ctrl"
	@mkdir -p $(UNIT_DIR)
	iverilog -g2012 -o $(UNIT_DIR)/tb_input_window_ctrl.vvp $(UNIT_TB_INPUT) rtl/input_window_ctrl.sv
	bash -o pipefail -c 'vvp $(UNIT_DIR)/tb_input_window_ctrl.vvp | tee $(UNIT_DIR)/tb_input_window_ctrl.log'

unit-l1:
	@echo "==> UNIT: layer1_compute"
	@mkdir -p $(UNIT_DIR)
	iverilog -g2012 -o $(UNIT_DIR)/tb_layer1_compute.vvp $(UNIT_TB_L1) rtl/layer1_compute.sv rtl/rom_L1_W.sv rtl/rom_L1_b.sv
	bash -o pipefail -c 'vvp $(UNIT_DIR)/tb_layer1_compute.vvp | tee $(UNIT_DIR)/tb_layer1_compute.log'

unit-l2:
	@echo "==> UNIT: layer2_compute"
	@mkdir -p $(UNIT_DIR)
	iverilog -g2012 -o $(UNIT_DIR)/tb_layer2_compute.vvp $(UNIT_TB_L2) rtl/layer2_compute.sv rtl/rom_L2A_W.sv rtl/rom_L2B_W.sv rtl/rom_L2_b.sv
	bash -o pipefail -c 'vvp $(UNIT_DIR)/tb_layer2_compute.vvp | tee $(UNIT_DIR)/tb_layer2_compute.log'

unit-l3:
	@echo "==> UNIT: layer3_compute"
	@mkdir -p $(UNIT_DIR)
	iverilog -g2012 -o $(UNIT_DIR)/tb_layer3_compute.vvp $(UNIT_TB_L3) rtl/layer3_compute.sv rtl/rom_L3A_W.sv rtl/rom_L3B_W.sv rtl/rom_L3_b.sv
	bash -o pipefail -c 'vvp $(UNIT_DIR)/tb_layer3_compute.vvp | tee $(UNIT_DIR)/tb_layer3_compute.log'

clean-debug:
	@echo "==> Cleaning debug artifacts from sim_data"
	rm -f sim_data/tb_*.vvp sim_data/test_*.vvp sim_data/tb_*.vcd sim_data/*trace*.txt
	rm -f sim_data/test_full.vvp sim_data/test_l3_diag.vvp sim_data/test_simple_l3.vvp
	rm -f sim_data/tb_full.vvp sim_data/tb_full_wire.vvp sim_data/tb_full_final.vvp
	@echo "Debug cleanup complete."

clean:
	rm -rf hex_files/*.hex sim_data/sim.vvp sim_data/dump.vcd sim_data/rtl_output.txt $(UNIT_DIR)
	@echo "Cleanup Complete."
