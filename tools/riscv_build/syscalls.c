/* Minimal newlib syscall stub -- just enough for malloc()/free() to
 * work in this bare-metal build (no OS, no real syscalls, no libc
 * otherwise linked in beyond what a test's own code actually
 * references). newlib's malloc grows the heap purely by calling
 * _sbrk(); everything else it needs (free-list bookkeeping, etc.)
 * lives entirely inside newlib itself, so this one function is
 * sufficient for a test that never touches stdio (no printf/etc, so
 * no _write/_read/_close/_fstat/_isatty stubs needed either -- the
 * linker never pulls in code that references them).
 *
 * Heap grows up from _bss_end (link.ld/golden.ld's own end-of-.bss
 * symbol -- already exists, no new linker symbol needed) towards
 * _stack_top (also already defined there) -- returns (void *)-1 on
 * exhaustion, the POSIX sbrk(2) convention newlib's malloc checks
 * for.
 */
#include <stddef.h>

extern char _bss_end;
extern char _stack_top;

static char *heap_ptr = NULL;

void *_sbrk(ptrdiff_t incr) {
    if (heap_ptr == NULL) {
        heap_ptr = &_bss_end;
    }
    char *prev = heap_ptr;
    if (prev + incr > &_stack_top) {
        return (void *)-1;
    }
    heap_ptr += incr;
    return prev;
}
