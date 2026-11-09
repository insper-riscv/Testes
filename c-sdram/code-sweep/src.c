// RV32_TEST_KIND: unit
#include <stdint.h>

#include "rv32_test.h"

// Código maior que a cache de instruções de 4 KB, executado várias vezes: 16 KB de instruções em linha reta,
// cada passada despeja as linhas que a anterior encheu, e o resultado tem de ser o mesmo todas as vezes.

// Blocos de texto assembly: 1, 4, 16, 64, 256 e 1024 instruções addi seguidas.
#define I1 "addi %0, %0, 1\n\t"
#define I4 I1 I1 I1 I1
#define I16 I4 I4 I4 I4
#define I64 I16 I16 I16 I16
#define I256 I64 I64 I64 I64
#define I1024 I256 I256 I256 I256

// Executa 4096 addi em linha reta sobre x e devolve x. A norma não tem atributo para proibir o inlining
// (ISO/IEC 9899:2024, 6.7.13.1 deixa os atributos com prefixo à implementação), então o teste usa
// [[gnu::noinline]], necessário para que o corpo exista uma só vez e ocupe 16 KB de código.
[[gnu::noinline]] static uint32_t run(uint32_t x) {
    __asm__ volatile (I1024 I1024 I1024 I1024 : "+r"(x));
    return x;
}

// Chama run quatro vezes e confere que cada passada soma 4096.
int main(void) {
    uint32_t x = 0;
    for (uint32_t pass = 1; pass <= 4; pass++) {
        x = run(x);
        if (x != pass * 4096u) RV32_FAIL(pass);
    }
    RV32_PASS();
}
