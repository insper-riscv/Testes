# Writes a .mif's content into a memory instance via JTAG, without
# reprogramming the FPGA — the same mechanism L2IP's
# atualizaMemoria.tcl and RV32IM's own loadROM.tcl use. Requires the
# target IP to have ENABLE_RUNTIME_MOD=YES (confirmed already set on
# both ROM1PORT and RAM1PORT — see README.md).
#
# Usage: quartus_stp -t write_mem.tcl <hardware> <device> <instance> <mif_path>

package require ::quartus::insystem_memory_edit

if {[llength $argv] < 4} {
    puts stderr "Usage: quartus_stp -t write_mem.tcl <hardware> <device> <instance> <mif_path>"
    exit 1
}
lassign $argv HW DEV INSTANCE MIF_PATH

catch { end_memory_edit }
if {[catch { begin_memory_edit -hardware_name $HW -device_name $DEV } err]} {
    puts stderr "begin_memory_edit failed: $err"
    exit 2
}

if {[catch {
    update_content_to_memory_from_file -instance_index $INSTANCE \
        -mem_file_path $MIF_PATH -mem_file_type "mif"
} uerr]} {
    puts stderr "update_content_to_memory_from_file failed: $uerr"
    catch { end_memory_edit }
    exit 3
}

catch { end_memory_edit }
puts "Wrote $MIF_PATH to instance $INSTANCE"
exit 0
