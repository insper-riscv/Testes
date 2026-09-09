/* Self-contained malloc()/free() — deliberately NOT newlib's.
 *
 * compile_test still passes -nostdlib (see Tools' compiler/build.py),
 * so this project never links against the toolchain's own bundled
 * libc.a at all. Tried the opposite first (drop -nostdlib, provide
 * just a _sbrk() stub for newlib's own malloc to call) — broke in CI
 * with "can't link double-float modules with soft-float modules":
 * the riscv-collab prebuilt release CI downloads turned out to ship a
 * SINGLE-target libc.a built for rv32imafdc/hard-float (confirmed by
 * downloading that exact release and checking its own
 * Tag_RISCV_arch), incompatible with -mabi=ilp32 (soft-float — the
 * only ABI that makes sense for a core with no FPU at all). That
 * wasn't fixable with compile flags: the toolchain a given CI run
 * happens to download isn't guaranteed to have been built for this
 * project's own -march/-mabi, and "always latest" makes pinning
 * around it fragile. A malloc that never touches libc.a sidesteps the
 * whole class of problem.
 *
 * A plain bump allocator is enough for this project's tests: none of
 * them build/tear down repeatedly or care about reclaiming memory
 * mid-test, so free() is a no-op rather than a real free-list.
 *
 * Heap grows up from _bss_end (link.ld/golden.ld's own end-of-.bss
 * symbol — already exists, no new linker symbol needed) towards
 * _stack_top (also already defined there) — returns NULL on
 * exhaustion, same convention libc's own malloc uses.
 */
#include <stddef.h>

extern char _bss_end;
extern char _stack_top;

static char *heap_ptr = NULL;

void *malloc(size_t size) {
    if (heap_ptr == NULL) {
        heap_ptr = &_bss_end;
    }
    /* 4-byte-align every allocation -- struct fields on RV32 expect
     * natural alignment, and a byte-granular bump pointer would
     * eventually hand back a misaligned block otherwise. */
    size = (size + 3u) & ~(size_t)3u;

    if (heap_ptr + size > &_stack_top) {
        return NULL;
    }
    char *block = heap_ptr;
    heap_ptr += size;
    return block;
}

void free(void *ptr) {
    (void)ptr; /* bump allocator -- nothing to reclaim, see header comment */
}
