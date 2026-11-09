// RV32_EXT: M,Zifencei
// RV32_TEST_KIND: unit
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include "rv32_platform.h"
#include "rv32_test.h"

// Monitor de comandos no console da UART JTAG.
//
// O programa lê uma linha da UART, ecoa o que lê, executa o comando e responde na UART. Os números são
// hexadecimais, as palavras têm 32 bits e são alinhadas a palavra.
//
//   help                    lista os comandos
//   peek ADDR               mostra a palavra em ADDR
//   poke ADDR VALUE         escreve VALUE na palavra em ADDR
//   dump ADDR N             mostra N palavras a partir de ADDR
//   run ADDR                chama o código em ADDR (uma função que retorna) e mostra o que ela retorna
//   status                  mostra o índice e o estado do último ELF, do registrador do display
//   reset                   reinicia o núcleo pela memória de boot
//   quit                    encerra o programa com PASS (o que uma execução de teste precisa)
//
// Um comando desconhecido ou malformado imprime "error: ..." e o monitor segue; nada que o host envie
// encerra o laço além de `quit`. Na placa, rode o programa e depois converse com ele com
//
//   riscv-tools --config tools/riscv_build/config.sdram.yaml console --interactive
//
// Na simulação o testbench envia o uart_input.txt pela UART e compara tudo o que o programa imprimiu com o
// uart_expected.txt. Sem ninguém na UART o programa termina de uma vez.

// Registradores da UART JTAG e do display. Ficam como macros porque um ponteiro para endereço fixo não pode ser
// constexpr (ISO/IEC 9899:2024, 6.7.2: só o ponteiro nulo); o acesso é volatile (6.7.4.1) e alinhado a palavra.
#define UART_RXDATA ((volatile uint32_t *)0xC0000004u)
#define UART_STATUS ((volatile uint32_t *)0xC0000008u)
#define DISPLAY ((volatile uint32_t *)0xD0000000u)

// Número máximo de leituras do estado à espera do host.
static constexpr uint32_t ATTACH_POLLS = 40000000u;
// Capacidade da linha de comando, com o terminador (não é LINE_MAX, nome que o POSIX usa em <limits.h>).
static constexpr uint32_t LINE_CAPACITY = 64u;
// Número máximo de argumentos de um comando, além do nome.
static constexpr int32_t ARGS_MAX = 3;
// Máximo de palavras que o comando dump mostra.
static constexpr uint32_t DUMP_MAX = 64u;
// Palavras por linha do comando dump.
static constexpr uint32_t DUMP_PER_LINE = 4u;

// Diz se um host está ligado à UART (bit 17 do estado).
static inline bool host_attached(uint32_t status) {
    return ((status >> 17) & 1u) != 0u;
}

// Diz se a palavra lida de rxdata traz um byte válido (bit 8).
static inline bool rx_valid(uint32_t word) {
    return ((word >> 8) & 1u) != 0u;
}

// Imprime a linha de erro com o motivo.
static void print_error(const char *why) {
    printf("error: %s\n", why);
}

