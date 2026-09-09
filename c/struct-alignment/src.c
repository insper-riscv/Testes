// RV32_TEST_KIND: unit
#include "rv32_test.h"
#include <stdint.h>

typedef uint32_t u32;
typedef uint16_t u16;
typedef uint8_t u8;

typedef struct {
    u8 a;
    u16 b;
    u32 c;
    u8 d;
} Greater;

typedef struct {
    u32 a;
    u16 b;
    u8 c;
    u8 d;
} Lesser;

int main(void) {
    volatile u32 size_lesser = sizeof(Lesser);
    volatile u32 size_greater = sizeof(Greater);

    if (size_lesser != 8 || size_greater != 12) RV32_FAIL();

    RV32_PASS();
}
