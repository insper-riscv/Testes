// RV32_EXT: M
// RV32_TEST_KIND: memory
//
// A misaligned access that crosses a word runs in two steps. When the two words sit in two lines of the data cache,
// the lines may be present or absent independently, and with a write-back cache the first line may be dirty: each
// combination has to give the data an aligned access would give. The buffer is 4 KB aligned, so an address 4 KB
// above one of its lines has the same index and another tag and evicts it. The first word crosses at the end of
// line 0 and the second one starts line 1.
#include "rv32_platform.h"

    .section .text
    .globl main

    # Fills the buffer with the pattern, then leaves the lines in the state the case asks for.
    # present(x) reads a word of the line; evict(x) reads the word 4 KB above, which replaces it.
    .macro fill
    li   x6, 0x44F6A577
    sw   x6, 0(x14)
    li   x6, 0x00112233
    sw   x6, 4(x14)
    li   x6, 0x8899AABB
    sw   x6, 8(x14)
    li   x6, 0xCCDDEEFF
    sw   x6, 12(x14)
    li   x6, 0x01234567
    sw   x6, 16(x14)
    li   x6, 0x89ABCDEF
    sw   x6, 20(x14)
    li   x6, 0xFEDCBA98
    sw   x6, 24(x14)
    li   x6, 0x76543210
    sw   x6, 28(x14)
    .endm
    .macro present line
    lw   x6, \line*16(x14)
    .endm
    .macro evict line
    lw   x6, \line*16(x19)
    .endm

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE
    li   x14, 0x40300000        # x14 = the buffer, 4 KB aligned, in the SDRAM
    li   x19, 0x1000
    add  x19, x19, x14            # x19 = the same lines one tag above
    li   x15, 0xA1B2C3D4          # value of the stores

    # load crossing, line 0 present and line 1 absent
    fill
    present 0
    evict 1
    lw   x10, 13(x14)
    sw   x10, 0(x5)
    lw   x11, 12(x14)
    sw   x11, 4(x5)
    lw   x12, 16(x14)
    sw   x12, 8(x5)

    # load crossing, line 0 absent and line 1 present
    fill
    evict 0
    present 1
    lw   x10, 14(x14)
    sw   x10, 12(x5)
    lw   x11, 12(x14)
    sw   x11, 16(x5)
    lw   x12, 16(x14)
    sw   x12, 20(x5)

    # load crossing, both lines absent
    fill
    evict 0
    evict 1
    lw   x10, 15(x14)
    sw   x10, 24(x5)
    lw   x11, 12(x14)
    sw   x11, 28(x5)
    lw   x12, 16(x14)
    sw   x12, 32(x5)

    # load crossing, both lines present
    fill
    present 0
    present 1
    lw   x10, 13(x14)
    sw   x10, 36(x5)
    lw   x11, 12(x14)
    sw   x11, 40(x5)
    lw   x12, 16(x14)
    sw   x12, 44(x5)

    # lh crossing from line 0 into line 1, line 0 present and line 1 absent
    fill
    present 0
    evict 1
    lh   x10, 15(x14)
    sw   x10, 48(x5)

    # the first line holds a store the memory has not seen (dirty in a write-back cache), line 1 absent
    fill
    present 0
    evict 1
    li   x6, 0x5A6B7C8D
    sw   x6, 12(x14)
    lw   x10, 13(x14)
    sw   x10, 52(x5)
    lw   x11, 12(x14)
    sw   x11, 56(x5)

    # store crossing, line 0 present and line 1 absent
    fill
    present 0
    evict 1
    sw   x15, 13(x14)
    lw   x10, 12(x14)
    sw   x10, 60(x5)
    lw   x11, 16(x14)
    sw   x11, 64(x5)
    lw   x12, 13(x14)
    sw   x12, 68(x5)

    # store crossing, line 0 absent and line 1 present
    fill
    evict 0
    present 1
    sw   x15, 14(x14)
    lw   x10, 12(x14)
    sw   x10, 72(x5)
    lw   x11, 16(x14)
    sw   x11, 76(x5)
    lw   x12, 14(x14)
    sw   x12, 80(x5)

    # store crossing, both lines absent
    fill
    evict 0
    evict 1
    sw   x15, 15(x14)
    lw   x10, 12(x14)
    sw   x10, 84(x5)
    lw   x11, 16(x14)
    sw   x11, 88(x5)
    lw   x12, 15(x14)
    sw   x12, 92(x5)

    # store crossing, both lines present
    fill
    present 0
    present 1
    sw   x15, 13(x14)
    lw   x10, 12(x14)
    sw   x10, 96(x5)
    lw   x11, 16(x14)
    sw   x11, 100(x5)
    lw   x12, 13(x14)
    sw   x12, 104(x5)

    # sh crossing from line 0 into line 1, both lines absent
    fill
    evict 0
    evict 1
    sh   x15, 15(x14)
    lw   x10, 12(x14)
    sw   x10, 108(x5)
    lw   x11, 16(x14)
    sw   x11, 112(x5)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
