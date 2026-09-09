"""cocotb testbench for ACT4 certification ELFs (I/M-only, see ../rv32im-min/).

Same idea as tools/riscv_build/sim/test_c_program.py — watches the RAM
write bus for a specific address instead of reading rv32im_pipeline_core's
internal state directly (this GHDL install's VPI can't see array-of-vector
signals, see that module's own docstring) — but ACT4 tests don't know
about this project's PASS/FAIL mailbox convention at all. They use the
HTIF tohost/fromhost convention instead (RVMODEL_HALT_PASS/FAIL, see
../rv32im-min/rvmodel_macros.h), and print an RVCP-SUMMARY line through
a "console" word (RVMODEL_IO_WRITE_STR) that link.ld places right after
tohost/fromhost — both watched here the same way.

Unlike test_c_program.py's MAILBOX_PASS/FAIL (1/2), tohost's PASS/FAIL
encoding is HTIF's own: odd values are "done", 1 = pass, anything else
odd = fail (RVMODEL_HALT_FAIL always writes exactly 3, but this checks
oddness/value-1 rather than hardcoding 3 alone, matching how Spike
itself treats tohost).
"""

import os

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

# Must stay in sync with ../rv32im-min/link.ld's `ram (rw)` region and
# its trailing tohost/fromhost/rv32_act_console layout: ORIGIN(ram) +
# LENGTH(ram) = 0x00020000 + (0x20000 - 20) = 0x3FFEC.
TOHOST_ADDR = 0x0003FFEC
CONSOLE_ADDR = 0x0003FFFC
TOHOST_PASS = 1
TIMEOUT_CYCLES = 200_000


@cocotb.test()
async def test_program(dut) -> None:
    test_name = os.environ.get("TEST_NAME", "?")
    dut._log.info(f"running {test_name}")

    cocotb.start_soon(Clock(dut.CLK, 10, unit="ns").start())

    cycles_used = 0
    console_bytes = bytearray()

    dut.reset.value = 1
    await ClockCycles(dut.CLK, 5)
    dut.reset.value = 0

    for _ in range(TIMEOUT_CYCLES):
        await RisingEdge(dut.CLK)
        cycles_used += 1

        if dut.ram_wren.value != 1 or dut.ram_en.value != 1:
            continue

        addr = int(dut.ram_addr.value)
        data = int(dut.ram_wdata.value)

        if addr == CONSOLE_ADDR:
            byte = data & 0xFF
            if byte == 0:
                if console_bytes:
                    dut._log.info(console_bytes.decode("ascii", errors="replace"))
                    console_bytes.clear()
            else:
                console_bytes.append(byte)
            continue

        if addr != TOHOST_ADDR:
            continue

        if console_bytes:
            dut._log.info(console_bytes.decode("ascii", errors="replace"))

        dut._log.info(f"CLOCK CYCLES TAKEN {cycles_used}")
        if data == TOHOST_PASS:
            dut._log.info("PASS")
            return
        raise AssertionError(f"test signalled FAIL via tohost (value={data:#x})")

    raise AssertionError(
        f"timed out after {TIMEOUT_CYCLES} cycles without a tohost PASS/FAIL write"
    )
