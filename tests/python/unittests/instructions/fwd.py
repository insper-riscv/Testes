import cocotb
from cocotb.triggers import Timer
import os
os.environ['COCOTB_RESOLVE_X'] = 'ZEROS'

@cocotb.test()
async def test_forwarding_raw(dut):
    """Testa forwarding RAW: ADD x3,x1,x2 depende de ADDI x1 e ADDI x2 anteriores.
    Resultado esperado: SW escreve 8 na RAM."""
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
    found = False
    for _ in range(20):
        wdata, weRAM = await step()
        if weRAM == '1' and wdata == 8:
            dut._log.info(f"FORWARDING RAW OK: SW escreveu wdata=8 no step {n[0]}")
            found = True
            break
    assert found, f"Forwarding RAW falhou: SW com wdata=8 nunca ocorreu apos {n[0]} steps"
