"""Roda na placa DE0-CV os programas do Tests e os ELFs do ACT4, com um veredito por item.

O runner tem três subcomandos.

``prepare``
    Compila cada etapa para a placa (``compile --emit mif``). Roda onde está o GCC
    RISC-V, isto é, dentro da imagem ``ci-elf``, e não precisa de placa.
``run``
    Pega o lock da placa, programa o bitstream com o ``quartus_pgm`` (a menos que
    ``--skip-program``), roda as etapas pedidas com ``riscv-tools run`` e escreve
    ``results-<placa>.json`` com PASS, FAIL ou TIMEOUT por programa. Roda onde estão o
    Quartus e o cabo.
``act``
    Pega o lock da placa e roda os ELFs do ACT4 de um config gerado por
    ``gen_profiles.py --board`` (``riscv-tools certify-board --skip-build``).

Duas placas rodam em paralelo repartindo a lista com ``--part I/N``: a placa ``I`` (de 0
a N-1) roda os itens de índice ``I`` módulo ``N`` da lista ordenada.
"""

import argparse
import fcntl
import json
import os
import re
import shlex
import subprocess
import sys
import time
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

TESTS_ROOT = Path(__file__).resolve().parents[2]
BUILD = "tools/riscv_build"

# Cada etapa é um config do Tests e os programas que a placa não roda, com o motivo.
STAGES: dict[str, dict[str, object]] = {
    "regression": {
        "config": "config.sdram-flash-regression.yaml",
        "exclude": {
            "uart-echo": "pinos físicos da UART, que as placas não têm ligados",
            "uart-tx": "pinos físicos da UART, que as placas não têm ligados",
            "uart-errors": "pinos físicos da UART, que as placas não têm ligados",
        },
    },
    "sdram": {
        "config": "config.sdram-flash.yaml",
        "exclude": {},
        # hex-id pausa para uma pessoa ler o display e passa de 15 s
        "timeouts": {"hex-id": 90},
    },
    "irq": {
        "config": "config.sdram-flash-irq.yaml",
        "exclude": {},
    },
}

LOCKS = {"laptop": "/tmp/de0cv-laptop.lock", "ws": "/tmp/de0cv-ws.lock"}
_VERDICT = re.compile(r"^\s*(PASS|FAIL|TIMEOUT)\s+(\S+)")
_IDCODE = "02B050DD"


def tools_command() -> list[str]:
    """Devolve o comando do ``riscv-tools``.

    Returns
    -------
    list of str
        O valor de ``RISCV_TOOLS`` repartido como no shell, ou ``["riscv-tools"]``.
    """
    return shlex.split(os.environ.get("RISCV_TOOLS", "riscv-tools"))


@contextmanager
def board_lock(board: str, wait_s: int = 14400) -> Iterator[None]:
    """Segura o lock da placa durante toda a sessão.

    Parameters
    ----------
    board : str
        ``laptop`` ou ``ws``.
    wait_s : int
        Quanto esperar pelo lock antes de desistir.

    Yields
    ------
    None
        Com o lock tomado.

    Raises
    ------
    TimeoutError
        Se o lock não ficou livre a tempo.
    """
    with open(LOCKS[board], "a", encoding="utf-8") as handle:
        deadline = time.monotonic() + wait_s
        while True:
            try:
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() > deadline:
                    raise TimeoutError(f"lock {LOCKS[board]} ocupado") from None
                time.sleep(5)
        try:
            yield
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def de0cv_cable() -> str:
    """Acha o cabo da DE0-CV pelo IDCODE, nunca pelo nome do cabo (que muda).

    Returns
    -------
    str
        O nome ``USB-Blaster [bus-porta]`` cuja cadeia lista o IDCODE da DE0-CV.

    Raises
    ------
    RuntimeError
        Se nenhum cabo lista o IDCODE.
    """
    out = subprocess.run(
        ["jtagconfig"], check=True, capture_output=True, text=True
    ).stdout
    cable = None
    for line in out.splitlines():
        found = re.match(r"^\s*\d+\)\s+(USB-Blaster.*)$", line)
        if found:
            cable = found.group(1).strip()
        elif cable and _IDCODE in line.upper():
            return cable
    raise RuntimeError(f"nenhum cabo lista o IDCODE {_IDCODE}:\n{out}")


