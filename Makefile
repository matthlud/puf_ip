IVERILOG ?= iverilog
VVP ?= vvp
SIM_DIR := build/sim
SIM_BINARY := $(SIM_DIR)/puf_controller_tb.vvp
RTL := rtl/puf_controller.sv rtl/puf_model.sv
TESTBENCH := tb/tests/test_top.sv

.PHONY: test wave clean

WAVE_FILE := $(SIM_DIR)/puf_controller_tb.vcd

test: $(SIM_BINARY)
	$(VVP) $(SIM_BINARY)

wave: test
	@echo "Waveform written to $(WAVE_FILE)"
	@echo "Open it with: gtkwave $(WAVE_FILE)"

$(SIM_BINARY): $(RTL) $(TESTBENCH)
	mkdir -p $(SIM_DIR)
	$(IVERILOG) -g2012 -s puf_controller_tb -o $@ $(RTL) $(TESTBENCH)

clean:
	rm -f $(SIM_BINARY) $(WAVE_FILE)
	rmdir $(SIM_DIR) build 2>/dev/null || true
