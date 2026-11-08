"""Roda os testes cocotb por entidade e por instrução listados em ``tests.json``."""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

# cocotb 2.0 split the Python test-runner API out of the main cocotb
# package into cocotb-tools, imported as cocotb_tools.runner — this
# repo's requirements.txt pulls unpinned cocotb, which now resolves to
# 2.x, so the old `cocotb.runner` import 404s. See insper-riscv/Tools'
# own sim_runner module for the same migration.
from cocotb_tools.check_results import get_results
from cocotb_tools.runner import get_runner


def build_directory(tests_root: Path, toplevel: str, test_module: str) -> Path:
    """Cria e devolve a pasta de build do teste.

    Parameters
    ----------
    tests_root : Path
        A pasta ``tests``.
    toplevel : str
        Entidade de topo.
    test_module : str
        Módulo cocotb do teste.

    Returns
    -------
    Path
        ``sim_build/<grupo>/<nome>``, com o nome do módulo nos testes de instrução e o do topo nos demais.
    """
    if ".entities." in test_module:
        group = "entities"
    elif ".instructions." in test_module:
        group = "instructions"
    else:
        group = "misc"
    name = test_module.split(".")[-1] if group == "instructions" else toplevel
    build_dir = tests_root / "python/sim_build" / group / name
    build_dir.mkdir(parents=True, exist_ok=True)
    return build_dir


def absolute_parameter(value: object, repo_root: Path) -> str:
    """Texto que o simulador recebe para o valor de um generic.

    Parameters
    ----------
    value : object
        Booleano, inteiro ou texto (um caminho, quando existe no diretório atual ou na raiz do repositório).
    repo_root : Path
        A raiz do repositório.

    Returns
    -------
    str
        ``true``/``false`` para booleanos, o número em decimal, o caminho absoluto quando o texto é um caminho
        e o próprio texto nos demais casos (flags que não são caminhos).
    """
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    for candidate in (Path(str(value)), repo_root / str(value)):
        if candidate.exists():
            return str(candidate.resolve())
    return str(value)


def absolute_parameters(parameters: dict[str, object] | None, repo_root: Path) -> dict[str, object]:
    """Generics de um teste, cada um convertido por ``absolute_parameter``.

    Parameters
    ----------
    parameters : dict, optional
        Os generics do topo.
    repo_root : Path
        A raiz do repositório.

    Returns
    -------
    dict of {str: object}
        Os generics convertidos; vazio quando não há nenhum.
    """
    return {k: absolute_parameter(v, repo_root) for k, v in (parameters or {}).items()}


def run_cocotb_test(  # pylint: disable=too-many-arguments,too-many-positional-arguments,too-many-locals
    toplevel: str,
    sources: list[str],
    test_module: str,
    parameters: dict[str, object] | None = None,
    build_args: list[str] | None = None,
    test_args: list[str] | None = None,
) -> None:
    """Compila o VHDL de um teste por entidade e roda o módulo cocotb dele.

    Parameters
    ----------
    toplevel : str
        Entidade de topo.
    sources : list of str
        Fontes VHDL, relativos à raiz do repositório.
    test_module : str
        Módulo cocotb do teste.
    parameters : dict, optional
        Generics do topo; caminhos viram absolutos.
    build_args : list of str, optional
        Opções extras do GHDL na compilação.
    test_args : list of str, optional
        Opções extras da simulação.

    Raises
    ------
    RuntimeError
        Se algum teste do módulo falhou.
    """
    repo_root = Path(__file__).resolve().parents[2]
    sys.path.append(str(repo_root))

    sim = os.getenv("SIM", "ghdl")
    vhdl_sources = [repo_root / src for src in sources]

    runner = get_runner(sim)

    build_dir = build_directory(repo_root / "tests", toplevel, test_module)
    parameters = absolute_parameters(parameters, repo_root)

    runner.build(
        vhdl_sources=vhdl_sources,
        hdl_toplevel=toplevel,
        always=True,
        build_dir=build_dir,
        parameters=parameters,
        build_args=build_args or [],
    )

    wave_file = build_dir / "waves.ghw"
    plusargs = [f"--wave={wave_file}"]

    results_xml = runner.test(
        hdl_toplevel=toplevel,
        hdl_toplevel_lang="vhdl",
        test_module=test_module,
        build_dir=build_dir,
        plusargs=plusargs,
        test_args=test_args or [],
    )

    print(f"Waves: {wave_file} (gerado)")

    # runner.test() returns normally when a cocotb test fails; the failures are only in results.xml
    total, failed = get_results(results_xml)
    if failed:
        raise RuntimeError(f"{failed} of {total} cocotb tests failed")


