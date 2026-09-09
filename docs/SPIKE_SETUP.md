# Configurando o Spike (golden_generator)

Pré-requisitos pra `golden_generator.setup()` conseguir compilar o Spike
(`vendor/riscv-isa-sim`) e pro `uv` rodar os comandos do projeto. Ver
[QUARTUS_INSTALL.md](QUARTUS_INSTALL.md) e [RUNNER_SETUP.md](RUNNER_SETUP.md)
pros outros pré-requisitos (Quartus, runner do CI).

## 1. `uv` — instalar globalmente

Via o instalador oficial (`https://astral.sh/uv/install.sh`), apontado pra
`/usr/local/bin` em vez do padrão `~/.local/bin` — assim fica disponível pra
qualquer usuário da máquina, sem precisar de PATH extra (`/usr/local/bin` já
está no `PATH` padrão de todo mundo).

```bash
curl -LsSf https://astral.sh/uv/install.sh -o /tmp/uv-install.sh
chmod +x /tmp/uv-install.sh
sudo UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 /tmp/uv-install.sh
rm /tmp/uv-install.sh
```

- Baixa o script primeiro em vez de `curl | sudo sh` direto — dá pra
  inspecionar antes de rodar como root.
- O instalador baixa um binário pré-compilado (não compila nada) e confere
  o SHA256 contra um hash fixo no próprio script antes de instalar.
- `UV_NO_MODIFY_PATH=1`: não precisa mexer em `~/.bashrc` de ninguém, já que
  `/usr/local/bin` já está no `PATH`.

Verificar:
```bash
which uv        # /usr/local/bin/uv
uv --version
```

## 2. Dependências `apt` pro build do Spike

`golden_generator.setup()` clona e compila `riscv-isa-sim` (Spike) a partir
do código-fonte na primeira vez que é chamado. `./configure` do Spike
**falha sem `device-tree-compiler`**; os pacotes do Boost evitam um `make`
mais lento/com warnings.

```bash
sudo apt-get install -y device-tree-compiler libboost-regex-dev libboost-system-dev
```

Uso os dois pacotes específicos do Boost (o mesmo conjunto mínimo que
`sim.yml`/`certification.yml` instalam em CI) em vez do
`libboost-all-dev` mais genérico que aparece em
`tools/Tools/docs/generating-a-golden.md` — mesmo resultado, sem puxar a
suíte Boost inteira.

**Conferido contra o [README oficial do `riscv-isa-sim`](https://github.com/riscv-software-src/riscv-isa-sim)**
(via GitHub, sem clonar o repo inteiro) — ele pede exatamente esses três
pacotes pra Linux/apt (`device-tree-compiler`, `libboost-regex-dev`,
`libboost-system-dev`), então a lista acima está completa.

Verificar o que já está instalado antes de rodar o `apt-get install`:
```bash
dpkg -s device-tree-compiler libboost-regex-dev libboost-system-dev
```

## 3. Compilar o Spike no cache global (`/opt/riscv-foundation`)

Dá pra rodar como qualquer usuário no grupo `runner` (dono do cache fica
esse usuário — ver [RUNNER_SETUP.md](RUNNER_SETUP.md), Fase 5) ou como o
próprio usuário `runner` (dono fica `runner:runner`, igual ao cache do GCC
`riscv32-elf`) — rodar como `runner` é o recomendado, pra manter o dono
consistente entre os dois caches. Precisa rodar a partir de algum checkout
do repositório que `runner` consiga ler — o home de um usuário comum
normalmente não serve, já que `runner` não consegue atravessar um `/home/*`
com permissão `750` sem estar no grupo dono dele.

O `actions/checkout` de um job do GitHub Actions cria automaticamente um
checkout em `/opt/actions-runner/_work/<repo>/<repo>` (substitua `<repo>`
pelo nome do repositório) — mas só depois que **algum job já rodou** nesse
runner para esse repositório; num runner recém-configurado, esse diretório
ainda não existe. Confira antes de usá-lo:

```bash
ls /opt/actions-runner/_work/<repo>/<repo>/pyproject.toml 2>&1
```

Se existir, rode direto dali:
```bash
sudo -u runner HOME=/opt/actions-runner bash -lc '
  cd /opt/actions-runner/_work/<repo>/<repo>
  RISCV_ISA_SIM_DIR=/opt/riscv-foundation/riscv-isa-sim uv run python -c "from riscv_tools import golden_generator; golden_generator.setup()"
'
```

Se ainda não existir (nenhum job rodou nesse runner ainda), ou clona um
checkout à parte que `runner` já é dono por construção:
```bash
sudo -u runner HOME=/opt/actions-runner bash -lc '
  git clone --recurse-submodules <url-do-repo> /opt/actions-runner/tmp-checkout
  cd /opt/actions-runner/tmp-checkout
  RISCV_ISA_SIM_DIR=/opt/riscv-foundation/riscv-isa-sim uv run python -c "from riscv_tools import golden_generator; golden_generator.setup()"
'
```

O `HOME=/opt/actions-runner` explícito é uma rede de segurança: se o
`/etc/passwd` do `runner` não tiver o `HOME` certo (ver a nota na Fase 1 do
[RUNNER_SETUP.md](RUNNER_SETUP.md)), `uv` falha tentando criar cache num
diretório inexistente:
```
error: Failed to initialize cache at `/home/runner/.cache/uv`
  Caused by: failed to create directory `/home/runner/.cache/uv`: Permission denied
```
Passar `HOME=` explícito contorna isso independente da conta estar
corrigida ou não, e não tem efeito colateral se já estiver certa.

- `golden_generator.setup()` (`tools/Tools/src/riscv_tools/golden_generator/setup.py`)
  clona `riscv-isa-sim` direto em `RISCV_ISA_SIM_DIR` (não precisa
  inicializar nenhum submódulo local pra isso), faz checkout do commit
  pinado, e roda `configure && make -j$(nproc)`.
- Não é rápido — compilação real de C++.
- `real.yml` (o workflow de hardware real que roda nesse runner) já usa o
  mesmo `RISCV_ISA_SIM_DIR=/opt/riscv-foundation/riscv-isa-sim`, então o
  binário compilado aqui é reaproveitado pelo CI também — não precisa
  compilar de novo lá.

Verificar depois:
```bash
/opt/riscv-foundation/riscv-isa-sim/build/spike --help
```

## 4. PATH global do GCC RISC-V (conveniência pra terminais interativos)

`/etc/profile.d/quartus.sh` (ver [QUARTUS_INSTALL.md](QUARTUS_INSTALL.md))
só cobre o Quartus. Pra `riscv32-unknown-elf-gcc` também ficar disponível
sem caminho completo em qualquer terminal de qualquer usuário:

```bash
echo 'export PATH="$PATH:/opt/riscv-foundation/riscv32-elf/bin"' | \
  sudo tee /etc/profile.d/riscv-foundation.sh
sudo chmod +x /etc/profile.d/riscv-foundation.sh
```

**Isso só ajuda terminais interativos/login** — `/etc/profile.d/` nunca é
lido por shells não-interativos (automação, scripts chamados via `bash -c`,
o `systemd` do `runner`). Rodar `riscv-tools` manualmente por fora de um
terminal de verdade — inclusive por ferramentas de automação/IA — continua
exigindo o `export PATH=...` explícito documentado no passo 3 acima; é a
mesma razão pela qual `real.yml` seta `$GITHUB_PATH` em vez de confiar no
`profile.d` (ver [RUNNER_SETUP.md](RUNNER_SETUP.md), Fase 4).
