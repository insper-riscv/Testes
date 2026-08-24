import cocotb
from cocotb.triggers import Timer
import os
os.environ['COCOTB_RESOLVE_X'] = 'ZEROS'

@cocotb.test()
async def test_mext(dut):
    """Testa MUL, MULH, DIV, DIVU, REM, REMU em sequencia.
    Resultados esperados nos SWs: 42, 0, 7, 7, 1, 1."""
    dut.CLK.value = 0
    await Timer(10, units="ns")

    n = [0]
    async def step():
        n[0] += 1
        for i in range(3):
            dut.CLK.value = 1
            await Timer(10, units="ns")
            dut.CLK.value = 0
            await Timer(10, units="ns")
        return (
            int(dut.ram_wdata.value),
            str(dut.core.u_reg_ex_mem.r_weRAM.value),
        )

    expected = [42, 0, 7, 7, 1, 1]
    labels   = ["MUL", "MULH", "DIV", "DIVU", "REM", "REMU"]
    results  = []

    for _ in range(300):
        wdata, weRAM = await step()
        if weRAM == '1':
            results.append(wdata)
            idx = len(results) - 1
            if idx < len(expected):
                assert wdata == expected[idx], \
                    f"{labels[idx]} falhou: wdata={wdata}, esperado={expected[idx]}"
                dut._log.info(f"{labels[idx]} OK: wdata={wdata}")
        if len(results) >= len(expected):
            break

    assert len(results) >= len(expected), \
        f"Apenas {len(results)} SWs executados, esperado {len(expected)}"