def run_config(config: dict[str, Any]) -> None:
    """Roda um teste de ``tests.json`` sem as chaves ``skip`` e ``skip_reason``.

    Parameters
    ----------
    config : dict
        A entrada do teste.
    """
    run_cocotb_test(**{k: v for k, v in config.items() if k not in ("skip", "skip_reason")})


def run_all(test_configs: dict[str, dict[str, Any]]) -> list[str]:
    """Roda todos os testes que não estão marcados como ``skip``.

    "skip"/"skip_reason" é uma dispensa do config (não uma remoção) para um teste que hoje falha por um motivo
    alheio à mudança em teste, no mesmo espírito dos arquivos ``.off`` da suíte asm/c. Só vale na varredura
    ``all``: rodar o teste pelo nome tenta rodá-lo mesmo assim.

    Parameters
    ----------
    test_configs : dict
        O conteúdo de ``tests.json``.

    Returns
    -------
    list of str
        Os nomes dos testes que falharam.
    """
    failures: list[str] = []
    for name, config in test_configs.items():
        if config.get("skip"):
            print(f"\n{'=' * 20} PULANDO TESTE: {name.upper()} {'=' * 20}")
            print(f"[SKIP] {config.get('skip_reason', 'no reason given')}")
            continue
        print(f"\n{'=' * 20} INICIANDO TESTE: {name.upper()} {'=' * 20}")
        try:
            run_config(config)
            print(f"{'-' * 20} TESTE {name.upper()} FINALIZADO COM SUCESSO {'-' * 20}")
        # registra a falha e segue para o próximo teste
        except Exception as e:  # noqa: BLE001  # pylint: disable=broad-exception-caught
            failures.append(name)
            print(f"[ERRO] O teste '{name}' falhou: {e}")
    return failures


def load_configs(json_path: Path) -> dict[str, dict[str, Any]]:
    """Lê ``tests.json`` ou encerra o programa com uma mensagem.

    Parameters
    ----------
    json_path : Path
        O arquivo.

    Returns
    -------
    dict
        Os testes por nome.
    """
    try:
        with open(json_path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Erro: Arquivo de configuração '{json_path}' não encontrado.")
    except json.JSONDecodeError:
        print(f"Erro: O arquivo JSON '{json_path}' está mal formatado.")
    sys.exit(1)


def main() -> None:
    """Lê a linha de comando e roda um teste de ``tests.json`` ou todos."""
    test_configs = load_configs(Path(__file__).resolve().parents[1] / "python/tests.json")
    options = [*test_configs, "all"]
    parser = argparse.ArgumentParser(description="Runner de Testes Cocotb para o projeto RV32I")
    parser.add_argument("test_name", nargs="?", default="all", help=f"Nome do teste a ser executado. Opções: {options}")
    args = parser.parse_args()

    if args.test_name == "all":
        print("Executando TODOS os testes definidos em tests.json...")
        failures = run_all(test_configs)
        print("\nTodos os testes foram executados.")
        if failures:
            print(f"[ERRO] {len(failures)} teste(s) falharam: {', '.join(failures)}")
            sys.exit(1)
    elif args.test_name in test_configs:
        print(f"Executando teste específico: {args.test_name}")
        config = test_configs[args.test_name]
        if config.get("skip"):
            print(
                f"[AVISO] '{args.test_name}' está marcado como skip ({config.get('skip_reason', 'no reason given')}) "
                "-- rodando mesmo assim, por ter sido pedido explicitamente."
            )
        run_config(config)
        print(f"\nTeste {args.test_name} finalizado.")
    else:
        print(f"Erro: Teste '{args.test_name}' não encontrado em tests.json.")
        print(f"Opções disponíveis: {options}")
        sys.exit(1)


if __name__ == "__main__":
    main()
