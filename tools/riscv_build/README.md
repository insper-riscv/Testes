# RISC-V test pipeline

Compiles bare-metal C test programs, runs them two ways, and reports
PASS/FAIL:

- **real** (`tests/c/real/`): runs on an actual FPGA over JTAG.
- **sim** (`tests/c/sim/`): runs in a GHDL/cocotb simulation, no hardware needed.

The **real** suite is wired to
[`RV32IM/tests/FPGA/core/quartus/core_fpga_test.qpf`](../../../RV32IM/tests/FPGA/core/quartus/core_fpga_test.qpf)
(a sibling repo, not nested under this folder) — the only working core
+ Quartus project on this workstation. The **sim** suite still has no
real VHDL core wired in; that part remains `<<< ADJUST` (list at the
bottom of this file).

## Writing a test

Drop a `.c` file into `tests/c/real/` or `tests/c/sim/`. Two optional
header comments configure it:

```c
// RV32_EXT: M          // extensions ADDED to the implicit rv32i base.
// RV32_EXT: M,A        // order doesn't matter — both this and "A,M" become rv32ima.
// RV32_TEST_KIND: unit          // default. real tests only: checked via the
// RV32_TEST_KIND: integration   // PASS/FAIL mailbox alone, or mailbox + a
                                  // full RAM dump compared against
                                  // tests/c/real/golden/<name>.json.
#include "rv32_test.h"

int main(void) {
    // ... RV32_PASS() or RV32_FAIL() when done ...
}
```

An `integration` test needs a matching
`tests/c/real/golden/<name>.json`: byte address (hex string) -> expected
value (0-255). `build_tests.py` fails fast if it's missing.

## Running locally

```bash
# real (needs Quartus + a board on JTAG)
python3 tools/riscv_build/build_tests.py --emit mif
python3 tools/riscv_build/build_fpga.py

# sim (needs GHDL + cocotb)
python3 tools/riscv_build/build_tests.py --emit hex
python3 tools/riscv_build/run_sim_tests.py
```

Both `build_tests.py` runs iterate every `.c` file in their folder and
write a `build/{real,sim}/manifest.json` that the corresponding runner
consumes.

## CI

Each suite has its own workflow file:

- [`.github/workflows/sim.yml`](../../.github/workflows/sim.yml) —
  runs on any push/PR/branch, on a standard GitHub-hosted runner
  (`ghdl/ghdl:6.0.0-mcode-ubuntu-24.04`, no license needed). Also
  triggerable manually via **Actions → sim tests → Run workflow**.
- [`.github/workflows/real.yml`](../../.github/workflows/real.yml) —
  only on `main`, or on demand via **Actions → real tests (FPGA) → Run
  workflow**. Needs a self-hosted runner with Quartus and a board
  attached.

## Configuring the real suite on this workstation

This machine already has everything the real suite needs to run
*locally* (i.e. `python3 tools/riscv_build/build_fpga.py`, run by
hand):

- Quartus 25.1std at `/home/picow/altera_lite/25.1std/quartus/bin` —
  add it to `PATH` before running anything (`quartus_sh`,
  `quartus_pgm`, `quartus_stp` all live there).
- The board answers on JTAG: `jtagconfig` reports hardware
  `USB-Blaster [1-4]`, device `@1: 5CE(BA4|FA4) (0x02B050DD)` —
  already set in `config.yaml`.
- `core_fpga_test`'s ROM1PORT/RAM1PORT IPs both have
  `ENABLE_RUNTIME_MOD=YES` (`INSTANCE_NAME=ROM` / `RAM`), so the
  In-System Memory Content Editor can read/write them over JTAG — this
  is what `read_mailbox.tcl`/`dump_ram.tcl` rely on. Confirmed by
  grepping `ips/{ROM,RAM}1PORT/*1port.vhd`; no Quartus GUI changes
  needed.
- Memory map: `rv32im_pipeline_core` is Harvard (separate `rom_addr` /
  `ram_addr` buses, each its own space starting at `0x0`) — ROM is
  8192 words (32K), RAM is 4096 words (16K), mailbox at the last RAM
  word (`0x00003FFC`). All already reflected in `config.yaml`,
  `link.ld`, and `include/rv32_test.h`.

CI needs a git repo with a GitHub remote to attach a runner to — this
folder lives in a new **private** repo, separate from `RV32IM`
(`RV32IM` is public, and a self-hosted runner reachable from a public
repo means anyone who can open a PR against it can run code on
whatever machine the runner lives on).

**If the runner is registered at the organization level** (available
to every repo in the org, not just this one), that protection doesn't
hold by default: any repo the runner's *runner group* is scoped to —
often "All repositories" out of the box — can dispatch jobs to it,
including the public `RV32IM`. Go to **Organization Settings → Actions
→ Runner groups**, find the group this runner landed in, and set
**Repository access → Selected repositories → only the private `test`
repo**. Without this step, a public repo in the same org can still
reach this exact machine, which defeats the whole point of making
`test` private.