// Valor de um dígito hexadecimal, ou -1 se o caractere não é um.
static int32_t hex_digit(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

// Lê um número hexadecimal de até 8 dígitos; devolve verdadeiro se o texto inteiro era um número válido.
static bool parse_hex(const char *text, uint32_t *value) {
    uint32_t result = 0;
    int32_t digits = 0;
    for (; *text; text++) {
        int32_t d = hex_digit(*text);
        if (d < 0 || digits == 8) return false;
        result = (result << 4) | (uint32_t)d;
        digits++;
    }
    *value = result;
    return digits > 0;
}

// Compara duas cadeias; devolve verdadeiro se são iguais.
static bool same(const char *a, const char *b) {
    while (*a && *a == *b) {
        a++;
        b++;
    }
    return *a == *b;
}

// Divide a linha nos espaços, no lugar; devolve quantas palavras achou
static int32_t split(char *line, char *words[ARGS_MAX + 1]) {
    int32_t count = 0;
    while (*line) {
        while (*line == ' ') *line++ = '\0';
        if (!*line) break;
        if (count == ARGS_MAX + 1) return count + 1;
        words[count++] = line;
        while (*line && *line != ' ') line++;
    }
    return count;
}

// Lê um endereço de palavra do texto; imprime o erro e devolve falso se for inválido ou desalinhado.
// O acesso desalinhado a uma palavra não é definido pela norma (ISO/IEC 9899:2024, 6.3.3.3), por isso é recusado.
static bool address_argument(const char *text, uint32_t *address) {
    if (!parse_hex(text, address)) {
        print_error("bad number");
        return false;
    }
    if (*address & 3u) {
        print_error("address not word-aligned");
        return false;
    }
    return true;
}

// Mostra `count` palavras a partir de `address`, quatro por linha.
static void command_dump(uint32_t address, uint32_t count) {
    if (count > DUMP_MAX) {
        print_error("at most 40 words");
        return;
    }
    for (uint32_t i = 0; i < count; i++) {
        if (i % DUMP_PER_LINE == 0) printf("%08x:", (unsigned int)(address + 4 * i));
        printf(" %08x", (unsigned int)*(volatile uint32_t *)(uintptr_t)(address + 4 * i));
        if (i % DUMP_PER_LINE == DUMP_PER_LINE - 1 || i == count - 1) printf("\n");
    }
}

// Chama o código em `address` como uma função que retorna int. A conversão de inteiro em ponteiro de função
// tem resultado definido pela implementação (ISO/IEC 9899:2024, 6.3.3.3) e é o objetivo do comando `run`.
static int32_t command_run(uint32_t address) {
    __asm__ volatile("fence.i" ::: "memory");
    return ((int (*)(void))(uintptr_t)address)();
}

// Reinicia o núcleo saltando para o endereço 0, onde fica a memória de boot. O endereço passa por uma variável
// volátil para que a conversão seja a de um inteiro em tempo de execução e não a de uma constante de ponteiro
// nulo, que não pode ser chamada.
[[noreturn]] static void command_reset(void) {
    volatile uintptr_t boot_rom = 0u;
    ((void (*)(void))boot_rom)();
    unreachable();
}

// Imprime a lista de comandos.
static void command_help(void) {
    puts("help | peek A | poke A V | dump A N | run A | status | reset | quit");
}

// Executa uma linha de comando; devolve verdadeiro para quit
static bool execute(char *line) {
    char *w[ARGS_MAX + 1];
    uint32_t a = 0, v = 0;
    int32_t n = split(line, w);
    if (n == 0) return false;
    if (n > ARGS_MAX) {
        print_error("too many words");
    } else if (same(w[0], "help") && n == 1) {
        command_help();
    } else if (same(w[0], "peek") && n == 2) {
        if (address_argument(w[1], &a)) {
            printf("%08x: %08x\n", (unsigned int)a, (unsigned int)*(volatile uint32_t *)(uintptr_t)a);
        }
    } else if (same(w[0], "poke") && n == 3) {
        if (address_argument(w[1], &a)) {
            if (parse_hex(w[2], &v)) *(volatile uint32_t *)(uintptr_t)a = v;
            else print_error("bad number");
        }
    } else if (same(w[0], "dump") && n == 3) {
        if (address_argument(w[1], &a)) {
            if (parse_hex(w[2], &v)) command_dump(a, v);
            else print_error("bad number");
        }
    } else if (same(w[0], "run") && n == 2) {
        if (address_argument(w[1], &a)) printf("returned %08x\n", (unsigned int)command_run(a));
    } else if (same(w[0], "status") && n == 1) {
        uint32_t d = *DISPLAY;
        printf("index %02x state %04x\n", (unsigned int)((d >> 16) & 0xFFu), (unsigned int)(d & 0xFFFFu));
    } else if (same(w[0], "reset") && n == 1) {
        puts("reset");
        command_reset();
    } else if (same(w[0], "quit") && n == 1) {
        return true;
    } else {
        print_error("unknown command or wrong arguments");
    }
    return false;
}

// O próximo byte da UART, ou -1 quando não há nenhum
static int32_t read_byte(void) {
    uint32_t word = *UART_RXDATA;
    return rx_valid(word) ? (int32_t)(word & 0xFFu) : -1;
}

// Espera o host, lê linhas da UART, executa cada comando e termina em quit.
int main(void) {
    char line[LINE_CAPACITY];
    uint32_t length = 0;
    bool discarding = false;

    for (uint32_t polls = 0; polls < ATTACH_POLLS && !host_attached(*UART_STATUS); polls++) {
    }
    if (!host_attached(*UART_STATUS)) RV32_PASS();

    puts("monitor ready");
    for (;;) {
        int32_t c = read_byte();
        if (c < 0) continue;
        if (c == '\r' || c == '\n') {
            putchar('\n');
            if (discarding) {
                print_error("line too long");
            } else {
                line[length] = '\0';
                if (execute(line)) break;
            }
            length = 0;
            discarding = false;
        } else if (c == 0x08 || c == 0x7F) {
            if (length > 0 && !discarding) length--;
        } else if (!discarding) {
            if (length == LINE_CAPACITY - 1) {
                discarding = true;
            } else {
                line[length++] = (char)c;
                putchar(c);
            }
        }
    }
    puts("bye");
    RV32_PASS();
}
