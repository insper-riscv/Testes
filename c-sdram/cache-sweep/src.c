// RV32_TEST_KIND: unit
#include "rv32_test.h"
#include "rv32_sdram.h"

// Sweeps larger than the 4 KB data cache, so every line is evicted and filled again: write a pattern
// over 16 KB, read it back, rewrite it with another pattern, and read at strides that put two lines on
// the same cache index. A word that the cache loses, keeps stale, or puts in another line shows up.

#define WORDS 4096u

int main(void) {
    volatile unsigned int *m = RV32_SDRAM;

    for (unsigned int i = 0; i < WORDS; i++) m[i] = rv32_sdram_data(i);
    for (unsigned int i = 0; i < WORDS; i++) {
        if (m[i] != rv32_sdram_data(i)) RV32_FAIL(1);
    }

    // rewrite every other word: stores that hit lines in the cache and stores that miss, interleaved
    for (unsigned int i = 0; i < WORDS; i += 2) m[i] = ~rv32_sdram_data(i);
    for (unsigned int i = 0; i < WORDS; i++) {
        unsigned int want = (i & 1u) ? rv32_sdram_data(i) : ~rv32_sdram_data(i);
        if (m[i] != want) RV32_FAIL(2);
    }

    // two words 4 KB apart share a cache index: alternate between them
    for (unsigned int k = 0; k < 64; k++) {
        unsigned int a = k * 4u, b = a + 1024u;          // 1024 words = 4 KB
        m[a] = 0xA0000000u | k;
        m[b] = 0xB0000000u | k;
        if (m[a] != (0xA0000000u | k)) RV32_FAIL(3);
        if (m[b] != (0xB0000000u | k)) RV32_FAIL(4);
        if (m[a] != (0xA0000000u | k)) RV32_FAIL(5);
    }

    // byte and halfword stores into lines that are in the cache
    volatile unsigned char *bytes = (volatile unsigned char *)RV32_SDRAM;
    for (unsigned int i = 0; i < 256; i++) bytes[i] = (unsigned char)i;
    for (unsigned int i = 0; i < 256; i++) {
        if (bytes[i] != (unsigned char)i) RV32_FAIL(6);
    }

    RV32_PASS();
}
