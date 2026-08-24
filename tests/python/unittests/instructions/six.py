import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_load_store_via_loads_and_regs(dut):
    """Testa SW, SH, SB verificando loads + valores nos registradores via ADD t3,reg,x0"""

    dut.CLK.value = 0
    await Timer(10, units="ns")

    async def step():
        alu_out = int(dut.core.alu_out_idexmem.value)
        ram_out = int(dut.core.ram_out.value)
        ext_ram_out = int(dut.core.extenderRAM_out.value)
        dut.CLK.value = 1; await Timer(5, units="ns")
        dut.CLK.value = 0; await Timer(10, units="ns")
        dut.CLK.value = 1; await Timer(10, units="ns")
        dut.CLK.value = 0; await Timer(10, units="ns")
        dut.CLK.value = 1; await Timer(10, units="ns")
        dut.CLK.value = 0; await Timer(10, units="ns")
        dut.CLK.value = 1; await Timer(5, units="ns")
        return alu_out, ram_out, ext_ram_out

    # ===== Warmup: 1 step extra (latência inicial) + 3 instruções de inicialização =====
    await step()  # warmup extra (latência inicial desta versão do pipeline)
    await step()  # addi x1,x0,15
    await step()  # lui x2,0xAABBD
    await step()  # addi x2,x2,-803 (x2=0xAABBCCDD)

    # ===== STORES (3 steps) =====
    await step()  # sw x2,0(x1)
    await step()  # sh x2,4(x1)
    await step()  # sb x2,6(x1)

    # ===== Extras: aguardar stores chegarem ao exmem =====
    await step()  # sw chega ao exmem
    await step()  # sh chega ao exmem
    await step()  # sb chega ao exmem

    # ===== LOADS + exposições =====
    # Padrão para cada load+add (com load-use stall):
    # step "load": load no exmem (endereço)
    # step "stall": bolha de hazard
    # step "add": add t3,reg,x0 no exmem -> alu = valor_load

    # LW
    await step()           # lw x3,0(x1) no exmem
    await step()           # stall (load-use hazard)
    alu, _, _ = await step()  # add t3,x3,x0 no exmem
    assert alu == 0xAABBCCDD, f"LW falhou no reg: {alu:#x}"
    dut._log.info(f"LW OK: {alu:#010x}")

    # LH
    await step()           # lh x4,4(x1) no exmem
    await step()           # stall
    alu, _, _ = await step()  # add t3,x4,x0
    assert alu == 0xFFFFCCDD & 0xFFFFFFFF, f"LH falhou no reg: {alu:#x}"
    dut._log.info(f"LH OK: {alu:#010x}")

    # LHU
    await step()           # lhu x5,4(x1) no exmem
    await step()           # stall
    alu, _, _ = await step()  # add t3,x5,x0
    assert alu == 0x0000CCDD, f"LHU falhou no reg: {alu:#x}"
    dut._log.info(f"LHU OK: {alu:#010x}")

    # LB
    await step()           # lb x6,6(x1) no exmem
    await step()           # stall
    alu, _, _ = await step()  # add t3,x6,x0
    assert alu == 0xFFFFFFDD & 0xFFFFFFFF, f"LB falhou no reg: {alu:#x}"
    dut._log.info(f"LB OK: {alu:#010x}")

    # LBU
    await step()           # lbu x7,6(x1) no exmem
    await step()           # stall
    alu, _, _ = await step()  # add t3,x7,x0
    assert alu == 0x000000DD, f"LBU falhou no reg: {alu:#x}"
    dut._log.info(f"LBU OK: {alu:#010x}")

    dut._log.info("Todos os loads/stores + registradores passaram")
