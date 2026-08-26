# Configurando um runner self-hosted (guia passo a passo)

Baseado no setup real dessa workstation (`picow-WS-C621E-SAGE-Series`). Todos os
nomes/caminhos abaixo são os que estão de fato em uso aqui — confirmados direto no
host, não é um template genérico.

## Visão geral

```
/opt/actions-runner/      home do usuário de serviço "runner" (o runner do GitHub Actions em si)
/opt/altera_lite/         bind mount do Quartus (picow → runner, sem dar acesso ao home do picow)
/opt/riscv-foundation/    cache compartilhado de toolchains RISC-V (workstation inteira, não só um repo)
```

## Fase 1 — Usuário de serviço dedicado

O runner roda como um usuário de sistema **sem senha, sem sudo próprio, sem estar
no grupo do usuário admin** — isolamento deliberado.

```bash
sudo useradd -r -m -d /opt/actions-runner -s /bin/bash runner
sudo passwd -l runner              # sem login por senha; só via sudo/systemd
sudo usermod -aG plugdev runner    # acesso ao USB-Blaster (defesa em profundidade)
```

- `-r` → UID/GID na faixa de sistema (aqui: `999`/`998`).
- `-m -d /opt/actions-runner` → cria o home já no lugar certo, dono `runner:runner`.

## Fase 2 — Registrar o runner no GitHub

**Onde pegar o token/URL**: no repo (ou na org, se for um runner de nível de
organização) → **Settings → Actions → Runners → New runner**. O token expira em
~1h, precisa copiar na hora.

```bash
sudo -iu runner bash -lc '
  cd /opt/actions-runner
  curl -o actions-runner.tar.gz -L <URL_DE_DOWNLOAD_DA_PAGINA>
  tar xzf actions-runner.tar.gz
  ./config.sh --url https://github.com/<org-ou-org/repo> --token <TOKEN_DA_PAGINA> \
      --labels self-hosted,quartus,fpga --name workstation-fpga --unattended
'
```

- `sudo -iu runner` roda como `runner`, mas usa o sudo de quem está logado — `runner`
  nunca precisa ter sudo próprio pra isso.
- **Se o token der erro de permissão do tipo "refusing to allow a Personal Access
  Token to create or update workflow ... without `workflow` scope"**: o token
  (fine-grained PAT) precisa da permissão **"Workflows"** habilitada (Read and
  write) — é diferente de "Contents"/"Actions", precisa ser adicionada
  explicitamente na tela de edição do token.

### Segurança: runner de nível de organização

Se o runner for registrado na ORG (não num repo específico), ele fica disponível
pra **qualquer repo** que o *runner group* dele permitir — por padrão isso costuma
ser "All repositories", o que expõe essa máquina a repos públicos da mesma org.

**Obrigatório**: Org Settings → Actions → Runner groups → grupo onde esse runner
caiu → **Repository access → Selected repositories → só os repos que precisam
mesmo tocar hardware**. Sem isso, qualquer repo público da org alcança essa
máquina através do mesmo runner.

**O grupo tem que se chamar `FPGA`** (não o default "Default", nem qualquer outro
nome tipo "Workstation - FPGA") — é esse o grupo que os workflows deste projeto
esperam poder alcançar. Durante o registro interativo (`config.sh` sem
`--runnergroup`), o CLI pergunta em qual grupo colocar o runner; escolha/crie o
grupo `FPGA` ali. Se o runner já foi registrado num grupo errado, mova-o depois em
Org Settings → Actions → Runner groups → `FPGA` → **Runners → Add runner** (ou
mude o grupo do runner existente pela própria página do grupo). Um runner no
grupo errado não dá erro claro — o job de um workflow que precisa dele
simplesmente fica preso em "Queued" pra sempre, sem nenhuma mensagem explicando
por quê.

## Fase 3 — Serviço systemd (autorun, sobrevive a reboot)

O script `svc.sh` que vem no pacote do runner assume que o próprio usuário do
serviço tem sudo (ele chama `sudo systemctl` internamente) — como `runner` não
tem, a unit é escrita direto:

```bash
sudo tee /etc/systemd/system/gh-actions-runner.service <<'UNIT'
[Unit]
Description=GitHub Actions self-hosted runner (FPGA workstation)
After=network.target

[Service]
Type=simple
User=runner
WorkingDirectory=/opt/actions-runner
ExecStart=/opt/actions-runner/run.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now gh-actions-runner
sudo systemctl status gh-actions-runner --no-pager   # deve mostrar "active (running)"
```

## Fase 4 — Acesso a ferramentas que só o usuário admin tem instaladas

Se o runner precisa de algo que já está instalado no home de outro usuário (ex:
Quartus em `/home/picow/altera_lite`), **não** coloque `runner` no grupo desse
usuário — isso dá acesso permanente a tudo dentro do home dele. Em vez disso,
**bind mount** só o que precisa, num caminho neutro em `/opt`:

