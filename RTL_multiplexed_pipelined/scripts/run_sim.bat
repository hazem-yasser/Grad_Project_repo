@echo off
REM ============================================================================
REM  BiLSTM-CNN Equalizer RTL Simulation Script
REM  Usage: run_sim.bat [questa|iverilog] [num_samples]
REM ============================================================================

set SIM=%1
if "%SIM%"=="" set SIM=questa



set ROOT=%~dp0..
set RTL_DIR=%ROOT%\rtl_bilstm
set TB_DIR=%ROOT%\tb
set HEX_DIR=%ROOT%\hex_files_bilstm
set WORK_DIR=%ROOT%\work_bilstm

if not "%2"=="clean" (
    echo ============================================================
    echo  BiLSTM-CNN Equalizer RTL Simulation
    echo  Simulator: %SIM%
    echo ============================================================
)


REM Step 1: Generate hex files if not present
if not exist "%HEX_DIR%\sigmoid_lut.hex" (
    if not "%2"=="clean" echo [1/3] Generating hex files...
    python "%ROOT%\scripts\gen_bilstm_hex.py"
) else (
    if not "%2"=="clean" echo [1/3] Hex files already exist.
)


REM Step 2: Compile and simulate
set "USE_VLOG="
if "%SIM%"=="questa"   set USE_VLOG=1
if "%SIM%"=="modelsim" set USE_VLOG=1

set "FLAGS="
set "EXTRA_SIM_ARGS="
if "%2"=="clean" (
    set "FLAGS=-DCLEAN_OUTPUT"
    set "EXTRA_SIM_ARGS=>nul"
)

if defined USE_VLOG (
    if not "%2"=="clean" echo [2/3] Compiling with %SIM%...
    cd /d "%ROOT%"
    if not exist "work_bilstm" vlib work_bilstm 2>nul
    vlog %FLAGS% -work work_bilstm -sv "%RTL_DIR%\lstm_cell.sv" "%RTL_DIR%\conv1d_layer.sv" "%RTL_DIR%\bilstm_cnn_top.sv" "%TB_DIR%\tb_bilstm_cnn_top.sv" %EXTRA_SIM_ARGS%
    if errorlevel 1 goto :error

    if not "%2"=="clean" echo [3/3] Running simulation...
    vsim -c %FLAGS% -do "run -all; quit -f" work_bilstm.tb_bilstm_cnn_top %EXTRA_SIM_ARGS%
    if errorlevel 1 goto :error
) else if "%SIM%"=="iverilog" (
    if not "%2"=="clean" echo [2/3] Compiling with Icarus Verilog...
    cd /d "%ROOT%"
    iverilog %FLAGS% -g2012 -o sim_bilstm.vvp "%RTL_DIR%\lstm_cell.sv" "%RTL_DIR%\conv1d_layer.sv" "%RTL_DIR%\bilstm_cnn_top.sv" "%TB_DIR%\tb_bilstm_cnn_top.sv"

    if not "%2"=="clean" echo [3/3] Running simulation...
    if not "%2"=="clean" (
        echo NOTE: Icarus Verilog may produce 'x' outputs due to dynamic array indexing limitations.
        echo       Use QuestaSim/ModelSim/Vivado for correct simulation.
    )
    vvp sim_bilstm.vvp
) else (
    echo Unknown simulator: %SIM%
    echo Usage: run_sim.bat [questa^|modelsim^|iverilog] [clean]
    goto :end
)



if not "%2"=="clean" (
    echo ============================================================
    echo  Simulation complete!
    echo  Output: %ROOT%\sim_data\weights_bilstm\rtl_bilstm_output.txt
    echo  Run: python scripts\verify_bilstm_rtl.py  to compare vs golden
    echo ============================================================
)
goto :end


:error
echo ============================================================
echo  ERROR: Simulation failed!
echo ============================================================

:end
