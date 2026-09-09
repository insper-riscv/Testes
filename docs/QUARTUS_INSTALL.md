# Instalando o Quartus Prime Lite

O Quartus **precisa estar instalado direto em `/opt`** antes de configurar o
runner self-hosted (ver [RUNNER_SETUP.md](RUNNER_SETUP.md)) — instalado como
um programa global (`/opt/altera_lite`, em vez do home de um usuário), pra
ficar acessível a qualquer usuário/serviço da máquina sem precisar de grupo
especial. Como o destino é `/opt`, que pertence ao `root`, a instalação
precisa de `sudo`.

## 1. Baixar o instalador oficial

Quartus Prime Lite Edition, versão 25.1:
[página de download](https://www.altera.com/downloads)

O nome do arquivo muda a cada build (ex: `qinst-lite-linux-25.1std-1129.run`).
Os comandos abaixo usam `qinst-lite-linux-*.run` pra não depender do número
exato; confira o SHA1 publicado na página de download contra o arquivo
baixado antes de instalar.

## 2. Dar permissão de execução

```bash
chmod +x qinst-lite-linux-*.run
```

## 3. Instalar

**Modo GUI** (roda o instalador direto):
```bash
sudo ./qinst-lite-linux-*.run
```
Na tela de destino, apontar pra `/opt/altera_lite`. Precisa de `sudo` porque
`/opt` é do `root` — sem `sudo`, o instalador não consegue criar o diretório
de destino.

**Modo CLI** (sem display, ex: máquina headless/SSH):
```bash
sudo ./qinst-lite-linux-*.run -- --target /opt/altera_lite
sudo /opt/altera_lite/qinst.sh --cli   # --help pra ver as opções
```

## 4. Resultado esperado

Binários em `/opt/altera_lite/25.1std/quartus/bin/`, dono `root:root`,
permissão `755`/`555` (leitura+execução pra todo mundo, escrita só pro
root) — é isso que garante que qualquer usuário do sistema (incluindo o
usuário de serviço `runner`) consiga rodar o Quartus sem precisar estar em
nenhum grupo especial.

## 5. PATH para usuários interativos

```bash
echo 'export PATH="$PATH:/opt/altera_lite/25.1std/quartus/bin"' | \
  sudo tee /etc/profile.d/quartus.sh
sudo chmod +x /etc/profile.d/quartus.sh
```

Isso resolve o `PATH` (`quartus`, `quartus_pgm`, `jtagconfig`, etc.) pra
**qualquer shell interativo/login de qualquer usuário**. **Não** resolve pro
`runner` rodando via `systemd` — esse caso é tratado à parte, na Fase 4 do
[RUNNER_SETUP.md](RUNNER_SETUP.md).

## 6. (Opcional) Atalho `.desktop` global

Pra o Quartus aparecer no menu de aplicativos de qualquer usuário:

```bash
sudo tee /usr/share/applications/quartus-lite.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Quartus Prime Lite
Comment=Intel/Altera Quartus Prime Lite Edition
Exec=/opt/altera_lite/25.1std/quartus/bin/quartus
Icon=/opt/altera_lite/25.1std/quartus/adm/quartusii.png
Terminal=false
Categories=Development;Electronics;
StartupWMClass=quartus
EOF
sudo update-desktop-database /usr/share/applications
```

Precisa estar em `/usr/share/applications/`, para aparecer pra
todo mundo. `desktop-file-validate` confere se o arquivo está sintaticamente
correto:

```bash
desktop-file-validate /usr/share/applications/quartus-lite.desktop
```
