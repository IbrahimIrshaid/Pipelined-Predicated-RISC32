# Questa / ModelSim:  cd sim && vsim -c -do run.do
if {[file exists work]} { vdel -lib work -all }
vlib work
vlog -sv +incdir+../rtl ../rtl/opcodes.v ../rtl/basic_components.v ../rtl/controller.v \
    ../rtl/datapath.v ../rtl/processor.v ../rtl/memories.v ../rtl/top.v ../tb/tb_selfcheck.sv
vsim -c tb_selfcheck
run -all
quit -f
