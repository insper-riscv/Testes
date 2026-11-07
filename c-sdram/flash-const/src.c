// RV32_EXT: Zicsr
// RV32_TEST_KIND: unit
#include "rv32_test.h"
#include "rv32_platform.h"

// Constants read from the FLASH, which is a chip behind the caches: aligned and misaligned reads of
// a table in the FLASH, a second pass after the SDRAM traffic evicted the lines, and a store to the
// FLASH, which the core refuses with a store access fault (mcause 7) and the chip never sees (the table must keep its
// value, whether or not its line is cached).

static const unsigned int table[64] = {
    0x00000000u, 0x11111111u, 0x22222222u, 0x33333333u, 0x44444444u, 0x55555555u, 0x66666666u, 0x77777777u,
    0x88888888u, 0x99999999u, 0xAAAAAAAAu, 0xBBBBBBBBu, 0xCCCCCCCCu, 0xDDDDDDDDu, 0xEEEEEEEEu, 0xFFFFFFFFu,
    0x01234567u, 0x89ABCDEFu, 0xFEDCBA98u, 0x76543210u, 0x0F1E2D3Cu, 0x4B5A6978u, 0xA1B2C3D4u, 0xE5F60718u,
    0xDEADBEEFu, 0xCAFEBABEu, 0x8BADF00Du, 0xFEEDFACEu, 0x0BADC0DEu, 0xC0FFEE00u, 0xABCDEF01u, 0x10FEDCBAu,
    0x13579BDFu, 0x2468ACE0u, 0x00FF00FFu, 0xFF00FF00u, 0x0000FFFFu, 0xFFFF0000u, 0x12345678u, 0x87654321u,
    0x5A5A5A5Au, 0xA5A5A5A5u, 0x3C3C3C3Cu, 0xC3C3C3C3u, 0x0F0F0F0Fu, 0xF0F0F0F0u, 0x01010101u, 0x80808080u,
    0x11223344u, 0x55667788u, 0x99AABBCCu, 0xDDEEFF00u, 0x00000001u, 0x00000002u, 0x00000004u, 0x00000008u,
    0x00000010u, 0x00000020u, 0x00000040u, 0x00000080u, 0x00000100u, 0x00000200u, 0x00000400u, 0x00000800u,
};

// Faults taken and the cause of the last one. The handler skips the store that faulted.
static volatile unsigned int faults;
static volatile unsigned int last_cause;

static void __attribute__((interrupt("machine"), aligned(4))) store_fault_handler(void) {
    unsigned int cause, epc;
    __asm__ volatile("csrr %0, mcause" : "=r"(cause));
    __asm__ volatile("csrr %0, mepc" : "=r"(epc));
    last_cause = cause;
    faults++;
    __asm__ volatile("csrw mepc, %0" : : "r"(epc + 4u));
}

static unsigned int checksum(void) {
    unsigned int x = 0;
    for (unsigned int i = 0; i < 64; i++) x = (x << 1 | x >> 31) ^ table[i];
    return x;
}

static unsigned int checksum_bytes(void) {
    const volatile unsigned char *p = (const volatile unsigned char *)table;
    unsigned int x = 0;
    for (unsigned int i = 0; i < sizeof(table); i++) x = (x << 3 | x >> 29) ^ p[i];
    return x;
}

int main(void) {
    unsigned int first = checksum();
    unsigned int first_bytes = checksum_bytes();
    // twice in a row: the second pass hits the data cache
    if (checksum() != first) RV32_FAIL(1);
    if (checksum_bytes() != first_bytes) RV32_FAIL(2);

    // misaligned reads across two words of the FLASH (Zicclsm)
    const volatile unsigned char *p = (const volatile unsigned char *)table;
    for (unsigned int i = 1; i < 4; i++) {
        unsigned int want = (unsigned int)p[4 + i] | (unsigned int)p[5 + i] << 8 |
                            (unsigned int)p[6 + i] << 16 | (unsigned int)p[7 + i] << 24;
        const volatile unsigned int *w = (const volatile unsigned int *)(p + 4 + i);
        if (*w != want) RV32_FAIL(3);
    }

    // evict the data cache with 16 KB of SDRAM traffic, then read the table again
    volatile unsigned int *sweep = (volatile unsigned int *)(RV32_RAM_BASE + 0x00800000u);
    for (unsigned int i = 0; i < 4096; i++) sweep[i] = i;
    unsigned int sum = 0;
    for (unsigned int i = 0; i < 4096; i++) sum += sweep[i];
    if (sum != 4096u * 4095u / 2u) RV32_FAIL(4);
    if (checksum() != first) RV32_FAIL(5);

    // a store to the FLASH is refused with a store access fault and changes nothing, on a line that is cached and on one that is not
    __asm__ volatile("csrw mtvec, %0" : : "r"((unsigned int)&store_fault_handler));
    volatile unsigned int *flash = (volatile unsigned int *)&table[3];
    unsigned int before = *flash;                 // brings the line in
    *flash = 0xFFFFFFFFu;
    if (faults != 1u || last_cause != 7u) RV32_FAIL(10);
    if (*flash != before) RV32_FAIL(6);
    volatile unsigned int *far = (volatile unsigned int *)&table[60];
    unsigned int before_far = *far;
    *far = 0u;
    if (faults != 2u || last_cause != 7u) RV32_FAIL(11);
    if (*far != before_far) RV32_FAIL(7);
    for (unsigned int i = 0; i < 4096; i++) sweep[i] = ~i;   // evict
    if (table[3] != before || table[60] != before_far) RV32_FAIL(8);
    if (checksum() != first) RV32_FAIL(9);

    RV32_PASS();
}
