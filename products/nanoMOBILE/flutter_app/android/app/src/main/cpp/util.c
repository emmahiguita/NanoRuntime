/*
 * util.c — Shared utility implementations (count_argv, apply_env).
 */
#include "util.h"
#include <stdlib.h>
#include <string.h>
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
 * binario (toybox) + CFI shadow del linker necesitan VMA adicional. 512 MB
 * dejaba demasiado poco y el mmap fallaba (linker_block_allocator
 * create_new_page CHECK 'page != MAP_FAILED'). 1 GB cubre el caso y sigue
 * protegiendo contra runaway (tar/python con leak). */
#define CHILD_RLIMIT_AS_MB (1024ULL * 1024ULL * 1024ULL)

/*
 * Aplica RLIMIT_AS en el child process ANTES de dlopen/execve.
 *
 * Sin límite, un `tar -x` de un archivo grande o un binario con leak puede
 * consumir RAM ilimitada en el worker (:nanoshell) y tumbarse el device.
 * 512MB cubre apt/dpkg/python típicos; overrides via NANOAI_RLIMIT_AS_MB.
 */
void apply_rlimit_as(void) {
    const char* env_override = getenv("NANOAI_RLIMIT_AS_MB");
    rlim_t limit = CHILD_RLIMIT_AS_MB;
    if (env_override && env_override[0]) {
        char* end = NULL;
        unsigned long mb = strtoul(env_override, &end, 10);
        if (end != env_override && mb > 0) limit = mb * 1024UL * 1024UL;
    }
    struct rlimit rl;
    rl.rlim_cur = limit;
    rl.rlim_max = limit;
    setrlimit(RLIMIT_AS, &rl);
}