```bash
sudo mkdir -p /opt/altera_lite
echo '/home/picow/altera_lite /opt/altera_lite none bind 0 0' | sudo tee -a /etc/fstab
sudo mount --bind /home/picow/altera_lite /opt/altera_lite
```

`runner` nunca ganha nenhuma permissão sobre `/home/picow` em si — só enxerga essa
árvore específica por um segundo caminho, gerenciado pelo root via `/etc/fstab`.

No workflow (`.github/workflows/real.yml`), aponta pro caminho montado:
```yaml
run: echo "/opt/altera_lite/25.1std/quartus/bin" >> "$GITHUB_PATH"
```

## Fase 5 — Cache compartilhado de toolchains (`/opt/riscv-foundation`)

Em vez de cada repo/usuário baixar sua própria cópia de toolchains grandes
(GCC RISC-V, Spike, etc.), um cache único pra workstation inteira:

```bash
sudo mkdir -p /opt/riscv-foundation
sudo chown runner:runner /opt/riscv-foundation
sudo chmod 2775 /opt/riscv-foundation   # setgid: arquivos novos herdam o grupo "runner"
```

Pra um usuário admin (ex: `picow`) também poder escrever ali sem sudo toda vez:

```bash
sudo usermod -aG runner picow
```

Isso é seguro nessa direção (admin ganhando acesso a algo do runner) porque o
admin já tem sudo irrestrito na máquina — é só conveniência, não um privilégio
novo. É a direção oposta (`runner` no grupo do `picow`) que teria que ser evitada.

**Nota**: mudança de grupo só vale numa sessão de shell nova. Pra usar na sessão
atual sem deslogar: `sg runner -c "<comando>"`.

O workflow então usa esse cache com verificação de versão (só baixa de novo se a
tag/versão mudou desde a última vez — ver `real.yml` pro padrão exato usado aqui
com o GCC).

## Fase 6 — Secret pra confirmar acionamento manual

Além do controle de acesso do repo (Fase 2), um segundo portão pra disparo manual
via `workflow_dispatch` — útil se algum dia mais gente tiver acesso de escrita ao
repo sem dever poder acionar hardware físico:

- Repo → **Settings → Secrets and variables → Actions → New repository secret**
- Nome: `FPGA_RUN_SECRET`, valor: qualquer frase (ex: `openssl rand -hex 32`)
- No workflow, um `workflow_dispatch.inputs.confirm` comparado contra esse secret
  antes de qualquer passo que toque a placa (ver `real.yml`).

## Fase 7 — Pegadinhas de hardware JTAG

- **A porta USB do dongle muda de número** (`USB-Blaster [1-4]` → `[1-10]`) entre
  replugs/reorganizações físicas — não confie num valor fixo no config, detecte
  via `jtagconfig` em tempo de execução.
- **Autosuspend USB pode derrubar a conexão JTAG sozinho, com o tempo** — se o
  hub/controlador raiz (`usb1` ou similar) estiver com `power/control=auto`, ele
  pode suspender a porta inteira depois de um tempo sem tráfego USB "normal"
  (JTAG gera tráfego em rajadas, não contínuo — exatamente o padrão que dispara
  autosuspend). Sintoma: `jtagconfig` mostra `Unable to read device chain -
  JTAG chain broken` ou `Hardware not attached`, mesmo com cabo/placa firmes, e
  some depois de um replug físico (que força reenumeração).

  Diagnóstico:
  ```bash
  for dev in /sys/bus/usb/devices/*; do
    [ -f "$dev/power/control" ] || continue
    echo "$(basename "$dev")  control=$(cat "$dev/power/control")  product=$(cat "$dev/product" 2>/dev/null)"
  done
  ```
  Procure o hub/controlador **pai** do dongle JTAG (não só o dongle em si — ele
  pode estar em `on` enquanto o pai está em `auto`) com `control=auto`.

  Fix:
  ```bash
  echo on | sudo tee /sys/bus/usb/devices/usb1/power/control   # ajuste "usb1" pro seu caso
  ```
  Permanente (sobrevive a reboot):
  ```bash
  echo 'ACTION=="add", SUBSYSTEM=="usb", KERNEL=="usb1", TEST=="power/control", ATTR{power/control}="on"' | \
    sudo tee /etc/udev/rules.d/52-usb1-no-autosuspend.rules
  sudo udevadm control --reload-rules
  sudo udevadm trigger --subsystem-match=usb
  ```

## Checklist final

- [ ] `sudo systemctl status gh-actions-runner` → `active (running)`
- [ ] Runner aparece **Idle** em Settings → Actions → Runners, com as labels certas
- [ ] Runner group restrito a **Selected repositories** (não "All repositories")
- [ ] `jtagconfig` lê o device ID da placa sem erro
- [ ] `cat /sys/bus/usb/devices/usb1/power/control` → `on` (ajuste o nome do hub)
- [ ] Secret de confirmação manual configurado, se aplicável
