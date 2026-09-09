# Suporte a `malloc`/`free` (via newlib + um `_sbrk` mínimo)

## Motivação

O merge de `unit_struct_tests` (PR #4) trouxe `c/struct-init-heap/src.c`,
que aloca com `malloc()`. Antes disso nenhum teste do projeto usava heap —
o build sempre passou `-nostdlib` pro gcc, que corta libc **e** libgcc por
completo, então `malloc` simplesmente não existia:

```
undefined reference to `malloc'
```

## O que mudou

### 1. `riscv_tools` (`Tools`, genérico — afeta qualquer projeto que use o pacote)

`compiler.compile_test` não passa mais `-nostdlib` pro gcc, só
`-nostartfiles` (`Tools/src/riscv_tools/compiler/build.py`). A diferença:

- `-nostartfiles` continua cortando o `_start`/crt padrão — o `crt0.S` de
  cada projeto continua sendo o único ponto de entrada, nada muda aí.
- Sem `-nostdlib`, libc (newlib, já vem junto do toolchain
  `riscv32-unknown-elf-gcc`) e libgcc voltam a ser **linkáveis**.

Isso é seguro pra todo teste que já existia: o linker só puxa símbolos que
são **de fato referenciados** — um teste que nunca chama nada de libc
continua exatamente igual, nem um byte a mais no `.elf`. Só passa a puxar
código de verdade quando um teste referencia algo como `malloc`.

Novo hook opcional em `config.yaml`: `paths.syscalls`. Se configurado,
`cli.py` inclui esse arquivo (via `extra_sources`, mesmo mecanismo que já
existia pra linkar `boot_rom.S` no golden do Spike) em **todo** build de
teste, real e sim — ver `_syscalls_sources()` em `cli.py`. Um projeto que
não precisa de heap simplesmente não declara essa chave; nada muda pra ele.

### 2. Este projeto (`Tests`, específico)

`tools/riscv_build/config.yaml` aponta `paths.syscalls` pro novo
`tools/riscv_build/syscalls.c`, que implementa a única syscall que o
`malloc`/`free` da newlib realmente precisam: `_sbrk`.

```c
extern char _bss_end;
extern char _stack_top;

static char *heap_ptr = NULL;

void *_sbrk(ptrdiff_t incr) {
    if (heap_ptr == NULL) heap_ptr = &_bss_end;
    char *prev = heap_ptr;
    if (prev + incr > &_stack_top) return (void *)-1;
    heap_ptr += incr;
    return prev;
}
```

- **Não precisou de símbolo novo no linker script**: `_bss_end` (início do
  heap) e `_stack_top` (limite superior) já existiam em `link.ld`/
  `golden.ld` desde o redesign BOOT_ROM+FLASH (ver
  `docs/MEMORY_ARCHITECTURE.md`).
- O heap cresce **para cima** a partir de `_bss_end`, na mesma região de
  RAM que a pilha ocupa (que cresce **para baixo** a partir de
  `_stack_top`) — `_sbrk` recusa (`(void *)-1`, a convenção POSIX que a
  newlib já checa) qualquer pedido que invadiria esse limite, mas não tem
  como detectar as duas regiões colidindo *no meio* se a pilha crescer
  demais por conta própria — não é um problema novo, é a mesma limitação
  de qualquer alocador bump-pointer simples num ambiente sem MMU.
- Só implementa `_sbrk`: nenhum teste usa `printf`/arquivos/etc, então o
  linker nunca precisa de `_write`/`_read`/`_close`/`_fstat`/`_isatty` —
  se um teste futuro passar a usar stdio, essas vão faltar até serem
  implementadas aqui também.
- Sem reentrância/lock: o core é single-issue, single-core, e cada teste
  roda sozinho do reset até `RV32_PASS()/RV32_FAIL()` — não existe
  concorrência real pra `_sbrk` precisar se preocupar com.

## Como usar num teste novo

Nada de especial — `#include <stdlib.h>` e chama `malloc`/`free` como em
qualquer C hospedado:

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

`struct-init-heap` (antes: erro de link) compila e passa — confirmado
rodando a suíte completa dos dois lados: **84/84 no GHDL sim** e
**84/84 no hardware real**, sem regressão em nenhum teste pré-existente
(o resto do projeto nunca referenciou libc, então nada mudou pra eles).
