# PUF Controller Specification

## Register map

The register interface uses 8-bit byte addresses and 32-bit registers. All
defined registers are word-aligned.

| Address | Register | R/W | Description |
|---|---|---|---|
| `0x00` | `CONTROL` | W | Write-one command bits: start or software reset |
| `0x04` | `STATUS` | R | Busy, done, and error flags |
| `0x08` | `DATA0` | R | Response bits `[31:0]` |
| `0x0C` | `DATA1` | R | Response bits `[63:32]` |
| `0x10` | `DATA2` | R | Response bits `[95:64]` |
| `0x14` | `DATA3` | R | Response bits `[127:96]` |
| `0x18` | `CRC` | R | CRC-32/ISO-HDLC of the 128-bit response |
| `0x1C` | `MASK0` | R/W | Transfer mask bits `[31:0]` |
| `0x20` | `MASK1` | R/W | Transfer mask bits `[63:32]` |
| `0x24` | `MASK2` | R/W | Transfer mask bits `[95:64]` |
| `0x28` | `MASK3` | R/W | Transfer mask bits `[127:96]` |

The transfer mask is a per-bit enable vector. `MASK[x] = 1` means bit `x` is
captured into the response and contributes to the CRC. `MASK[x] = 0` suppresses
that bit from the transferred response and excludes it from the CRC update. The
mask defaults to all ones after reset so the original acquisition behavior is
preserved.

### `CONTROL` (`0x00`)

Control bits are write-one commands, not stored values. Writing a `1` requests
the command; writing a `0` has no effect. Reads from this write-only address
return zero.

| Bit | Name | Description |
|---:|---|---|
| 0 | `START` | Start a new 128-bit acquisition if the controller is idle |
| 1 | `RESET` | Clear status and result registers if the controller is idle |

If both command bits are set, `RESET` takes priority and `START` is ignored.
`RESET` is ignored while `BUSY` is set; it does not interrupt an acquisition.
The active-low hardware reset `rst_n` resets the controller asynchronously.

### `STATUS` (`0x04`)

| Bit | Name | Description |
|---:|---|---|
| 0 | `BUSY` | An acquisition is in progress |
| 1 | `DONE` | The latest acquisition completed successfully |
| 2 | `ERROR` | A `START` command was written while `BUSY` was set |

Bits `[31:3]` are reserved and read as zero. `DONE` remains set after
completion until an accepted `START`, an accepted `RESET`, or assertion of
`rst_n`. `ERROR` remains set until an accepted `RESET` or assertion of
`rst_n`. An accepted `START` clears `DONE` but does not clear `ERROR`. A
`START` while busy leaves the active acquisition unchanged and sets `ERROR`.

In the current interface, the controller has no PUF reliability or macro-error
input. Consequently, `ERROR` reports only a `START` command issued while busy;
it does not indicate an internal PUF macro failure or an unreliable bit.

### `DATA0`-`DATA3` and `CRC`

On an accepted `START`, all response and CRC registers are cleared. The controller pulses `puf_start` once for each response bit. `puf_index`
identifies the requested bit and remains stable until its `puf_valid` pulse
arrives. The macro must return one `puf_valid` pulse and the corresponding
`puf_bit` for each request. Each `puf_start` assertion lasts one clock cycle.
After a bit is captured, the controller advances the index and leaves
`puf_start` low for at least one full clock cycle before issuing the next
request. Valid captures are numbered consecutively from 0 through 127. The
first captured bit is response bit 0 (`DATA0[0]`), and the last is response
bit 127 (`DATA3[31]`). After capture 127, `BUSY` clears and `DONE` sets;
`puf_index` remains 127 until the next accepted command. The result registers
may contain a partial response while `BUSY` is set; software should use them
only after `DONE` is set.

`CRC` is the 32-bit CRC-32/ISO-HDLC (also known as CRC-32/IEEE):

- Width: 32 bits
- Normal polynomial: `0x04C11DB7` (reflected implementation polynomial:
  `0xEDB88320`)
- Initial value: `0xFFFFFFFF`
- Input and output reflected (`RefIn = true`, `RefOut = true`)
- Final XOR: `0xFFFFFFFF`
- Input order: captured response bits in acquisition order, from response bit
  0 through response bit 127 (LSB-first)

The CRC is finalized when the 128th valid bit is captured. `DATA0` through
`DATA3` and `CRC` reset to zero on `rst_n` and on an accepted `RESET` command.

## Reset values

Asserting active-low `rst_n` asynchronously resets the controller. Every
software-visible register resets to zero:

| Register/field | Reset value |
|---|---:|
| `CONTROL` command state | `0x00000000` (commands are not retained) |
| `STATUS.BUSY` | `0` |
| `STATUS.DONE` | `0` |
| `STATUS.ERROR` | `0` |
| `DATA0`-`DATA3` | `0x00000000` |
| `CRC` | `0x00000000` |

## Reserved and unsupported accesses

Reserved bits are ignored on writes and read as zero. Writes to read-only or
unmapped addresses are ignored; reads from unmapped addresses return zero.
The register interface has no bus-error response.

## Register interface

The register interface is a simple, synchronous, 32-bit memory-mapped
interface. It has no ready, wait-state, byte-enable, or bus-error signals.

| Signal | Direction | Description |
|---|---|---|
| `clk` | Input | Register interface and controller clock; operations are sampled on the rising edge |
| `rst_n` | Input | Asynchronous active-low reset |
| `reg_wr` | Input | One-cycle write strobe |
| `reg_rd` | Input | Read enable |
| `reg_addr[7:0]` | Input | Byte address of the selected register |
| `reg_wdata[31:0]` | Input | Write data sampled with `reg_wr` |
| `reg_rdata[31:0]` | Output | Combinational read data; zero when `reg_rd` is deasserted |

`reg_wr` and `reg_rd` must not be asserted in the same cycle. A write takes
effect on the rising edge where `reg_wr` is sampled. Read data is
combinationally available for the selected address while `reg_rd` is asserted;
there is no registered read latency. Addresses are byte offsets, and only the
word-aligned addresses in the register map are defined. The interface does
not acknowledge transactions: each asserted write strobe is one write, and
each asserted read enable selects one register for the duration of that
enable.

## Interrupt

`irq` is an active-high, level-sensitive output. It is asserted while either
`DONE` or `ERROR` is set. It deasserts when the corresponding status flags are
cleared by an accepted command or hardware reset.
