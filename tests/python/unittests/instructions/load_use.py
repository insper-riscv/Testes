import cocotb
from cocotb.triggers import Timer
import os
os.environ['COCOTB_RESOLVE_X'] = 'ZEROS'

@cocotb.test()
async def test_load_use_hazard(dut):
    """Testa load-use hazard: LW x3,0(x1) seguido de ADD x4,x3,x0.
    Pipeline deve inserir stall e resultado esperado: SW escreve 42 na RAM[1]."""
    dut.CLK.value = 0
    await Timer(10, units="ns")
    n = [0]
    written = []
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
    for _ in range(30):
        wdata, weRAM = await step()
        if weRAM == '1':
            written.append(wdata)
        if len(written) >= 2:
            break
    assert len(written) >= 2, f"Load-use: menos de 2 SWs executados apos {n[0]} steps"
    assert written[1] == 42, f"Load-use falhou: segundo SW escreveu {written[1]}, esperado 42"
    dut._log.info(f"LOAD-USE HAZARD OK: segundo SW escreveu wdata=42 no step {n[0]}")