def program(sof: Path) -> None:
    """Programa o bitstream na DE0-CV.

    Parameters
    ----------
    sof : Path
        O arquivo ``.sof``.
    """
    cable = de0cv_cable()
    print(f"programando {sof} pelo cabo {cable}", flush=True)
    subprocess.run(
        ["quartus_pgm", "-c", cable, "-m", "jtag", "-o", f"p;{sof}"],
        check=True,
    )
    time.sleep(3)


def manifest_names(stage: str) -> list[str]:
    """Lista os programas compilados de uma etapa.

    Parameters
    ----------
    stage : str
        Nome da etapa.

    Returns
    -------
    list of str
        Os nomes do manifesto, ordenados.
    """
    config = yaml_build_dir(str(STAGES[stage]["config"]))
    manifest = TESTS_ROOT / config / "real" / "manifest.json"
    return sorted(e["name"] for e in json.loads(manifest.read_text()))


def yaml_build_dir(config: str) -> str:
    """Lê o ``paths.build_dir`` de um config do Tests sem carregar o YAML inteiro.

    Parameters
    ----------
    config : str
        Nome do config em ``tools/riscv_build``.

    Returns
    -------
    str
        O diretório de build, relativo à raiz do Tests.
    """
    text = (TESTS_ROOT / BUILD / config).read_text()
    found = re.search(r"^\s*build_dir:\s*(\S+)", text, re.MULTILINE)
    if not found:
        raise RuntimeError(f"{config} não declara paths.build_dir")
    return found.group(1)


def partition(names: list[str], part: str) -> list[str]:
    """Pega a fatia ``I/N`` de uma lista.

    Parameters
    ----------
    names : list of str
        A lista ordenada.
    part : str
        ``I/N``.

    Returns
    -------
    list of str
        Os itens de índice ``I`` módulo ``N``.
    """
    index, count = (int(x) for x in part.split("/"))
    return names[index::count]


def run_stage(stage: str, board: str, part: str, out: Path) -> dict[str, str]:
    """Roda uma etapa na placa e devolve o veredito de cada programa.

    Parameters
    ----------
    stage : str
        Nome da etapa.
    board : str
        ``laptop`` ou ``ws``, só para o nome do log.
    part : str
        Fatia ``I/N`` da lista.
    out : Path
        Onde o log da etapa é escrito.

    Returns
    -------
    dict of {str: str}
        PASS, FAIL ou TIMEOUT por programa.
    """
    config = STAGES[stage]["config"]
    excluded = set(STAGES[stage]["exclude"])  # type: ignore[arg-type]
    names = [n for n in manifest_names(stage) if n not in excluded]
    wanted = partition(names, part)
    if not wanted:
        return {}
    set_timeouts(stage, wanted)
    command = tools_command() + [
        "--config",
        f"{BUILD}/{config}",
        "run",
        "--skip-reconfigure",
        "--skip-recompile",
        "--only",
        ",".join(wanted),
    ]
    log = out / f"{stage}-{board}.log"
    with open(log, "w", encoding="utf-8") as handle:
        subprocess.run(
            command,
            cwd=TESTS_ROOT,
            stdout=handle,
            stderr=subprocess.STDOUT,
            check=False,
        )
    verdicts = parse_verdicts(log.read_text())
    return {name: verdicts.get(name, "TIMEOUT") for name in wanted}


def set_timeouts(stage: str, wanted: list[str]) -> None:
    """Aumenta no manifesto o timeout dos programas lentos da etapa.

    Parameters
    ----------
    stage : str
        Nome da etapa.
    wanted : list of str
        Os programas que a placa vai rodar.
    """
    timeouts: dict[str, int] = STAGES[stage].get("timeouts", {})  # type: ignore[assignment]
    mine = {n: t for n, t in timeouts.items() if n in wanted}
    if not mine:
        return
    config = yaml_build_dir(str(STAGES[stage]["config"]))
    path = TESTS_ROOT / config / "real" / "manifest.json"
    entries = json.loads(path.read_text())
    for entry in entries:
        entry["timeout_s"] = max(entry["timeout_s"], mine.get(entry["name"], 0))
    path.write_text(json.dumps(entries, indent=1))


