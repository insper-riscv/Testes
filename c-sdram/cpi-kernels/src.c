// RV32_EXT: M, Zicsr
// RV32_TEST_KIND: unit
// RV32_TIMEOUT_S: 90
#include "rv32_test.h"
#include "rv32_platform.h"
#include "rv32_sdram.h"
#include <stdio.h>

// Cycles per instruction of five kernels, measured with the cycle and instret counters of Zicntr.
// Each kernel runs between two reads of both counters, and the program prints one line per kernel
// ("cpi <name> <cycles> <instret>") on the JTAG UART. The counts are the same on the board and in
// the simulation, so the two outputs can be compared line by line. The program checks that every
// kernel moved both counters and took at most 200 cycles per instruction.

#define UART_STATUS ((volatile unsigned int *)0xC0000008u)
#define HOST_ATTACHED(status) (((status) >> 17) & 1u)
#define ATTACH_POLLS 40000000u
#define N 256
#define DRAIN_SPINS 8000000u

struct sample {
    unsigned int cycles;
    unsigned int instret;
};

static inline unsigned int read_cycle(void) {
    unsigned int v;
    __asm__ volatile("csrr %0, 0xC00" : "=r"(v));
    return v;
}

static inline unsigned int read_instret(void) {
    unsigned int v;
    __asm__ volatile("csrr %0, 0xC02" : "=r"(v));
    return v;
}

static struct sample begin(void) {
    struct sample s;
    s.instret = read_instret();
    s.cycles = read_cycle();
    return s;
}

static void finish(const char *name, struct sample s) {
    unsigned int cycles = read_cycle() - s.cycles;
    unsigned int instret = read_instret() - s.instret;
    printf("cpi %s %u %u\n", name, cycles, instret);
    // the UART holds a few bytes: give the host time to drain them before the next line
    for (volatile unsigned int w = 0; w < DRAIN_SPINS; w++) {
    }
    if (instret == 0 || cycles < instret || cycles > 200u * instret) RV32_FAIL();
}

int main(void) {
    volatile unsigned int *m = RV32_SDRAM;
    volatile unsigned int sink = 0;
    unsigned int acc = 1;
    struct sample s;

    for (unsigned int polls = 0; polls < ATTACH_POLLS && !HOST_ATTACHED(*UART_STATUS); polls++) {
    }
    for (unsigned int i = 0; i < N; i++) m[i] = i * 3u + 1u;

    s = begin();                                   // integers: addi, add, xor, bne
    for (unsigned int i = 0; i < N; i++) acc = (acc + i) ^ (acc >> 3);
    sink = acc;
    finish("int-loop", s);

    s = begin();                                   // multiplication
    for (unsigned int i = 1; i <= N / 4; i++) acc = acc * i + 7u;
    sink = acc;
    finish("multiply", s);

    s = begin();                                   // division
    for (unsigned int i = 1; i <= N / 4; i++) acc = (acc | 0x10000u) / (i + 2u);
    sink = acc;
    finish("divide", s);

    s = begin();                                   // word loads from the SDRAM
    for (unsigned int i = 0; i < N; i++) acc += m[i];
    sink = acc;
    finish("sdram-load", s);

    s = begin();                                   // byte stores to the SDRAM
    for (unsigned int i = 0; i < N; i++) ((volatile unsigned char *)m)[N * 4 + i] = (unsigned char)i;
    finish("sdram-byte-store", s);

    (void)sink;
    RV32_PASS();
}
