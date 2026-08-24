import cocotb
from cocotb.triggers import Timer

def sext(val, bits):
    mask = (1 << bits) - 1
    val &= mask
    if val & (1 << (bits - 1)):
        val -= (1 << bits)
    return val

@cocotb.test()
async def test_branches(dut):
    """Testa BEQ, BNE, BLT, BGE, BLTU, BGEU nas duas condições (satisfaz e não satisfaz)."""

    offset = sext(8, 13)  # offset = 8

    dut.CLK.value = 0
    await Timer(10, units="ns")

    async def step():
        pc = int(dut.core.pc_if_out.value)
        dut.CLK.value = 1; await Timer(5, units="ns")
        dut.CLK.value = 0; await Timer(10, units="ns")
        dut.CLK.value = 1; await Timer(10, units="ns")
        dut.CLK.value = 0; await Timer(10, units="ns")
        dut.CLK.value = 1; await Timer(10, units="ns")
        dut.CLK.value = 0; await Timer(10, units="ns")
        dut.CLK.value = 1; await Timer(5, units="ns")
        return pc

    await step()  # warmup extra (latência inicial desta versão)
    await step()  # x1 = 5
    await step()  # x2 = 10

    # Timing:
    # Branch NT: 1 step depois pc = pc_branch+4
    # Branch T:  3 steps depois pc = pc_branch+offset+4 (instrução APÓS o target)
    # Importante: o pc_after de um branch T é o pc_before do próximo branch!

    # ====== BEQ ======
    pc_before = await step()   # beq x1,x2 (não salta)
    pc_after = await step()
    assert pc_after == (pc_before+4)&0xFFFFFFFF, f"BEQ NT: got={pc_after:#x} exp={pc_before+4:#x}"
    dut._log.info(f"BEQ (não salta) OK")

    pc_before = await step()   # beq x1,x1 (salta)
    await step(); await step(); await step()
    pc_after = await step()
    assert pc_after == (pc_before+offset+4)&0xFFFFFFFF, f"BEQ T: got={pc_after:#x} exp={pc_before+offset+4:#x}"
    dut._log.info(f"BEQ (salta) OK")

    # ====== BNE ====== (pc_before = pc_after do BEQ T)
    pc_before = pc_after       # reutiliza pc_after do BEQ T
    await step(); await step(); await step()
    pc_after = await step()
    assert pc_after == (pc_before+offset+4)&0xFFFFFFFF, f"BNE T: got={pc_after:#x} exp={pc_before+offset+4:#x}"
    dut._log.info(f"BNE (salta) OK")

    pc_before = pc_after       # pc_after do BNE T = pc do BNE NT
    pc_after = await step()
    assert pc_after == (pc_before+4)&0xFFFFFFFF, f"BNE NT: got={pc_after:#x} exp={pc_before+4:#x}"
    dut._log.info(f"BNE (não salta) OK")

    # ====== BLT ======
    pc_before = await step()   # blt x1,x2 (salta)
    await step(); await step(); await step()
    pc_after = await step()
    assert pc_after == (pc_before+offset+4)&0xFFFFFFFF, f"BLT T: got={pc_after:#x} exp={pc_before+offset+4:#x}"
    dut._log.info(f"BLT (salta) OK")

    pc_before = pc_after       # blt x2,x1 (não salta)
    pc_after = await step()
    assert pc_after == (pc_before+4)&0xFFFFFFFF, f"BLT NT: got={pc_after:#x} exp={pc_before+4:#x}"
    dut._log.info(f"BLT (não salta) OK")

    # ====== BGE ======
    pc_before = await step()   # bge x2,x1 (salta)
    await step(); await step(); await step()
    pc_after = await step()
    assert pc_after == (pc_before+offset+4)&0xFFFFFFFF, f"BGE T: got={pc_after:#x} exp={pc_before+offset+4:#x}"
    dut._log.info(f"BGE (salta) OK")

    pc_before = pc_after       # bge x1,x2 (não salta)
    pc_after = await step()
    assert pc_after == (pc_before+4)&0xFFFFFFFF, f"BGE NT: got={pc_after:#x} exp={pc_before+4:#x}"
    dut._log.info(f"BGE (não salta) OK")

    # ====== BLTU ======
    pc_before = await step()   # bltu x1,x2 (salta)
    await step(); await step(); await step()
    pc_after = await step()
    assert pc_after == (pc_before+offset+4)&0xFFFFFFFF, f"BLTU T: got={pc_after:#x} exp={pc_before+offset+4:#x}"
    dut._log.info(f"BLTU (salta) OK")

    pc_before = pc_after       # bltu x2,x1 (não salta)
    pc_after = await step()
    assert pc_after == (pc_before+4)&0xFFFFFFFF, f"BLTU NT: got={pc_after:#x} exp={pc_before+4:#x}"
    dut._log.info(f"BLTU (não salta) OK")

    # ====== BGEU ======
    pc_before = await step()   # bgeu x2,x1 (salta)
    await step(); await step(); await step()
    pc_after = await step()
    assert pc_after == (pc_before+offset+4)&0xFFFFFFFF, f"BGEU T: got={pc_after:#x} exp={pc_before+offset+4:#x}"
    dut._log.info(f"BGEU (salta) OK")

    pc_before = pc_after       # bgeu x1,x2 (não salta)
    pc_after = await step()
    assert pc_after == (pc_before+4)&0xFFFFFFFF, f"BGEU NT: got={pc_after:#x} exp={pc_before+4:#x}"
    dut._log.info(f"BGEU (não salta) OK")

    dut._log.info("Todos os branches testados com sucesso!")
