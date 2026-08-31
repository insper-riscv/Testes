# Bug: pequenos globais `.data` inicializados nunca eram copiados (`.sdata`/`gp`)

## Sintoma

`data-init-byte` (`c/data-init-byte/src.c`) travava por completo contra o
hardware real — não dava PASS nem FAIL, simplesmente nunca escrevia nada na
mailbox (`no mailbox result after 15.0s`). Reproduzido **3 de 3 vezes**,
isolado (`--only data-init-byte --skip-reconfigure`, placa recém-programada,
nenhum outro teste rodando antes), descartando de vez a hipótese de ser mais
um caso do bug de JTAG intermitente já documentado em
[HARDWARE_PROGRAMMING.md](../HARDWARE_PROGRAMMING.md) — aquele quebra a
*conexão* JTAG (`jtagconfig` para de enxergar a placa); este bug faz o
*programa RISC-V* travar, com a JTAG continuando saudável o tempo todo.

O teste em si é propositalmente trivial:

```c
// RV32_TEST_KIND: unit
#include "rv32_test.h"

/* Diagnoses initialization of a one-byte .data object. */
static volatile unsigned char value = 0xA5u;

int main(void) {
    if (value != 0xA5u) RV32_FAIL();
    RV32_PASS();
}
```

## Investigação

Comparando o `.elf` gerado com o mapa de memória esperado:

```bash
riscv32-unknown-elf-nm -S build/real/data-init-byte.elf | grep -E "_data_|value"
```

```
00000000     1 OBJECT  LOCAL  DEFAULT    2 value
00000000     D _data_end
00000000     D _data_start
```

`_data_start` e `_data_end` são **iguais** (`0x00000000` os dois), mesmo
`value` existindo de verdade, com endereço `0x0` e tamanho `1`. O loop de
cópia `.data` do `crt0.S` é:

```asm
    la t0, _data_load
    la t1, _data_start
    la t2, _data_end
1:
    bge t1, t2, 2f      // _data_start >= _data_end → sai IMEDIATAMENTE
    lw  t3, 0(t0)
    sw  t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    j   1b
2:
```