def parse_verdicts(text: str) -> dict[str, str]:
    """Lê as linhas ``PASS nome`` do resumo do ``riscv-tools``.

    Parameters
    ----------
    text : str
        A saída do comando.

    Returns
    -------
    dict of {str: str}
        O veredito de cada nome que aparece no resumo.
    """
    found = {}
    for line in text.splitlines():
        match = _VERDICT.match(line)
        if match:
            found[match.group(2)] = match.group(1)
    return found


def cmd_prepare(args: argparse.Namespace) -> None:
    """Compila as etapas (``compile --emit mif``)."""
    for stage in args.stages:
        config = f"{BUILD}/{STAGES[stage]['config']}"
        for sub in ("generate-header", "compile --emit mif"):
            subprocess.run(
                tools_command() + ["--config", config] + sub.split(),
                cwd=TESTS_ROOT,
                check=True,
            )


def cmd_run(args: argparse.Namespace) -> None:
    """Programa a placa e roda as etapas sob o lock."""
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    results: dict[str, dict[str, str]] = {}
    with board_lock(args.board):
        if not args.skip_program:
            program(Path(args.sof))
        for stage in args.stages:
            results[stage] = run_stage(stage, args.board, args.part, out)
    (out / f"results-{args.board}.json").write_text(
        json.dumps(results, indent=1, sort_keys=True)
    )
    failed = [
        f"{s}/{n}" for s, r in results.items() for n, v in r.items() if v != "PASS"
    ]
    print(f"{sum(len(r) for r in results.values())} programas, falhas: {failed}")
    sys.exit(1 if failed else 0)


def cmd_act(args: argparse.Namespace) -> None:
    """Roda os ELFs do ACT4 de um config gerado, sob o lock da placa."""
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    root = Path(args.root)
    work = root / "vendor/riscv-arch-test/work"
    elfs = sorted({p.stem for p in work.glob(f"{args.target}*/elfs/**/*.elf")})
    wanted = partition(elfs, args.part)
    log = out / f"act-{args.board}.log"
    with board_lock(args.board):
        if not args.skip_program:
            program(Path(args.sof))
        with open(log, "w", encoding="utf-8") as handle:
            subprocess.run(
                tools_command()
                + [
                    "--config",
                    args.config,
                    "--root",
                    str(root),
                    "certify-board",
                    "--skip-build",
                    "--only",
                    ",".join(wanted),
                ],
                stdout=handle,
                stderr=subprocess.STDOUT,
                check=False,
            )
    verdicts = parse_verdicts(log.read_text())
    results = {n: verdicts.get(n, "TIMEOUT") for n in wanted}
    (out / f"act-{args.board}.json").write_text(
        json.dumps(results, indent=1, sort_keys=True)
    )
    failed = sorted(n for n, v in results.items() if v != "PASS")
    print(f"{len(results)} ELFs, falhas: {failed}")
    sys.exit(1 if failed else 0)


def main() -> None:
    """Lê a linha de comando e despacha."""
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n")[0])
    sub = parser.add_subparsers(dest="cmd", required=True)
    prep = sub.add_parser("prepare", help="compila as etapas")
    prep.add_argument("--stages", nargs="+", default=list(STAGES))
    prep.set_defaults(func=cmd_prepare)
    for name, func in (("run", cmd_run), ("act", cmd_act)):
        p = sub.add_parser(name)
        p.add_argument("--board", choices=sorted(LOCKS), required=True)
        p.add_argument("--part", default="0/1", help="fatia I/N da lista")
        p.add_argument("--sof", help="bitstream a programar")
        p.add_argument("--skip-program", action="store_true")
        p.add_argument("--out", default="build/board")
        p.set_defaults(func=func)
        if name == "run":
            p.add_argument("--stages", nargs="+", default=list(STAGES))
        else:
            p.add_argument("--config", required=True)
            p.add_argument("--root", required=True)
            p.add_argument("--target", required=True, help="pasta de work do ACT4")
    args = parser.parse_args()
    if args.cmd != "prepare" and not args.skip_program and not args.sof:
        parser.error("--sof é obrigatório sem --skip-program")
    args.func(args)


if __name__ == "__main__":
    main()
