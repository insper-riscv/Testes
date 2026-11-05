# Bug: the PLL never recovers from a loss of lock (only a power cycle fixes it)

🌐 [Português](../../pt-br/bugs/pll-lock-loss.md) · [English](pll-lock-loss.md)

## Symptom

Even with `jtagconfig` showing a healthy board (`02B050DD 5CE(BA4|FA4)`), read/write operations over JTAG on the In-System Memory Content Editor (`riscv-tools run`, `write_rom`, `mailbox.read_mailbox`) keep failing or never answering: "no mailbox result after 15.0s", `quartus_stp` hanging indefinitely, or "No editable memory instance was found". Only a physical power cycle of the board fixes it; reprogramming (`quartus_pgm`, even the `.sof`) alone, without a power cycle, does not.

This is a **different** symptom from the bug already documented in [HARDWARE_PROGRAMMING.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/HARDWARE_PROGRAMMING.md) ("Can't scan JTAG chain" right after a `quartus_sh --flow compile` followed by `quartus_pgm` launched as two separate Python calls): here `jtagconfig` still sees the chip normally, the problem is deeper.

## Why a healthy `jtagconfig` does not mean the mailbox read will work

There are two completely different JTAG layers:

1. **Basic JTAG TAP** (what `jtagconfig` scans): a fixed, dedicated hardware block, always present on the chip, which exists precisely to keep answering even if the user design is broken, hung, or not even configured. It does not depend on any internal clock of the design.
2. **In-System Memory Content Editor** (what `read_words.tcl`/`write_full.tcl`/`write_word.tcl` actually use, through `begin_memory_edit`/`update_content_to_memory_from_file`): goes through a debug "hub" **embedded in the user's own fabric** (`ENABLE_RUNTIME_MOD=YES` generates this infrastructure), which only answers if the design logic, and the clocks that feed it, are really running.

A healthy `jtagconfig` only guarantees layer 1. Layer 2 can be dead anyway, if the internal design is stuck (e.g. in permanent reset).

## Investigation

`core_fpga_test.vhd` derives all the design clocks (`pll_clk_if`, `pll_clk_idexmem`, `pll_clk_wb`) from a single PLL, and the `clk` of `rv32im_pipeline_core` (all the pipeline logic, registers, RegFile) specifically uses `pll_clk_idexmem`:

```vhdl
core_reset <= (not pll_locked) or (not FPGA_RESET_N);
```

That is: if `pll_locked` drops, the whole core (and by extension, everything the debug hub of the In-System Memory Content Editor needs to work) stays in reset. That alone is reasonable; the problem is what comes next. The compilation log (`quartus_sh --flow compile`) had been warning, repeatedly and ignored until now:

```
Warning: RST port on the PLL is not properly connected on instance
pll:pll_inst|pll_0002:pll_inst|altera_pll:altera_pll_i|general[0].gpll.
The reset port on the PLL should be connected. If the PLL loses lock for
any reason, you might need to manually reset the PLL in order to
re-establish lock to the reference clock.
```

Checking the code: `core_fpga_test.vhd` had

```vhdl
pll_inst : entity work.pll
  port map (
    refclk   => CLOCK_50,
    rst      => '0',
    ...
```

`rst` tied permanently to `'0'`: it is never pulsed. And the PLL IP (`pll.vhd`) was generated with `gui_pll_auto_reset value="Off"`, so this IP **does not try to relock by itself** if it loses lock for any reason (supply noise, a glitch, whatever). Without ever receiving a `rst` pulse, once `pll_locked` drops, it stays stuck at "not locked" **forever**, and consequently the whole core stays in reset forever, even though the basic JTAG TAP remains perfectly healthy (layer 1, independent of all this).

This matches exactly the pattern observed throughout the session: retry does not fix it (nothing ever pulses `rst`), reprogramming alone sometimes does not fix it (it depends on whether `quartus_pgm` alone forces a full configuration reset or not), and a power cycle always fixes it (reinitializes everything, PLL included).

## Fix applied

```vhdl
pll_inst : entity work.pll
  port map (
    refclk   => CLOCK_50,
    rst      => not FPGA_RESET_N,
    ...
```

Ties the PLL reset to the existing physical reset button: pressing that button now also forces the PLL to try to lock again, instead of only holding the core in reset while `pll_locked` is low. If this really is the root cause of the instability, the physical button should now be enough to recover the board, with no need for a full power cycle.

## Status: well-grounded hypothesis, not yet isolated empirically

The code (`rst => '0'` + `gui_pll_auto_reset=Off` + Quartus's own warning) is real and direct evidence, not speculation, but I have not yet isolated it as the **only** cause through a controlled test (e.g. reproducing the hang and confirming that just pressing the physical button, without powering the board off, recovers it). The next times the board hangs this way, it is worth trying the physical reset button before going straight to the full power cycle: both to confirm the hypothesis and because, if it is right, it is a much faster recovery.

This does not replace the rule of `quartus_sh`+`quartus_pgm` in a single shell process (see [HARDWARE_PROGRAMMING.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/HARDWARE_PROGRAMMING.md)): they are two distinct hardware/platform bugs, both real.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
