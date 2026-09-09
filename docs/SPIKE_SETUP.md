# Configurando o Spike (golden_generator) nesta workstation

Pré-requisitos pra `golden_generator.setup()` conseguir compilar o Spike
(`vendor/riscv-isa-sim`) e pro `uv` rodar os comandos do projeto. Ver
[QUARTUS_INSTALL.md](QUARTUS_INSTALL.md) e [RUNNER_SETUP.md](RUNNER_SETUP.md)
pros outros pré-requisitos da máquina (Quartus, runner do CI).

## 1. `uv` — instalado globalmente

Instalado via o instalador oficial (`https://astral.sh/uv/install.sh`),
apontado pra `/usr/local/bin` em vez do padrão `~/.local/bin` — assim fica
disponível pra qualquer usuário da máquina, sem precisar de PATH extra
(`/usr/local/bin` já está no `PATH` padrão de todo mundo).

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

Checado nesta máquina (set/2026) — o que falta instalar:

| Pacote | Status nesta máquina | Pra que serve |
|---|---|---|
| `git`, `curl`, `xz-utils`, `libmpc3`, `build-essential` | ✅ já instalados (desktop normal já traz) | git clone, download, toolchain, compilador C/C++ |
| `device-tree-compiler` | ❌ falta | `./configure` do Spike falha sem ele |
| `libboost-regex-dev` | ❌ falta | dependência de build do Spike |
| `libboost-system-dev` | ❌ falta | dependência de build do Spike |

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
`libboost-system-dev`), então a lista acima está completa, não falta nada.

## 3. Compilar o Spike no cache global (`/opt/riscv-foundation`)

Dá pra rodar como `hix` (dono fica `hix`, já que `hix` está no grupo
`runner` — ver [RUNNER_SETUP.md](RUNNER_SETUP.md), Fase 5) ou como o
próprio usuário `runner` (dono fica `runner:runner`, igual ao cache do GCC
`riscv32-elf`) — este projeto usa a segunda opção, rodando a partir do
checkout que o próprio runner já mantém em
`/opt/actions-runner/_work/Testes/Testes` (o seu `~/Desktop/...` não dá,
`runner` não consegue nem entrar em `/home/hix`, que é `750`):

```bash
sudo -u runner HOME=/opt/actions-runner bash -lc '
  cd /opt/actions-runner/_work/Testes/Testes
  RISCV_ISA_SIM_DIR=/opt/riscv-foundation/riscv-isa-sim uv run python -c "from riscv_tools import golden_generator; golden_generator.setup()"
'
```

**O `HOME=/opt/actions-runner` explícito é obrigatório** nesta máquina: o
`/etc/passwd` do `runner` está com `HOME=/home/runner` (diretório que não
existe — ver a nota na Fase 1 do [RUNNER_SETUP.md](RUNNER_SETUP.md)). Sem
isso, `uv` falha com:
```
error: Failed to initialize cache at `/home/runner/.cache/uv`
  Caused by: failed to create directory `/home/runner/.cache/uv`: Permission denied
```
Se `sudo usermod -d /opt/actions-runner runner` já tiver sido rodado pra
corrigir a conta (recomendado no `RUNNER_SETUP.md`), o `HOME=` explícito
vira redundante mas continua inofensivo — pode deixar.

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
