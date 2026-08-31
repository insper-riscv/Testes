# Bug: PLL nunca se recupera de perda de lock (só power-cycle resolve)

## Sintoma

Mesmo com `jtagconfig` mostrando a placa saudável (`02B050DD 5CE(BA4|FA4)`),
operações de leitura/escrita via JTAG no In-System Memory Content Editor
(`riscv-tools run`, `write_rom`, `mailbox.read_mailbox`) continuam falhando
ou nunca respondendo — "no mailbox result after 15.0s", `quartus_stp`
travando indefinidamente, ou "No editable memory instance was found". Só um
power-cycle físico da placa resolve; reprogramar (`quartus_pgm`, mesmo
`.sof`) sozinho, sem power-cycle, não resolve.

Esse é um sintoma **diferente** do bug já documentado em
[HARDWARE_PROGRAMMING.md](../HARDWARE_PROGRAMMING.md) ("Can't scan JTAG
chain" logo após um `quartus_sh --flow compile` seguido de `quartus_pgm`
lançados como duas chamadas Python separadas) — aqui `jtagconfig` continua
enxergando o chip normalmente, o problema é mais profundo.

## Por que `jtagconfig` OK não significa que a leitura da mailbox vai funcionar

São duas camadas de JTAG completamente diferentes:

1. **TAP JTAG básico** (o que `jtagconfig` escaneia): um bloco de hardware
   fixo, dedicado, sempre presente no chip — existe justamente para
   continuar respondendo mesmo se o design do usuário estiver quebrado,
   travado ou nem sequer configurado. Não depende de nenhum clock interno
   do design.
2. **In-System Memory Content Editor** (o que `read_words.tcl`/
   `write_full.tcl`/`write_word.tcl` usam de verdade, via
   `begin_memory_edit`/`update_content_to_memory_from_file`): passa por um
   "hub" de debug **embutido na própria fabric do usuário**
   (`ENABLE_RUNTIME_MOD=YES` gera essa infraestrutura), que só responde se
   a lógica do design — e os clocks que a alimentam — estiverem realmente
   rodando.

`jtagconfig` saudável só garante a camada 1. A camada 2 pode estar morta
mesmo assim, se o design interno estiver preso (ex: em reset permanente).

## Investigação

`core_fpga_test.vhd` deriva todos os clocks do design (`pll_clk_if`,
`pll_clk_idexmem`, `pll_clk_wb`) de um único PLL, e o `clk` de
`rv32im_pipeline_core` (toda a lógica do pipeline, registradores, RegFile)
usa especificamente `pll_clk_idexmem`:

```vhdl
core_reset <= (not pll_locked) or (not FPGA_RESET_N);
```

Ou seja: se `pll_locked` cair, o core inteiro (e por extensão, tudo que o
hub de debug do In-System Memory Content Editor precisa pra funcionar)
fica em reset. Isso por si só é razoável — o problema é o que vem a
seguir. O log de compilação (`quartus_sh --flow compile`) já vinha
avisando, repetidamente, ignorado até agora:

```
Warning: RST port on the PLL is not properly connected on instance
pll:pll_inst|pll_0002:pll_inst|altera_pll:altera_pll_i|general[0].gpll.
The reset port on the PLL should be connected. If the PLL loses lock for
any reason, you might need to manually reset the PLL in order to
re-establish lock to the reference clock.
```

Conferindo o código: `core_fpga_test.vhd` tinha

```vhdl
pll_inst : entity work.pll
  port map (
    refclk   => CLOCK_50,
    rst      => '0',
    ...
```

`rst` amarrado permanentemente em `'0'` — nunca é pulsado. E a IP do PLL
(`pll.vhd`) foi gerada com `gui_pll_auto_reset value="Off"` — ou seja, essa
IP **não tenta re-travar sozinha** se perder o lock por qualquer motivo
(ruído na alimentação, glitch, o que for). Sem nunca receber um pulso de
`rst`, uma vez que `pll_locked` cai, ela fica presa em "não travado" **pra
sempre**, e por consequência o core inteiro fica em reset pra sempre —
mesmo que o TAP JTAG básico continue perfeitamente saudável (camada 1,
independente disso tudo).

Isso bate exatamente com o padrão observado a sessão toda: retry não
resolve (nada nunca pulsa `rst`), reprogramar sozinho às vezes não resolve
(depende se `quartus_pgm` sozinho força um reset de configuração completo
ou não), e power-cycle sempre resolve (reinicializa tudo, PLL incluso).

## Correção aplicada

```vhdl
pll_inst : entity work.pll
  port map (
    refclk   => CLOCK_50,
    rst      => not FPGA_RESET_N,
    ...
```

Liga o reset do PLL ao botão físico de reset já existente — agora apertar
esse botão também força o PLL a tentar travar de novo, não só segura o
core em reset enquanto `pll_locked` está baixo. Se essa for mesmo a causa
raiz da instabilidade, o botão físico deve passar a bastar para recuperar
o board, sem precisar de power-cycle completo.

## Status: hipótese bem fundamentada, ainda não isolada empiricamente

O código (`rst => '0'` + `gui_pll_auto_reset=Off` + o warning do próprio
Quartus) é evidência real e direta, não especulação — mas ainda não
isolei isso como a **única** causa via um teste controlado (ex:
reproduzir a trava e confirmar que só apertar o botão físico, sem
desligar a placa, recupera). As próximas vezes que o board travar dessa
forma, vale testar o botão de reset físico antes de ir direto pro
power-cycle completo — tanto pra confirmar a hipótese quanto porque, se
certa, é uma recuperação bem mais rápida.

Isso não substitui a regra de `quartus_sh`+`quartus_pgm` em um único
processo de shell — ver [HARDWARE_PROGRAMMING.md](../HARDWARE_PROGRAMMING.md)
— são dois bugs de hardware/plataforma distintos, ambos reais.
