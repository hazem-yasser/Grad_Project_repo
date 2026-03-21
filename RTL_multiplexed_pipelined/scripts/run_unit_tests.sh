#!/bin/bash

# Unit Test Runner for RTL Modules
# Tests each module independently before integration

VERILOG_FLAGS="-g2012"
SIM_DIR="../sim_data"
TB_DIR="../tb"

echo "======= NEURAL NETWORK RTL MODULE UNIT TEST SUITE ======="
echo ""

# Test 1: Input Window Control Module
echo "[1/4] Testing input_window_ctrl..."
cd $TB_DIR
iverilog $VERILOG_FLAGS -o $SIM_DIR/test_input_window.vvp tb_input_window_ctrl.sv ../rtl/input_window_ctrl.sv
if [ $? -eq 0 ]; then
    vvp $SIM_DIR/test_input_window.vvp > $SIM_DIR/test_input_window.log
    echo "      ✓ INPUT_WINDOW_CTRL passed"
else
    echo "      ✗ INPUT_WINDOW_CTRL compilation failed"
fi

# Test 2: Layer1 Compute Module
echo "[2/4] Testing layer1_compute..."
iverilog $VERILOG_FLAGS -o $SIM_DIR/test_layer1.vvp tb_layer1_compute.sv ../rtl/layer1_compute.sv ../rtl/input_window_ctrl.sv
if [ $? -eq 0 ]; then
    vvp $SIM_DIR/test_layer1.vvp > $SIM_DIR/test_layer1.log
    if grep -q "ERROR" $SIM_DIR/test_layer1.log; then
        echo "      ✗ LAYER1_COMPUTE had runtime errors"
    else
        echo "      ✓ LAYER1_COMPUTE passed"
    fi
else
    echo "      ✗ LAYER1_COMPUTE compilation failed"
fi

# Test 3: Layer2 Compute Module  
echo "[3/4] Testing layer2_compute..."
iverilog $VERILOG_FLAGS -o $SIM_DIR/test_layer2.vvp tb_layer2_compute.sv ../rtl/layer2_compute.sv
if [ $? -eq 0 ]; then
    vvp $SIM_DIR/test_layer2.vvp > $SIM_DIR/test_layer2.log
    if grep -q "ERROR" $SIM_DIR/test_layer2.log; then
        echo "      ✗ LAYER2_COMPUTE had runtime errors"
    else
        echo "      ✓ LAYER2_COMPUTE passed"
    fi
else
    echo "      ✗ LAYER2_COMPUTE compilation failed"
fi

# Test 4: Layer3 Compute Module
echo "[4/4] Testing layer3_compute..."
iverilog $VERILOG_FLAGS -o $SIM_DIR/test_layer3.vvp tb_layer3_compute.sv ../rtl/layer3_compute.sv
if [ $? -eq 0 ]; then
    vvp $SIM_DIR/test_layer3.vvp > $SIM_DIR/test_layer3.log 2>&1
    if grep -q "ERROR" $SIM_DIR/test_layer3.log; then
        echo "      ✗ LAYER3_COMPUTE had runtime errors"
        echo "      ---"
        tail -n 20 $SIM_DIR/test_layer3.log
    else
        echo "      ✓ LAYER3_COMPUTE passed"
    fi
else
    echo "      ✗ LAYER3_COMPUTE compilation failed"
fi

echo ""
echo "======= SUMMARY ======="
echo " See sim_data/test_*.log for detailed output"
echo ""
