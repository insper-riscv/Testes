# Guia de Contribuição

🌐 [Português](CONTRIBUTING.md) · [English](CONTRIBUTING.en.md)

Este documento define as regras obrigatórias de codificação, organização estrutural, documentação e verificação para qualquer contribuição ao repositório `Testes`.

## 1. Normas C (C23)

Todo código C do projeto (programas de teste, runtime e fixtures) é escrito sob a norma **ISO/IEC 9899:2024 (C23)** e compilado com `-std=c23`, nunca com `-std=gnu23` nem com extensões do compilador que dispensem a norma.

| Regra | Especificação |
| :--- | :--- |
| Norma da linguagem | C23 (`-std=c23`, nunca `-std=gnu23`) em todos os arquivos `.c` e `.h`; o `riscv-tools` passa a flag em toda compilação |
| Avisos | `-Wall -Wextra -Wpedantic -Werror`, passados pelo `riscv-tools` em toda compilação; nenhum aviso é aceito |
| Ambiente de execução | Hospedado, com a picolibc: os programas compilam com o `--specs` da plataforma, sem `-ffreestanding`, e o `main` retorna ao crt0, que chama `exit` |
| Cabeçalhos | A norma garante em ambiente freestanding só `<float.h>`, `<iso646.h>`, `<limits.h>`, `<stdalign.h>`, `<stdarg.h>`, `<stdbit.h>`, `<stdbool.h>`, `<stddef.h>`, `<stdint.h>` e `<stdnoreturn.h>` (cláusula 4); `<stdio.h>` e `<stdlib.h>` vêm da picolibc e só os programas que testam a biblioteca os incluem |
| Tipos de largura fixa | `<stdint.h>` (`uint32_t`, `int32_t`, `uintptr_t`) em vez de `int`, `unsigned` e `long` sempre que a largura importa; `int` fica para contadores e códigos de retorno |
| Palavras-chave de C23 | Usar `bool`, `true`, `false`, `nullptr`, `constexpr`, `alignas`, `static_assert` sem mensagem e `typeof`; não incluir `<stdbool.h>` nem `<stdalign.h>` e não usar `NULL` |
| Atributos | Sintaxe padrão `[[nodiscard]]`, `[[maybe_unused]]`, `[[noreturn]]`, `[[fallthrough]]` e `[[deprecated]]` no lugar de `__attribute__`; `alignas(n)` no lugar de `aligned(n)`; `[[gnu::noinline]]` e `[[gnu::weak]]` só onde a norma não tem equivalente, com um comentário que diga o motivo |
| Constantes | `static constexpr` com tipo de largura fixa no lugar de `#define` numérico; `enum : uint32_t` para grupos de máscaras e endereços; literais binários (`0b1010`) e separadores (`1'000'000`) são permitidos |
| `#define` que permanece | Só onde um `.S` ou um `#if` lê o valor, onde o ponteiro aponta para um endereço fixo (o `constexpr` de ponteiro aceita só o ponteiro nulo, cláusula 6.7.2) ou onde o arquivo é gerado; cada um traz um comentário com o motivo |
| Nomenclatura | Identificadores em **inglês** com `snake_case`, constantes e macros em `UPPER_SNAKE_CASE`, tipos com sufixo `_t`; sem aliases de `<stdint.h>` (como `u32`) e sem nomes que o POSIX reserva (como `LINE_MAX`); comentários em **português** |
| Comentários | Cada função, variável global, constante e macro recebe um comentário descritivo em português imediatamente acima da declaração |

### 1.1. Comportamento que a norma não define

| Tema | Regra |
| :--- | :--- |
| Registradores MMIO | O endereço é uma constante inteira convertida em ponteiro `volatile` da largura do registrador (cláusulas 6.3.3.3 e 6.7.4.1), sempre alinhado a essa largura, numa macro ou numa função `static inline` única por registrador |
| Acesso desalinhado | Indefinido em C; um teste que mede o acesso desalinhado o faz por instrução explícita (`lw`, `sw`) em `__asm__ volatile`, nunca por ponteiro |
| Deslocamentos | Contagem negativa ou maior ou igual à largura é indefinida (cláusula 6.5.8); o `>>` de valor negativo é definido pela implementação e só aparece em teste que mede a instrução `sra`, com comentário que cite a cláusula; os demais deslocamentos usam operando sem sinal |
| Alias e tipo efetivo | Só os tipos caractere acessam qualquer objeto (cláusula 6.5.1); leituras de meia palavra sobre dado escrito como palavra passam por instrução explícita (`lh`, `lhu`, `sh`) |
| Escrita em objeto `const` | Indefinida (cláusula 6.7.4.1); o teste que precisa de uma escrita na FLASH faz a escrita por instrução explícita e lê de volta por ponteiro `volatile` |
| Ponteiro para função | A conversão passa por `uintptr_t`, que a implementação define (cláusula 6.3.3.3); a conversão direta de ponteiro para objeto em ponteiro para função não é definida |
| Subtração de ponteiros | Só entre elementos do mesmo vetor (cláusula 6.5.7); o tamanho de um bloco de código ou de dados vem de uma constante, não da diferença de dois símbolos |
| `alignas` e `static_assert` | `alignas(n)` fixa o alinhamento (cláusula 6.7.6); todo deslocamento de estrutura que o assembly lê por posição fixa tem um `static_assert` com `offsetof` (cláusulas 6.7.12 e 7.21) |

