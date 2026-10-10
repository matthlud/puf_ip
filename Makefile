IVERILOG ?= iverilog
VVP ?= vvp
SIM_DIR := build/sim
SIM_BINARY := $(SIM_DIR)/puf_controller_tb.vvp
RTL := rtl/puf_controller.sv
TESTBENCH := tb/puf_controller_tb.sv

.PHONY: test clean

test: $(SIM_BINARY)
	$(VVP) $(SIM_BINARY)

$(SIM_BINARY): $(RTL) $(TESTBENCH)
	mkdir -p $(SIM_DIR)
	$(IVERILOG) -g2012 -s puf_controller_tb -o $@ $(RTL) $(TESTBENCH)

clean:
	rm -f $(SIM_BINARY)
	rmdir $(SIM_DIR) build 2>/dev/null || true