The runner itself runs as a dedicated, unprivileged Linux service
account (`runner`), not as a regular login user:

```bash
# as an admin (has sudo)
sudo useradd -m -s /bin/bash runner
sudo passwd -l runner              # no password login; only reachable via sudo/systemd
sudo usermod -aG picow runner      # /home/picow is 750 — needed just to traverse into altera_lite
sudo usermod -aG plugdev runner    # defense in depth; the USB-Blaster udev rule is already 0666

# register the runner AS that user (uses the admin's sudo, not runner's — runner gets none)
# Org Settings -> Actions -> Runners -> New runner gives the download URL + token below.
# (--url is the ORG, not a specific repo, for an org-level runner — see the
# runner-group restriction above, which is what actually limits which repos reach it.)
sudo -iu runner bash -lc '
  mkdir -p ~/actions-runner && cd ~/actions-runner
  curl -o actions-runner.tar.gz -L <download URL from that page>
  tar xzf actions-runner.tar.gz
  ./config.sh --url https://github.com/<org> --token <token from that same page> \
      --labels self-hosted,quartus,fpga --name workstation-fpga --unattended
'
```

The bundled `svc.sh install` expects the service user to have sudo of
its own (it shells out to `sudo systemctl ...`), which conflicts with
`runner` having none. Writing the systemd unit directly as the admin
avoids that:

```bash
sudo tee /etc/systemd/system/gh-actions-runner.service <<'UNIT'
[Unit]
Description=GitHub Actions self-hosted runner (FPGA workstation)
After=network.target

[Service]
Type=simple
User=runner
WorkingDirectory=/home/runner/actions-runner
ExecStart=/home/runner/actions-runner/run.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now gh-actions-runner
```

The token and download URL are one-time, repo-specific, and shown on
the GitHub Settings page — there's no way to script around fetching
them yourself.

`real.yml`'s `workflow_dispatch` also gates on a repository secret
(`FPGA_RUN_SECRET`, set under Settings → Secrets and variables →
Actions): repo write access already controls who can trigger it, but
this adds a second check for anyone with write access who still
shouldn't be able to run jobs on the physical board — set it to any
passphrase and pass the same value in the `confirm` input when
dispatching manually. It only guards the manual path; a push to `main`
is gated by branch protection instead.

## Design decisions worth knowing

- **Toolchain**: both `sim.yml` and `real.yml` always pull the latest
  nightly from
  [riscv-collab/riscv-gnu-toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain)
  rather than pinning a tag, even though `real.yml` runs on a
  persistent machine that could cache it — the project ships no
  "stable" release, updates often specifically to fix bugs, and this
  is meant to track the same toolchain used in production, so a stale
  local copy would defeat the point. Costs a ~200MB download per run,
  which is negligible next to the Quartus compile it's followed by.
- **Recompile-per-test**: `build_fpga.py` overwrites the ROM IP's
  `.mif` and runs a full `quartus_sh --flow compile` for every test,
  producing one bitstream each. This is simpler and needs no extra
  infrastructure, but is slow for large suites — if that becomes a
  bottleneck, the alternative is flashing one bitstream and loading
  each test's ROM content live via JTAG (Quartus' In-System Memory
  Content Editor supports this too), skipping recompilation entirely.
- **JTAG readback**: reading the PASS/FAIL mailbox and dumping RAM
  both go through Quartus' In-System Memory Content Editor
  (`quartus_stp` + the `insystem_memory_edit` package) — this is the
  only realistic channel for getting data off real silicon without
  UART or LEDs, so both `RV32_TEST_KIND` variants use it after
  programming the board.
- **GHDL container tag**: `ghdl/ghdl:6.0.0-mcode-ubuntu-24.04` — the
  Docker Hub scheme moved from loose tags like `ubuntu22-mcode` to
  versioned ones (`<ghdl-version>-<backend>-ubuntu-<version>`); this
  is the current stable GHDL release on an LTS base.

## `<<< ADJUST` checklist

The `real` suite's config is resolved for this workstation (see above).
What's still open:

| File | What |
|---|---|
| `sim/Makefile` | `TOPLEVEL`, `VHDL_SOURCES` — sim has no real core wired in yet |
| `sim/test_c_program.py` | `dut.rom_inst` / `dut.ram_inst` hierarchical paths, and the `clk`/`rst` signal names |
| `.github/workflows/real.yml` | `runs-on` labels — only matter once a runner is registered with those exact labels (see above); adjust the `branches: [main]` check too if the target repo's default branch isn't `main` |
| — | This folder (or wherever it ends up living) needs to actually be a git repo with a GitHub remote before either workflow can run in CI at all — see "Configuring the real suite on this workstation" above |