### 1.2. Extensões do compilador

Nenhuma flag do GCC proíbe `__attribute__`, `__asm__` ou `__builtin_*`, então a revisão confere o que a norma não cobre. A única extensão aceita é o `__asm__`, porque `asm` não é palavra-chave da norma (cláusula 6.4.2) e `__asm__` não conflita com `-std=c23`; ele fica restrito a instruções que o C não expressa (leitura de CSR, `fence.i`, `lh`, `lhu`, `sh`, `lw` e `sw` que o teste mede) e à rotina de atualização da FLASH, sempre com um comentário. Os atributos `[[gnu::...]]`, o `__strong_reference` do runtime e os `__builtin_*` só entram com um comentário que diga por que a norma não oferece equivalente; para o fim de caminho inalcançável, usar `unreachable()` de `<stddef.h>`.

A norma de referência é a [ISO/IEC 9899:2024](https://www.iso.org/standard/82075.html). Em trabalhos acadêmicos, cite-a com a entrada BibTeX abaixo:

```bibtex
@misc{iso9899,
  title        = {Information technology, Programming languages, C},
  author       = {{ISO/IEC}},
  year         = {2024},
  note         = {ISO/IEC 9899:2024 (C23)},
  howpublished = {\url{https://www.iso.org/standard/82075.html}}
}
```

## 2. Normas Python

| Regra | Especificação |
| :--- | :--- |
| Gerenciador | `uv` (`uv add`, `uv sync`, `uv run`); `pip`, `pip install` e `python -m pip` são proibidos |
| Testes | `pytest`; todo comportamento novo acompanha um teste |
| Documentação de código | Docstrings no estilo NumPy em módulos, classes e funções públicas |
| Tipagem | Anotações completas, verificadas pelo Pyright em modo `strict` |
| Estilo e qualidade | `ruff` para lint e formatação; `deptry` para dependências declaradas e usadas |
| Nomenclatura | Identificadores em **inglês** com `snake_case`; comentários e docstrings em **português** |

## 3. Regras de Documentação Markdown

Todo `README` e todo `CONTRIBUTING` e `AUTHORS` mantêm versões espelhadas em português (`*.md`) e em inglês (`*.en.md`), obedecendo às seguintes regras:

1. **Seletor de idioma e rodapé de licença:** todo `README.md` e `README.en.md` traz no topo o seletor `🌐 [Português](...) · [English](...)`, e todo arquivo `.md` encerra com o rodapé de copyright e link para `LICENSE`.
2. **Seções numeradas e progressivas:** todas as seções a partir de `##` devem ser numeradas (`## 1.`, `### 1.1.`, `## 2.`) em ordem lógica de leitura.
3. **Pontuação direta:**
   - **Proibido o uso de travessão** em prosa ou tabelas; utilize vírgula, parênteses, ponto e vírgula ou dois-pontos conforme a relação sintática real.
   - **Proibidos dois-pontos encadeados** (mais de um `:` na mesma frase ou célula de tabela).
4. **Explicação de comportamento:** nunca cite o nome de um arquivo, módulo ou sinal interno como se o próprio nome explicasse o que o sistema faz; descreva sempre a operação realizada.
5. **Tabelas e LaTeX sem redundância:** dados estruturados devem estar em tabelas Markdown e expressões matemáticas/lógicas em blocos LaTeX (`$$ ... $$` ou `$ ... $`), sem repetir em prosa o que a tabela ou equação já enuncia.
6. **Sem histórico ou pendências na documentação técnica:** documentos de arquitetura e contratos descrevem exclusivamente o estado atual, sem changelogs internos nem listas de tarefas futuras.
7. **Guias de uso apenas instruem:** instruções de instalação e execução dizem como fazer, sem justificar a escolha do método.

## 4. Verificação Obrigatória Antes de Abrir Pull Request

Qualquer alteração em código, configuração ou documentação deve passar sem erros pelos comandos abaixo antes do envio:

```bash
uv run riscv-tools --config tools/riscv_build/config.yaml compile --emit hex  # Compila todos os programas de teste
uv run riscv-tools --config tools/riscv_build/config.yaml sim                 # Executa a suíte de simulação
uv run riscv-tools --root . check-tree --kind tests                           # Árvore do repositório
uv run python -m unittest discover -s tests/host                              # Testes do host (harness, runner, regressão e cabeçalhos)
make check-headers                                                            # Cada rv32_platform.h contra o platform.yaml
```

O job `tree`, de um workflow à parte, confere a árvore do repositório com `riscv-tools check-tree`.

Ao adicionar, renomear ou remover qualquer arquivo versionado, atualize imediatamente:
- `tools/riscv_build/config.yaml`
- `docs/`
- `README.md`, `README.en.md` e a documentação afetada

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](LICENSE).
