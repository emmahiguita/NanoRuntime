/*
 * util.c — Shared utility implementations (count_argv, apply_env).
 */
#include "util.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/resource.h>

int count_argv(const char* const argv[]) {
    if (!argv) return 0;
    int n = 0;
    while (argv[n]) n++;
    return n;
}

void apply_env(const char* const envp[]) {
    if (!envp) return;
    for (int i = 0; envp[i]; i++) {
        char* kv = strdup(envp[i]);
        if (!kv) continue;
        char* eq = strchr(kv, '=');
        if (eq) {
            *eq = '\0';
            setenv(kv, eq + 1, 1);
        }
        free(kv);
    }
}

/* Límite de RAM virtual por proceso hijo. El worker (:nanoshell) hereda sus
 * libs (JVM + libnanoshell + sistema) al child vía fork, y el dlopen del
 * binario (toybox) + CFI shadow del linker necesitan VMA adicional. Un cap
 * fijo dejaba demasiado poco y el mmap fallaba (linker_block_allocator
 * create_new_page CHECK 'page != MAP_FAILED'). El cap se aplica ahora con
 * floor dinámico: nunca por debajo del VA ya usado + margen de crecimiento. */
#define CHILD_RLIMIT_AS_MB (1024ULL * 1024ULL * 1024ULL)

/* Margen de VA que se permite crecer al binario tras el fork+dlopen. */
#define RLIMIT_AS_GROWTH_MB 512

/*
 * Aplica RLIMIT_AS en el child process DESPUÉS de dlopen (y nunca antes de
 * execve/linker64 — ver pty.c).
 *
 * Sin límite, un `tar -x` de un archivo grande o un binario con leak puede
 * consumir RAM ilimitada en el worker (:nanoshell) y tumbarse el device.
 *
 * El hijo hereda el VA del proceso app completo (Flutter VM + engine) y el
 * linker reserva zonas grandes (CFI shadow de binarios PIE cargados por
 * dlopen). Fijar el cap pedido ciegamente rompe cualquier mmap nuevo:
 * total_vm heredado + sombras ya superan el cap. Por eso el cap efectivo es
 * max(pedido, VA actual + RLIMIT_AS_GROWTH_MB): protege contra crecimiento
 * descontrolado, no contra el estado heredado. Override vía
 * NANOAI_RLIMIT_AS_MB (se usa como piso pedido, mismo floor dinámico).
 */
void apply_rlimit_as(void) {
    const char* env_override = getenv("NANOAI_RLIMIT_AS_MB");
    rlim_t limit = CHILD_RLIMIT_AS_MB;
    if (env_override && env_override[0]) {
        char* end = NULL;
        unsigned long mb = strtoul(env_override, &end, 10);
        if (end != env_override && mb > 0) limit = mb * 1024UL * 1024UL;
    }

    // VA actual del proceso: primera columna de /proc/self/statm (páginas).
    rlim_t current_bytes = 0;
    FILE* f = fopen("/proc/self/statm", "re");
    if (f) {
        long long pages = 0;
        if (fscanf(f, "%lld", &pages) == 1) {
            long long page_size = sysconf(_SC_PAGESIZE);
            if (page_size <= 0) page_size = 4096;
            current_bytes = (rlim_t)pages * (rlim_t)page_size;
        }
        fclose(f);
    }

    rlim_t floor_bytes = current_bytes + (rlim_t)RLIMIT_AS_GROWTH_MB * 1024UL * 1024UL;
    if (floor_bytes > limit) limit = floor_bytes;

    struct rlimit rl;
    rl.rlim_cur = limit;
    rl.rlim_max = limit;
    setrlimit(RLIMIT_AS, &rl);
}
