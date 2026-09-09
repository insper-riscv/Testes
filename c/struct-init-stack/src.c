// RV32_TEST_KIND: unit
#include "rv32_test.h"
#include <stdint.h>

typedef uint32_t u32;
typedef int32_t i32;
typedef uint16_t u16;
typedef int16_t i16;
typedef uint8_t u8;
typedef int8_t i8;

typedef struct {
    u32 a;
    i32 b;
    u16 c;
    i16 d;
    u8 e;
    i8 f;
} Test;

int main(void) {
    Test a = { 
        .a = 32,
        .b = -32,
        .c = 16,
        .d = -16,
        .e = 8,
        .f = -8
    };

    if (
        a.a !=  32 ||
        a.b != -32 ||
        a.c !=  16 ||
        a.d != -16 ||
        a.e !=   8 ||
        a.f !=  -8
    ) RV32_FAIL();
    
    if (sizeof(Test) != 16) 
        RV32_FAIL();

    RV32_PASS();    
}
