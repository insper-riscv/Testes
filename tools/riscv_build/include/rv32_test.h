/* Convention used by the simulation testbench (GHDL/cocotb) to know a
 * test's outcome: the program writes 1 (PASS) or 2 (FAIL) here and spins
 * forever */
#ifndef RV32_TEST_H
#define RV32_TEST_H

/* The testbench watches this address and ends the simulation
 * once it stops being 0. Must match memory.mailbox_addr in config.yaml. */
#define RV32_MAILBOX_ADDR ((volatile unsigned int *)0x00003FFC)

/* Implemented in crt0.S: waits for go_flag_addr to go nonzero, then
 * jumps back to _start. Lets build_fpga.py re-run a different program
 * on the same, already-configured bitstream (JTAG-write a new ROM
 * image + pulse the flag) instead of reprogramming the FPGA. */
extern void rv32_wait_restart(void) __attribute__((noreturn));

/* Signals to the testbench that the test PASSED. */
static inline void RV32_PASS(void) {
    *RV32_MAILBOX_ADDR = 1;
    rv32_wait_restart();
}

/* Signals to the testbench that the test FAILED. */
static inline void RV32_FAIL(void) {
    *RV32_MAILBOX_ADDR = 2;
    rv32_wait_restart();
}

#endif /* RV32_TEST_H */