Com `_data_start == _data_end`, o `bge` na primeira iteração já é verdadeiro
— o loop **nunca copia nada**. `value` fica com o que já estava na RAM
(indefinido em hardware real: `crt0.S` documenta explicitamente "RAM starts
blank on real hardware"), não com `0xA5`.

Isso sozinho já explicaria um `RV32_FAIL()` — mas o sintoma real era
**travamento total**, sem nem chegar a escrever FAIL na mailbox. Faltava uma
segunda peça.

### A seção errada

```bash
riscv32-unknown-elf-readelf -S build/real/data-init-byte.elf | grep -E "\.data|\.sdata"
```

```
[ 2] .sdata            PROGBITS        00000000 002000 000001 00  WA  0   0  1
```

`value` não foi parar em `.data` — foi parar em **`.sdata`** (a seção
"small data" do RISC-V). O GCC do RISC-V redireciona globais pequenos
(por padrão, objetos de até 8 bytes) para `.sdata`/`.sbss`, endereçados de
forma relativa ao registrador `gp` (`gp`-relative addressing) em vez de
endereçamento absoluto — uma otimização de tamanho de código padrão da ABI.

O `link.ld` deste projeto só casa `*(.data*)`/`*(.bss*)`:

```ld
.data : {
    _data_start = .;
    *(.data*)          /* não casa .sdata* */
    _data_end = .;
} > RAM AT> ROM
```

`.sdata` não é uma seção "órfã" clássica (o `ld` ainda consegue posicioná-la,
já que `WA` bate com o que `.data`/`.bss` aceitam), mas como não há regra
explícita para ela, o linker a posiciona **depois** que `_data_end` já foi
calculado — na prática, no mesmo endereço onde `.data` "parou" (`0x0`, já
que não havia mais nada em `.data`/`.bss` antes dela nesse teste mínimo).
Resultado: `value` existe fisicamente na imagem, mas fora do range que
`crt0.S` sabe que precisa copiar/zerar.

### Por que trava, e não só falha

`.sdata`/`.sbss` são endereçados via `gp` (`lb rd, offset(gp)` em vez de um
endereço absoluto) — é assim que o RISC-V consegue instruções mais curtas
para esses acessos. Isso só funciona se o registrador `gp` estiver
inicializado corretamente, normalmente apontando para perto do meio da
região `.sdata`/`.sbss` (convenção `__global_pointer$`).

**`crt0.S` nunca inicializa `gp`** — não existe infraestrutura nenhuma pra
isso neste projeto (nunca foi necessário, porque nada usava `.sdata` até um
teste pequeno o suficiente aparecer). Então qualquer acesso `gp`-relative
usa o valor de `gp` como estava no reset — não é "um valor errado", é
**um endereço arbitrário**. Ler/escrever num endereço arbitrário é
comportamento indefinido: pode ler lixo silenciosamente, mas também pode
acessar uma região fora do range válido da RAM/ROM do core (Harvard, sem
MMU, sem tratamento de exceção) e travar o pipeline — o que bate exatamente
com o sintoma observado (trava total, mailbox nunca escrita).

## Correção

**Nota histórica**: a primeira correção tentada aqui foi desabilitar a
geração de small-data inteiramente via `-msmall-data-limit=0` no `gcc`
(`Tools/src/riscv_tools/compiler/build.py`) — simples, mas "simplificado
demais": deixa qualquer objeto pequeno mais lento (sempre endereçamento
absoluto, nunca `gp`-relative) sem resolver a causa raiz. Foi revertida em
favor da correção real abaixo, que segue a ABI oficial do RISC-V em vez de
desviar dela — ver
[psABI doc](https://github.com/riscv-non-isa/riscv-elf-psabi-doc).

A correção definitiva tem duas partes:

**1. Inicializar `gp` de verdade em `crt0.S`**, primeira coisa em `_start`,
antes de qualquer outro `la` (que o assembler/linker podem relaxar para
`gp`-relative se `gp` já estiver "válido" — daí o `.option norelax` em volta):

```asm
.option push
.option norelax
1:  auipc gp, %pcrel_hi(__global_pointer$)
    addi  gp, gp, %pcrel_lo(1b)
.option pop
```

**2. Dar a `.sdata`/`.sbss`/`.srodata` uma regra explícita em `link.ld`**,
dentro do mesmo range que `crt0.S` já sabe copiar/zerar — `*(.data*)`
sozinho não casava essas seções (ver "A seção errada" acima):

```ld
.data : {
    _data_start = .;
    *(.data*)
    . = ALIGN(4);
    PROVIDE(__global_pointer$ = . + 0x800);
    *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2)
    *(.srodata .srodata.*)
    *(.sdata .sdata.* .gnu.linkonce.s.*)
    _data_end = .;
} > RAM AT> ROM

.sbss (NOLOAD) : {
    _bss_start = .;
    *(.dynsbss)
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    *(.scommon)
} > RAM
```

`__global_pointer$` fica em `.sdata`'s início + `0x800` — convenção do
próprio `ld` do RISC-V (imediatos assinados de 12 bits, `gp` alcança
`.data` pra trás e `.sbss` pra frente, ambos dentro do alcance).

Junto com essa correção veio a inicialização equivalente de `tp` (x4) —
mesma classe de bug, nada usa hoje, mas fica pronto — ver
[CRT0_BOOT_REFERENCE.md](CRT0_BOOT_REFERENCE.md).

**Importante**: essa correção sozinha NÃO foi suficiente pra fazer
`data-init-byte` passar — `.sdata` parar de ficar fora do range copiado
resolve *esse* sintoma, mas expôs um bug bem mais fundamental do core (a
ROM nunca era alcançável por um `lw`/`sw`, então mesmo copiando do endereço
certo, o valor lido de lá vinha errado) — ver
[DATA_HARVARD_BUG.md](DATA_HARVARD_BUG.md) pra investigação completa e a
correção de arquitetura que resolveu isso de vez.

## Por que só apareceu agora

O suite de testes original (os 11 splits do `full.S`, `example-add`, etc.)
sempre trabalhou com arrays/estruturas maiores que o limite de small-data
(8 bytes), ou escreveu direto em endereços fixos via assembly — nunca expôs
esse caminho. O bug só ficou visível quando testes novos e propositalmente
minúsculos (`data-init-byte`, `data-init-halfword`) foram adicionados
especificamente para isolar casos de inicialização — o tipo exato de coisa
que esse padrão de otimização do compilador afeta.

## Lição para novos testes

Qualquer global `.data`/`.bss` pequeno (poucos bytes) é candidato a cair em
`.sdata`/`.sbss` se `-msmall-data-limit=0` algum dia for removido ou
sobrescrito. Se isso acontecer de novo, o sintoma será o mesmo: travamento
completo (não uma falha limpa) em testes com poucas variáveis pequenas.
`nm -S`/`readelf -S` no `.elf` gerado (procurando por `.sdata`/`.sbss`, ou
`_data_start == _data_end` com objetos reais em `.data`) é o jeito mais
rápido de confirmar se é isso de novo.
