# PUF Controller

A small SystemVerilog controller for collecting a 128-bit response from a
PUF macro. The controller exposes a simple 32-bit register interface and
calculates CRC-32/ISO-HDLC over the captured response.

## Project layout

```text
docs/puf_controller_spec.md       Register and interface specification
rtl/puf_controller.sv             Controller RTL
rtl/puf_model.sv                  Deterministic PUF source model
tb/tests/                         Modular self-checking testbench
formal/                           SymbiYosys harness, assertions, and runner
r2g/                              OpenROAD RTL-to-GDS flow
Makefile                          Simulation and cleanup targets
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

From the repository root, run all registered tests with:

```text
make test
```

The Makefile places the compiled simulation in `build/sim/`. Remove that
generated simulation file with:

```sh
make clean
```

The testbench checks reset values, control writes, status behavior, PUF request
pulse spacing and count, response-bit placement, and the computed CRC.

## RTL-to-GDS with OpenROAD

The minimal ASIC flow lives in `r2g/` and uses the official
[`openroad/orfs`](https://hub.docker.com/r/openroad/orfs) OpenROAD Flow Scripts
container, pinned by default to `v3.0-3197-g7fcc1909`. Docker is required;
OpenROAD and the PDK tools do not need to be installed on the host.

Run the flow with one of the supported platforms:

```sh
./r2g/run.sh sky130hd
# or: ./r2g/run.sh nangate45
# or: ./r2g/run.sh asap7
```

The default platform is `sky130hd`, so `./r2g/run.sh` is equivalent. The final
GDS is written to
`r2g/build/results/<platform>/puf_r2g_top/base/6_final.gds`. Override the
container image with `ORFS_IMAGE` if needed. The runner defaults to one worker; set
`NUM_CORES=4` before invoking it to request more.

The physical top integrates both the controller and the deterministic PRBS
model. This produces a reproducible example layout, not a silicon-accurate PUF:
the model is not a substitute for a physical entropy source or a characterized
PUF macro.

## Waveform viewing

The testbench writes a VCD waveform to `build/sim/puf_controller_tb.vcd`.
Open it with GTKWave:

```sh
sudo apt install gtkwave
make test
gtkwave build/sim/puf_controller_tb.vcd
```

## Formal verification

The controller has an optional formal assertion set guarded by `FORMAL`, so
normal simulation and synthesis builds are unchanged. It uses SymbiYosys (SBY)
and the ABC PDR engine from the pinned OpenROAD Flow Scripts container:

```sh
./formal/run.sh
```

Docker is required. The proof results are written under
`build/formal/puf_controller/`; set `FORMAL_IMAGE` to override the default
container image. The assertions check status/IRQ consistency, reserved-register
reads, the busy/done invariant, mask stability while acquiring, response and
CRC-state updates for masked and unmasked bits, index advancement, and final
CRC publication.

The harness constrains the abstract PUF source to return no more than one bit
per outstanding request. Response latency remains unbounded, so the proof does
not claim that an acquisition eventually completes.

## Interface and register specification

See [docs/puf_controller_spec.md](docs/puf_controller_spec.md) for the full
register map, command/status semantics, PUF request/response handshake, CRC
parameters, transfer mask behavior, reset behavior, reserved accesses, and
interrupt behavior.
