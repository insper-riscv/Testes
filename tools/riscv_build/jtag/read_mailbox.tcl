# Reads the PASS/FAIL mailbox word through Quartus' In-System Memory
# Content Editor, over the same JTAG link used to program the board.
# The RAM IP must have "Allow In-System Memory Content Editor to
# capture/update content independently of the system clock" enabled
# for this to work.
#
# Usage: quartus_stp -t read_mailbox.tcl <hardware_name> <device_name> <ram_instance> <mailbox_word_offset>

package require ::quartus::insystem_memory_edit

if {[llength $argv] < 4} {
    puts stderr "Usage: quartus_stp -t read_mailbox.tcl <hardware> <device> <instance> <word_offset>"
    exit 1
}
lassign $argv HW DEV INSTANCE WORD_OFFSET

catch { end_memory_edit }
if {[catch { begin_memory_edit -hardware_name $HW -device_name $DEV } err]} {
    puts stderr "begin_memory_edit failed: $err"
    exit 2
}

if {[catch {
    set words [read_content_from_memory -instance_index $INSTANCE \
                   -start_address $WORD_OFFSET -word_count 1]
} rerr]} {
    puts stderr "read_content_from_memory failed: $rerr"
    catch { end_memory_edit }
    exit 3
}

catch { end_memory_edit }
puts "MAILBOX=[lindex $words 0]"
exit 0
