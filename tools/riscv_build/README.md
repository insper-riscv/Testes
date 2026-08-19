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

This is the actual setup running on this machine — repo
[`insper-riscv/RISC-V-Workstation-Tests`](https://github.com/insper-riscv/RISC-V-Workstation-Tests)
(private), runner named `WS-C621E-SAGE`, runner group `Workstation -
FPGA` (Repository access → Selected repositories → only this repo;
"Allow public repositories" left unchecked — otherwise the public
`RV32IM`, same org, could reach this exact machine through the same
runner).

**Hardware/board facts, already reflected in `config.yaml`/`link.ld`/`include/rv32_test.h`:**
- JTAG: `jtagconfig` reports hardware `USB-Blaster [1-4]`, device
  `@1: 5CE(BA4|FA4) (0x02B050DD)`.
- `core_fpga_test`'s ROM1PORT/RAM1PORT IPs both have
  `ENABLE_RUNTIME_MOD=YES` (`INSTANCE_NAME=ROM` / `RAM`), so the
  In-System Memory Content Editor can read/write them over JTAG — this
  is what `read_mailbox.tcl`/`dump_ram.tcl` rely on.
- Memory map: `rv32im_pipeline_core` is Harvard (separate `rom_addr` /
  `ram_addr` buses, each its own space starting at `0x0`) — ROM is
  8192 words (32K), RAM is 4096 words (16K), mailbox at the last RAM
  word (`0x00003FFC`).

**The runner runs as a dedicated, unprivileged Linux service account**
(`runner`, no login password, no sudo of its own), home at
`/opt/actions-runner` — deliberately *not* `/home/runner`, and
deliberately *not* in the `picow` group, so it has zero standing
access to anything under `/home/picow`:

```bash
sudo useradd -r -m -d /opt/actions-runner -s /bin/bash runner
sudo passwd -l runner              # no password login; only reachable via sudo/systemd
sudo usermod -aG plugdev runner    # USB-Blaster access; udev already makes the device 0666 anyway

# Org Settings -> Actions -> Runners -> New runner gives the download URL + token.
# --url is the ORG (this is an org-level runner) — the runner-group
# restriction above is what actually limits which repos reach it.
sudo -iu runner bash -lc '
  cd /opt/actions-runner
  curl -o actions-runner.tar.gz -L <download URL from that page>
  tar xzf actions-runner.tar.gz
  ./config.sh --url https://github.com/<org> --token <token from that same page> \
      --labels self-hosted,quartus,fpga --name workstation-fpga --unattended
'
```

Registering the token needs the **`workflow`** permission (fine-grained
PAT: "Workflows", separate from "Contents"/"Actions") to be able to
push `.github/workflows/*.yml` at all — without it, `git push` gets
rejected with "refusing to allow a Personal Access Token to create or
update workflow ... without `workflow` scope".

Since `runner` isn't in the `picow` group, it can't reach Quartus at
`/home/picow/altera_lite` either (`/home/picow` is `750`). Fixed with
a bind mount instead of a group grant — `runner` never gets any
permission on `/home/picow` itself, it just sees the same directory
tree through a second, root-managed path under `/opt`:

```bash
sudo mkdir -p /opt/altera_lite
echo '/home/picow/altera_lite /opt/altera_lite none bind 0 0' | sudo tee -a /etc/fstab
sudo mount --bind /home/picow/altera_lite /opt/altera_lite
```

**Service**, written directly as the admin rather than via the bundled
`svc.sh install` (which shells out to `sudo systemctl ...` itself —
conflicts with `runner` having no sudo):

```bash
sudo tee /etc/systemd/system/gh-actions-runner.service <<'UNIT'
[Unit]
Description=GitHub Actions self-hosted runner (FPGA workstation)
After=network.target

[Service]
Type=simple
User=runner
WorkingDirectory=/opt/actions-runner
ExecStart=/opt/actions-runner/run.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now gh-actions-runner
```

`real.yml`'s `workflow_dispatch` also gates on a repository secret
(`FPGA_RUN_SECRET`, set under Settings → Secrets and variables →
Actions, e.g. `openssl rand -hex 32`): repo write access already
controls who can trigger it, but this adds a second check for anyone
with write access who still shouldn't be able to run jobs on the
physical board — pass the same value in the `confirm` input when
dispatching manually. It only guards the manual path; a push to `main`
is gated by branch protection instead.

**Runner OS is Ubuntu 22.04** (glibc 2.35, confirmed via `lsb_release
-a`/`ldd --version`) — `real.yml` downloads the
`riscv32-elf-ubuntu-22.04-gcc.tar.xz` riscv-collab asset specifically
for this reason; the `ubuntu-24.04` one (needs glibc ≥2.38) fails to
even start with a `GLIBC_2.38 not found` error. If this runner is ever
reinstalled on a newer Ubuntu, update that asset name in `real.yml`
and clear `/opt/actions-runner/.cache/riscv32-elf` (see the toolchain
caching note below — it won't redetect the mismatch on its own, since
it only compares release tags, not compatibility).

## Design decisions worth knowing

- **Toolchain**: both `sim.yml` and `real.yml` always track the latest
  nightly from
  [riscv-collab/riscv-gnu-toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain)
  rather than pinning a tag — the project ships no "stable" release,
  updates often specifically to fix bugs, and this is meant to track
  the same toolchain used in production. `sim.yml` runs on an
  ephemeral GitHub-hosted runner, so it just re-downloads every time.
  `real.yml` runs on a persistent machine: it checks the latest
  release tag via the GitHub API every run (a ~1KB request) and caches
  the ~200MB toolchain at `/opt/actions-runner/.cache/riscv32-elf`,
  only re-downloading when that tag actually changed — always current,
  without paying the download cost on every push when nothing changed
  upstream.
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

The `real` suite is fully wired up and running in CI on this
workstation (see above). What's still open:

| File | What |
|---|---|
| `sim/Makefile` | `TOPLEVEL`, `VHDL_SOURCES` — sim has no real core wired in yet |
| `sim/test_c_program.py` | `dut.rom_inst` / `dut.ram_inst` hierarchical paths, and the `clk`/`rst` signal names |
| `.github/workflows/real.yml` | `riscv32-elf-ubuntu-22.04-gcc.tar.xz` asset name and `/opt/altera_lite/...` PATH, if this ever moves to a different/newer runner OS or a different Quartus install location |
