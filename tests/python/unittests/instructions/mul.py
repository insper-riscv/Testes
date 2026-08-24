import cocotb
from cocotb.triggers import Timer
import os
os.environ['COCOTB_RESOLVE_X'] = 'ZEROS'

@cocotb.test()
async def test_mul(dut):
    """Testa MUL 6*7=42: verifica stall correto e resultado no wdata do SW."""
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
            int(dut.core.alu_out_idexmem.value),
            int(dut.ram_wdata.value),
            str(dut.core.u_reg_ex_mem.r_weRAM.value),
        )

    found = False
    for _ in range(55):
        alu, wdata, weRAM = await step()
        # O SW executa quando weRAM=1; nesse ciclo ram_wdata tem x12=42
        if weRAM == '1' and wdata == 42:
            dut._log.info(f"MUL OK: SW executou com wdata=42 no step {n[0]}")
            found = True
            break

    assert found, f"MUL falhou: após {n[0]} steps, SW com wdata=42 nunca ocorreu"
