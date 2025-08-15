verilator src/alu.v --top-module alu -Isrc -Iinclude -cc -CFLAGS -g --trace -exe verilator/alu_tb.cpp && make -C obj_dir -j -f Valu.mk Valu
verilator src/sram.v --top-module sram -Iinclude -cc -CFLAGS -g --trace -exe verilator/sram_tb.cpp && make -C obj_dir -j -f Vsram.mk Vsram
