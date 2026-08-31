> **Atualização**: este bug foi corrigido de vez a nível de hardware —
> `.data` com valor inicial não-zero funciona normalmente agora. Ver
> [Correção definitiva: Harvard modificado](#correção-definitiva-harvard-modificado)
> mais abaixo. O resto deste documento (investigação original + a mitigação
> por software que veio antes da correção de hardware) fica como registro
> histórico de como o bug foi encontrado e diagnosticado.

# Bug: `.data` (globais com valor inicial não-zero) não funciona neste core

## Resumo

Este core (`rv32im_pipeline_core`) é uma arquitetura **Harvard de verdade**:
os barramentos de ROM (`rom_addr`) e RAM (`ram_addr`) são fisicamente
independentes, e `lw`/`sw` **nunca** alcançam a ROM — só o *program counter*
(busca de instrução) usa o barramento de ROM. Isso significa que o
mecanismo padrão de `.data` (copiar o valor inicial da ROM pra RAM no boot)
**não pode funcionar de jeito nenhum** neste hardware, independente de
qualquer correção em `crt0.S`/`link.ld`.

Isso **não é uma exigência da ISA RISC-V** — a maioria das implementações
RISC-V (inclusive embarcadas) usa mapa de memória unificado (von Neumann) ou
Harvard "modificado" onde o barramento de dados ainda alcança a região de
programa, permitindo `.data` funcionar normalmente. É uma escolha de design
**específica deste core educacional**, não um limite do padrão.

## Como foi descoberto (investigação completa)

### 1. Sintoma inicial: "travamento"

`data-init-byte` (`c/data-init-byte/src.c`, à época com
`static volatile unsigned char value = 0xA5u;`) reportava
`no mailbox result after 15.0s` — sem PASS, sem FAIL. Reproduzido de forma
consistente (a mesma suíte de 42 testes rodada várias vezes sempre parava
exatamente nesse teste, com todo o resto passando limpo ao redor), o que
descartou coincidência de instabilidade de JTAG (ver
[HARDWARE_PROGRAMMING.md](../HARDWARE_PROGRAMMING.md) pro problema,
diferente, de "chain broken" na etapa de programação).

### 2. `gp`/`.sdata` — correção real, mas não suficiente

A primeira causa encontrada foi um `gp` (global pointer) nunca inicializado
em `crt0.S`, fazendo pequenos globais (`.sdata`, endereçamento
`gp`-relative) ficarem fora do range que o `crt0.S` sabia copiar/zerar — ver
[SMALL_DATA_SECTION_BUG.md](SMALL_DATA_SECTION_BUG.md) e
[CRT0_BOOT_REFERENCE.md](CRT0_BOOT_REFERENCE.md) pra essa correção completa
(que continua válida e necessária — só não era a causa completa deste bug
específico).

Depois de corrigir `gp`/`tp` e adicionar `.sdata`/`.sbss`/`.tdata`/`.tbss` ao
`link.ld`, `data-init-byte` **continuou falhando**, exatamente do mesmo
jeito.

### 3. A pergunta que resolveu: "trava mesmo, ou só a leitura falha?"

Em vez de assumir que era travamento de CPU, a mailbox foi lida **manualmente,
uma única vez**, sem passar pelo loop de polling automático do orquestrador:

```bash
# grava a ROM do teste, pulsa o go-flag, espera, lê a mailbox direto
quartus_stp -t write_full.tcl "USB-Blaster [1-4]" "@1: ..." 0 data-init-byte.mif
quartus_stp -t write_word.tcl "USB-Blaster [1-4]" "@1: ..." 1 4094 1   # go-flag
sleep 5
quartus_stp -t read_words.tcl "USB-Blaster [1-4]" "@1: ..." 1 4095 1  # mailbox
```

Resultado: **mailbox = 2 (FAIL)**. A CPU **não travou** — ela rodou até o
fim e escreveu FAIL corretamente, dado o valor que leu (errado, mas ela não
sabia disso). Ler `RAM[0]` (onde `value` deveria estar) confirmou: `0`, não
`0xA5` — o loop de cópia `.data`→ROM do `crt0.S` copiou lixo (o que já
estava em `RAM[_data_load]`, um endereço reaproveitado por coincidência
numérica do espaço de ROM), não o valor real da ROM.

Isso levou à confirmação no VHDL:

```
# rv32im_pipeline_core.vhd
ram_addr <= exmem_alu_out;
```

`ram_addr` vem **direto** da ALU no estágio EX/MEM — ou seja, de qualquer
`lw`/`sw`. `rom_addr` é uma linha completamente separada, plugada só no
`pc_fetch`. Não existe caminho físico de um `lw`/`sw` até a ROM.

### 4. O bug real do "timeout": polling JTAG demais, rápido demais

Se a CPU não trava, por que o orquestrador reporta timeout? `config.yaml`
tinha `poll_interval_seconds: 0.5` — com um timeout de 15s, isso permite até
**~30 chamadas `quartus_stp` separadas**, cada uma abrindo e fechando sua
própria sessão de JTAG/In-System Memory Editor do zero, em sequência rápida.
Essa é a mesma classe de fragilidade já documentada pro handoff
`quartus_sh`→`quartus_pgm` (ver HARDWARE_PROGRAMMING.md), só que multiplicada
por ~30 tentativas numa janela de 15s em vez de duas tentativas isoladas.

A leitura manual (uma chamada, com folga real de tempo) funcionou de
primeira — confirmando que o volume de chamadas rápidas repetidas, não o
hardware em si, é o que causa a falha de leitura.

## As duas correções aplicadas

1. **`poll_interval_seconds` `0.5` → `2.5`** (`config.yaml`) — menos sessões
   JTAG abertas/fechadas na janela de timeout, trocando latência de
   detecção por confiabilidade de leitura.

2. **Checagem em tempo de compilação** (`Tools/compiler/build.py`,
   `_check_data_section_empty`) — `riscv-tools compile` agora falha
   imediatamente, com mensagem explicando o porquê, se um teste produzir um
   `.data` não-vazio, em vez de deixar rodar e corromper silenciosamente.
   `.bss` (zero-init) continua funcionando normalmente — `crt0.S` zera com
   `sw` puro, sem precisar ler nada da ROM.

## Como escrever um teste que precisa de um valor inicial não-zero

Não use inicializador C em escopo de arquivo:

```c
// ERRADO — vira .data, falha na compilação com este projeto
static volatile unsigned int value = 0xCAFEBABEu;
```

Declare sem inicializador (vira `.bss`, zero-init funciona normalmente) e
atribua dentro de uma função:

```c
// CERTO — vira .bss + uma instrução li/sw normal dentro de main(),
// nunca depende de ler a ROM via lw/sw
static volatile unsigned int value;

int main(void) {
    value = 0xCAFEBABEu;
    if (value != 0xCAFEBABEu) RV32_FAIL();
    RV32_PASS();
}
```

## Testes desativados (`.off`)

Cinco testes existiam especificamente pra verificar que `.data` inicializa
corretamente — `c/data-init-byte`, `c/data-init-halfword`,
`c/data-init-word`, `c/data-init-word-array`, `c/data-initialization`. Como
esse mecanismo é impossível neste hardware (não é um bug a corrigir, é uma
característica do design do core), reescrevê-los pra "atribuir em `main()`"
os faria testar outra coisa completamente (só "consigo escrever/ler uma
variável", redundante com dezenas de outros testes) com um nome enganoso.

Cada pasta tem um arquivo `.off` (conteúdo = motivo, lido e impresso por
`riscv-tools compile`) que faz o discovery de testes pular a pasta
inteiramente, sem apagar o código-fonte original — ver `_discover_tests` em
`Tools/src/riscv_tools/cli.py`. Isso é diferente de simplesmente remover os
testes: o código continua no repositório, versionado, com o motivo exato de
estar desligado registrado ali mesmo, caso o core ganhe suporte a um mapa de
memória unificado no futuro.
