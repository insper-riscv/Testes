/* Convention used by the simulation testbench (GHDL/cocotb) to know a
 * test's outcome: the program writes 1 (PASS) or 2 (FAIL) here and spins
 * forever */
#ifndef RV32_TEST_H
#define RV32_TEST_H

/* The testbench watches this address and ends the simulation
 * once it stops being 0. Must match memory.mailbox_addr in config.yaml. */
#define RV32_MAILBOX_ADDR ((volatile unsigned int *)0x00003FFC)

/* Signals to the testbench that the test PASSED. */
static inline void RV32_PASS(void) {
    *RV32_MAILBOX_ADDR = 1;
    for (;;) {}
}

/* Signals to the testbench that the test FAILED. */
static inline void RV32_FAIL(void) {
    *RV32_MAILBOX_ADDR = 2;
    for (;;) {}
}

#endif /* RV32_TEST_H */
