# PUF Controller

A small SystemVerilog controller for collecting a 128-bit response from a
PUF macro. The controller exposes a simple 32-bit register interface and
calculates CRC-32/ISO-HDLC over the captured response.

## Project layout

```text
docs/puf_controller_spec.md  Register and interface specification
rtl/puf_controller.sv        Controller RTL
tb/puf_controller_tb.sv      Self-checking simulation testbench
Makefile                     Test and cleanup targets
```

## Open-source tools

The project uses open-source software only:

- **Icarus Verilog** (`iverilog` and `vvp`) to compile and run the simulation.
- **GNU Make** to use the optional `make test` shortcut.

Install on Debian or Ubuntu:

```sh
sudo apt update
sudo apt install iverilog make
```

Other package managers provide the same tools; for example, Fedora:

```sh
sudo dnf install iverilog make
```

## Run the testbench

From the repository root, run the testbench directly with Icarus Verilog:

```sh
iverilog -g2012 -s puf_controller_tb \
  -o /tmp/puf_controller_tb.vvp \
  rtl/puf_controller.sv tb/puf_controller_tb.sv
vvp /tmp/puf_controller_tb.vvp
```

A successful run prints:

```text
puf_controller_tb: PASS
```

Alternatively, use GNU Make to compile and run it:

```sh
make test
```

The Makefile places the compiled simulation in `build/sim/`. Remove that
generated simulation file with:

```sh
make clean
```

The testbench checks reset values, control writes, status behavior, PUF request
pulse spacing and count, response-bit placement, and the computed CRC.

## Waveform viewing

The testbench writes a VCD waveform to `build/sim/puf_controller_tb.vcd`.
Open it with GTKWave:

```sh
sudo apt install gtkwave
make test
gtkwave build/sim/puf_controller_tb.vcd
```

## Interface and register specification

See [docs/puf_controller_spec.md](docs/puf_controller_spec.md) for the full
register map, command/status semantics, PUF request/response handshake, CRC
parameters, transfer mask behavior, reset behavior, reserved accesses, and
interrupt behavior.
