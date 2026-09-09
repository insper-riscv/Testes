# Suporte a `malloc`/`free` (alocador próprio, não newlib)

## Motivação

O merge de `unit_struct_tests` (PR #4) trouxe `c/struct-init-heap/src.c`,
que aloca com `malloc()`. Antes disso nenhum teste do projeto usava heap —
o build sempre passou `-nostdlib` pro gcc, que corta libc **e** libgcc por
completo, então `malloc` simplesmente não existia:

```
undefined reference to `malloc'
```

## Primeira tentativa (revertida): linkar contra a newlib de verdade

A ideia óbvia: parar de passar `-nostdlib` (mantendo só `-nostartfiles`,
já que o `crt0.S` de cada projeto continua sendo o ponto de entrada) e
fornecer só a syscall que o `malloc`/`free` da newlib precisam de verdade,
`_sbrk`. Funcionou perfeitamente **local** — e quebrou no CI:

```
ld: .../libc.a(libc_a-malloc.o): can't link double-float modules with soft-float modules
```

### Causa raiz

Baixei exatamente o mesmo release que o CI baixa
(`riscv32-elf-ubuntu-24.04-gcc.tar.xz` do `riscv-collab/riscv-gnu-toolchain`)
e inspecionei o `libc.a` dele com `readelf -A`:

| Toolchain | `Tag_RISCV_arch` do `libc.a` |
|---|---|
| Local (`/home/picow/opt/riscv`) | `rv32i2p1_m2p0_zmmul1p0` (soft-float) |
| CI (release "latest" do riscv-collab) | `rv32i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_..._zcf1p0` (**hard-float**, `ilp32d`) |

Os dois toolchains são builds **single-target** (nenhum multilib — só um
`libc.a`, sem subdiretórios por variante de ISA/ABI), só que apontando pra
alvos diferentes. O da minha máquina local coincide por acaso com
`-march=rv32i -mabi=ilp32` (as flags que este projeto sempre usou, já que
o core não tem FPU nenhuma — `ilp32`, soft-float, é a única ABI que faz
sentido aqui). O release genérico que o `riscv-collab` distribui não tem
essa coincidência.

**Isso não tem conserto por flag**: se o `.a` baixado só tem um variante
hard-float, não existe combinação de `-march`/`-mabi` que faça ele linkar
contra código soft-float — o objeto simplesmente não existe naquele
arquivo. E como o workflow sempre baixa "a última release" (não uma
versão pinada), depender de qual ABI aquele release *por acaso* usa como
padrão é frágil por natureza — pode mudar de novo a qualquer nova release.

## Solução: `malloc`/`free` próprios, sem tocar em `libc.a`

Revertido: `compile_test` voltou a passar `-nostdlib -nostartfiles` (ver
`Tools/src/riscv_tools/compiler/build.py`) — o build nunca mais linka
contra a newlib do toolchain, seja ele qual for. `tools/riscv_build/
syscalls.c` (apontado por `config.yaml`'s `paths.syscalls`, ver
`_syscalls_sources()` em `cli.py`) implementa `malloc`/`free` **direto**,
sem depender de nenhuma syscall (`_sbrk` ou outra) que a newlib precisaria:

```c
extern char _bss_end;
extern char _stack_top;

static char *heap_ptr = NULL;

void *malloc(size_t size) {
    if (heap_ptr == NULL) heap_ptr = &_bss_end;
    size = (size + 3u) & ~(size_t)3u;   // alinha em 4 bytes
    if (heap_ptr + size > &_stack_top) return NULL;
    char *block = heap_ptr;
    heap_ptr += size;
    return block;
}

void free(void *ptr) { (void)ptr; }   // bump allocator, nunca recicla
```

- **Não precisou de símbolo novo no linker script**: `_bss_end` (início do
  heap) e `_stack_top` (limite superior) já existiam em `link.ld`/
  `golden.ld` desde o redesign BOOT_ROM+FLASH (ver
  `docs/MEMORY_ARCHITECTURE.md`).
- Aloca só pra frente (bump pointer), `free()` é no-op — nenhum teste
  deste projeto aloca/libera repetidamente ou depende de reciclar memória
  no meio da execução, então um free-list de verdade seria complexidade
  sem uso real hoje.
- O heap cresce **para cima** a partir de `_bss_end`, na mesma região de
  RAM que a pilha ocupa (que cresce **para baixo** a partir de
  `_stack_top`) — `malloc` recusa (retorna `NULL`) qualquer pedido que
  invadiria esse limite, mas não tem como detectar as duas regiões
  colidindo *no meio* se a pilha crescer demais por conta própria — não é
  um problema novo, é a mesma limitação de qualquer alocador bump-pointer
  simples num ambiente sem MMU.
- `#include <stdlib.h>` num teste continua funcionando normalmente pras
  *declarações* de `malloc`/`free` (o toolchain inclui os headers da
  newlib independente de `-nostdlib` — só a fase de *link* é afetada);
  como o link nunca toca em `libc.a`, essas declarações acabam resolvidas
  pelas nossas próprias definições, sem conflito.
- Sem reentrância/lock: o core é single-issue, single-core, e cada teste
  roda sozinho do reset até `RV32_PASS()/RV32_FAIL()` — não existe
  concorrência real pra `malloc` precisar se preocupar com.

## Como usar num teste novo

Nada de especial — `#include <stdlib.h>` e chama `malloc`/`free` como em
qualquer C hospedado (por baixo dos panos são as nossas próprias
implementações, não as da newlib, mas a interface é idêntica):

```c
// RV32_TEST_KIND: unit
#include "rv32_test.h"
#include <stdlib.h>

int main(void) {
    int *p = malloc(sizeof(int));
    if (p == NULL) RV32_FAIL();
    *p = 42;
    if (*p != 42) RV32_FAIL();
    free(p);
    RV32_PASS();
}
```

## Verificação

`struct-init-heap` compila e passa — confirmado rodando a suíte completa
dos dois lados: **84/84 no GHDL sim** e **84/84 no hardware real**, sem
regressão em nenhum teste pré-existente. Também confirmado que a causa
raiz do problema de CI foi mesmo essa (não outra coisa): baixei o release
exato que o `sim.yml` usa e inspecionei o `libc.a` com `readelf -A` antes
de decidir a solução, em vez de só supor.
