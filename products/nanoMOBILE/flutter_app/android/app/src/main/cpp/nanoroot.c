/*
 * nanoroot.c — LD_PRELOAD fakechroot library for NanoAI.
 *
 * Intercepts libc filesystem calls and redirects absolute paths to the
 * app's sandbox rootfs prefix. This lets binaries from the Termux bootstrap
 * see a proper Linux filesystem layout without needing ptrace/proot.
 *
 * Usage:
 *   LD_PRELOAD=libnanoroot.so NANO_ROOTFS=/data/data/.../files/nano/usr program
 *
 * Redirects:
 *   /usr       → $NANO_ROOTFS/..
 *   /etc       → $NANO_ROOTFS/etc
 *   /tmp       → $NANO_ROOTFS/../tmp
 *   /var       → $NANO_ROOTFS/var
 *   /home      → $NANO_ROOTFS/../home
 *   /proc      → (passthrough — Android's /proc is fine)
 *   /dev       → (passthrough)
 *   /sys       → (passthrough)
 *   /system    → (passthrough)
 *   /data      → (passthrough)
 *
 * Architecture:
 *   Uses __attribute__((constructor)) to load at dlopen time (before main).
 *   Reads NANO_ROOTFS from environment.
 *   Intercepts: open, openat, stat, lstat, fstatat, access, faccessat,
 *   mkdir, mkdirat, opendir, dlopen, readlink, realpath, unlink, rename.
 *
 * Build:
 *   NDK cmake, links against libc only.
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <stdarg.h>
#include <stdio.h>
#include <errno.h>
#include <limits.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/shm.h>

// ── State ──

static char g_prefix[PATH_MAX] = {0};
static size_t g_prefix_len = 0;

// Prefijo hardcodeado por termux-packages al compilar Xvnc, openbox,
// xkbcomp, etc. (asumen $PREFIX=/data/data/com.termux/files/usr). Nuestra
// app no es com.termux, asi que ese directorio no existe en nuestro
// sandbox: hay que redirigirlo siempre a g_prefix.
#define TERMUX_PREFIX "/data/data/com.termux/files/usr"
#define TERMUX_PREFIX_LEN (sizeof(TERMUX_PREFIX) - 1)

// ── Real libc functions (resolved via dlsym) ──

static int (*real_open)(const char*, int, ...) = NULL;
static int (*real_openat)(int, const char*, int, ...) = NULL;
static int (*real_stat)(const char*, struct stat*) = NULL;
static int (*real_lstat)(const char*, struct stat*) = NULL;
static int (*real_fstatat)(int, const char*, struct stat*, int) = NULL;
static int (*real_access)(const char*, int) = NULL;
static int (*real_faccessat)(int, const char*, int, int) = NULL;
static int (*real_mkdir)(const char*, mode_t) = NULL;
static int (*real_mkdirat)(int, const char*, mode_t) = NULL;
static DIR* (*real_opendir)(const char*) = NULL;
static ssize_t (*real_readlink)(const char*, char*, size_t) = NULL;
static char* (*real_realpath)(const char*, char*) = NULL;
static int (*real_unlink)(const char*) = NULL;
static int (*real_rename)(const char*, const char*) = NULL;
static int (*real_bind)(int, const struct sockaddr*, socklen_t) = NULL;
static int (*real_connect)(int, const struct sockaddr*, socklen_t) = NULL;
static int (*real_execve)(const char*, char* const*, char* const*) = NULL;
static int (*real_execvp)(const char*, char* const*) = NULL;
static int (*real_execvpe)(const char*, char* const*, char* const*) = NULL;
static FILE* (*real_popen)(const char*, const char*) = NULL;
static void* (*real_dlopen)(const char*, int) = NULL;

#define LOAD_SYM(name) do { \
    if (!real_##name) { \
        real_##name = dlsym(RTLD_NEXT, #name); \
        if (!real_##name) { fprintf(stderr, "nanoroot: dlsym(%s) failed\n", #name); _exit(1); } \
    } \
} while(0)

// ── Path redirection ──

// Returns 1 if path should be redirected, and writes the new path to *out.
// Returns 0 if path should be passed through as-is.
// Returns -1 if path is outside the redirected tree (use as-is for safety).
static int redirect_path(const char* path, char* out, size_t out_size) {
    if (!path || !g_prefix_len) return 0;

    // Relative paths: don't redirect (program handles relative to cwd)
    if (path[0] != '/') return 0;

    // Whitelist: paths we never redirect
    if (strncmp(path, "/proc/", 6) == 0 || strcmp(path, "/proc") == 0) return 0;
    if (strncmp(path, "/dev/", 5) == 0 || strcmp(path, "/dev") == 0) return 0;
    if (strncmp(path, "/sys/", 5) == 0 || strcmp(path, "/sys") == 0) return 0;
    if (strncmp(path, "/system/", 8) == 0 || strcmp(path, "/system") == 0) return 0;
    // Redirect Termux prefix to our rootfs (MUST be before /data whitelist).
    // Xvnc, openbox, etc. have /data/data/com.termux/files/usr/ hardcoded.
    if (strncmp(path, TERMUX_PREFIX, TERMUX_PREFIX_LEN) == 0 &&
        (path[TERMUX_PREFIX_LEN] == '/' || path[TERMUX_PREFIX_LEN] == '\0')) {
        int n = snprintf(out, out_size, "%s%s", g_prefix, path + TERMUX_PREFIX_LEN);
        if (n < 0 || (size_t)n >= out_size) return -1;
        return 1;
    }

    if (strncmp(path, "/data/", 6) == 0 || strcmp(path, "/data") == 0) return 0;
    if (strncmp(path, "/apex/", 6) == 0 || strcmp(path, "/apex") == 0) return 0;
    if (strncmp(path, "/storage/", 9) == 0 || strcmp(path, "/storage") == 0) return 0;
    if (strncmp(path, "/sdcard/", 8) == 0 || strcmp(path, "/sdcard") == 0) return 0;
    if (strncmp(path, "/vendor/", 8) == 0 || strcmp(path, "/vendor") == 0) return 0;
    if (strncmp(path, "/odm/", 5) == 0 || strcmp(path, "/odm") == 0) return 0;
    if (strncmp(path, "/product/", 9) == 0 || strcmp(path, "/product") == 0) return 0;

    // Special: /etc/resolv.conf → pass through (Android manages DNS)
    if (strcmp(path, "/etc/resolv.conf") == 0) return 0;

    // Redirect: /usr, /etc, /tmp, /var, /home, /bin, /sbin, /lib, /opt, /root
    int is_redirect = 0;
    if (strncmp(path, "/usr", 4) == 0 && (path[4] == '/' || path[4] == '\0')) is_redirect = 1;
    else if (strncmp(path, "/etc", 4) == 0 && (path[4] == '/' || path[4] == '\0')) is_redirect = 1;
    else if (strncmp(path, "/tmp", 4) == 0 && (path[4] == '/' || path[4] == '\0')) is_redirect = 1;
    else if (strncmp(path, "/var", 4) == 0 && (path[4] == '/' || path[4] == '\0')) is_redirect = 1;
    else if (strncmp(path, "/home", 5) == 0 && (path[5] == '/' || path[5] == '\0')) is_redirect = 1;
    else if (strncmp(path, "/bin", 4) == 0 && (path[4] == '/' || path[4] == '\0')) is_redirect = 1;
    else if (strncmp(path, "/sbin", 5) == 0 && (path[5] == '/' || path[5] == '\0')) is_redirect = 1;
    else if (strncmp(path, "/lib", 4) == 0 && (path[4] == '/' || path[4] == '\0')) is_redirect = 1;
    else if (strncmp(path, "/root", 5) == 0 && (path[5] == '/' || path[5] == '\0')) is_redirect = 1;

    if (!is_redirect) return 0;

    // Map: /usr/bin → {prefix}/../usr/bin  but our prefix is usr/, so:
    // /usr/bin → {prefix}/bin  (since prefix = .../files/nano/usr)
    // /etc → {prefix}/../etc  → .../files/nano/etc
    // /tmp → {prefix}/../tmp  → .../files/nano/tmp
    // /bin → {prefix}/../bin  → .../files/nano/bin  (symlink to usr/bin usually)

    // Strategy: construct {prefix_parent}/{rest of path after /usr}
    // prefix = .../files/nano/usr
    // prefix_parent = .../files/nano  (everything before last /)
    const char* last_slash = strrchr(g_prefix, '/');
    if (!last_slash) return 0;
    size_t parent_len = last_slash - g_prefix;

    if (strncmp(path, "/usr", 4) == 0) {
        // /usr/X → {prefix}/X (prefix IS usr/)
        int n = snprintf(out, out_size, "%s%s", g_prefix, path + 4);
        if (n < 0 || (size_t)n >= out_size) return -1;
        return 1;
    } else if (strncmp(path, "/bin", 4) == 0 && (path[4] == '/' || path[4] == '\0')) {
        // /bin → {prefix}/bin (Termux: usr/bin). El Popen interno de Xvnc
        // hace execl("/bin/sh", "sh", "-c", ...): sin este mapeo, /bin
        // caería en {parent}/bin (inexistente) y el xkbcomp jamás correría.
        int n = snprintf(out, out_size, "%s%s", g_prefix, path);
        if (n < 0 || (size_t)n >= out_size) return -1;
        return 1;
    } else if (strncmp(path, "/lib", 4) == 0 && (path[4] == '/' || path[4] == '\0')) {
        // /lib → {prefix}/lib (Termux: usr/lib)
        int n = snprintf(out, out_size, "%s%s", g_prefix, path);
        if (n < 0 || (size_t)n >= out_size) return -1;
        return 1;
    } else if (strncmp(path, "/sbin", 5) == 0 && (path[5] == '/' || path[5] == '\0')) {
        // /sbin → {prefix}/bin (Termux no tiene usr/sbin; toybox vive en usr/bin)
        int n = snprintf(out, out_size, "%s/bin%s", g_prefix, path + 5);
        if (n < 0 || (size_t)n >= out_size) return -1;
        return 1;
    } else {
        // /etc, /tmp, /var, /home → {parent}/path
        if (parent_len + strlen(path) >= out_size) return -1;
        memcpy(out, g_prefix, parent_len);
        strcpy(out + parent_len, path);
        return 1;
    }
}

// -- Generic Termux-prefix rewrite for exec argv / popen command strings --
//
// redirect_path() above translates a SINGLE full path. Some binaries embed
// the Termux prefix INSIDE arguments (e.g. xkbcomp's "-R/data/data/com.
// termux/files/usr/share/X11/xkb") or inside a whole shell command string
// passed to popen()/Popen(). This helper replaces every occurrence of
// TERMUX_PREFIX found anywhere in a string with g_prefix, however many
// times it appears. Returns 1 if at least one replacement was made (out is
// filled), 0 otherwise (out is untouched, caller should keep the original).
static int rewrite_termux_refs(const char* in, char* out, size_t out_size) {
    if (!in || !g_prefix_len) return 0;
    size_t out_pos = 0;
    const char* p = in;
    int replaced = 0;
    while (*p) {
        const char* hit = strstr(p, TERMUX_PREFIX);
        size_t chunk = hit ? (size_t)(hit - p) : strlen(p);
        if (out_pos + chunk + 1 > out_size) { out[out_pos] = '\0'; return replaced; }
        memcpy(out + out_pos, p, chunk);
        out_pos += chunk;
        if (!hit) break;
        if (out_pos + g_prefix_len + 1 > out_size) { out[out_pos] = '\0'; return replaced; }
        memcpy(out + out_pos, g_prefix, g_prefix_len);
        out_pos += g_prefix_len;
        p = hit + TERMUX_PREFIX_LEN;
        replaced = 1;
    }
    out[out_pos] = '\0';
    return replaced;
}

// Applies rewrite_termux_refs() to every entry of argv. Allocates a new
// NULL-terminated array (caller must free with free_rewritten_argv()).
// Entries without the Termux prefix are reused as-is (not copied).
static char** rewrite_argv(char* const argv[]) {
    if (!argv || !g_prefix_len) return NULL;
    int argc = 0;
    while (argv[argc]) argc++;
    char** out = calloc((size_t)argc + 1, sizeof(char*));
    if (!out) return NULL;
    int any = 0;
    for (int i = 0; i < argc; i++) {
        char buf[4096];
        if (argv[i] && rewrite_termux_refs(argv[i], buf, sizeof(buf))) {
            out[i] = strdup(buf);
            any = 1;
        } else {
            out[i] = argv[i];
        }
    }
    if (!any) {
        free(out);
        return NULL;
    }
    return out;
}

static void free_rewritten_argv(char** rewritten, char* const original[]) {
    if (!rewritten) return;
    for (int i = 0; original[i]; i++) {
        if (rewritten[i] != original[i]) free(rewritten[i]);
    }
    free(rewritten);
}

// -- Intercept: execve -> linker64 / dlopen (SELinux bypass) --
// On OPPO/ColorOS Android 15, execve syscall is blocked by SELinux from
// untrusted_app domain. Strategy:
//   1. Try real execve (works on non-restricted devices).
//   2. If EACCES: try dlopen+dlsym("main") (works for bash, busybox).
//   3. If binary is stripped (no "main"): try execve via /system/bin/linker64.
//      linker64 está en /system → SELinux permite el execve. El linker
//      construye proceso completo con aux vector, TLS y namespaces.
// execvp/execvpe son interceptados por separado.

typedef int (*main_t)(int, char**, char**);

// Intenta ejecutar el binario via linker64. Retorna 0 si éxito (no retorna
// realmente — el proceso es reemplazado), -1 si falla.
static int _try_linker64(const char* target, char* const argv[], char* const envp[]) {
    extern char** environ;
    // P1 (evidencia device 2026-08-12): en procesos que nacen vía linker64
    // (aterm, openbox, tint2), nano_execve_core() nunca corre y real_execve
    // queda NULL (static init). El primer exec del proceso suele ser
    // execlp()/execvpe() — p.ej. aterm -> execlp("bash") — y la cascada
    // llegaba aquí con real_execve == NULL: blr a 0x0 -> SIGSEGV (pc=0x0,
    // SEGV_MAPERR) y el terminal moría en loop cada 5s. Se resuelve lazy.
    if (!real_execve) {
        real_execve = dlsym(RTLD_NEXT, "execve");
        if (!real_execve) {
            fprintf(stderr, "nanoroot: dlsym(execve) falló en _try_linker64\n");
            return -1;
        }
    }
    // Contar argc
    int argc = 0;
    while (argv && argv[argc]) argc++;

    // Construir argv para linker64: ["linker64", target, arg1, ...]
    char** linker_argv = malloc(sizeof(char*) * (argc + 2));
    if (!linker_argv) return -1;
    linker_argv[0] = "/system/bin/linker64";
    linker_argv[1] = (char*)target;
    for (int i = 1; i < argc; i++) linker_argv[i + 1] = argv[i];
    linker_argv[argc + 1] = NULL;

    // real_execve esquiva nuestro intercept (es la función original de libc).
    int ret = real_execve("/system/bin/linker64", linker_argv, envp ? envp : environ);
    free(linker_argv);
    return ret;
}

// -- Instrumentación de diagnóstico (append a archivo) --
// El Popen interno del X server descarta stdout/stderr del hijo, así que
// fprintf(stderr) no llega a xvnc_err.txt. Este helper escribe directo a
// usr/tmp/nanoroot_exec.log para ver el flujo real del exec.
static int dbg_exec_enabled = -1; // 1 = sí, 0 = no (leer env una vez)
static void dbg_exec(const char* msg) {
    if (dbg_exec_enabled == -1) {
        const char* e = getenv("NANOROOT_DEBUG_EXEC");
        dbg_exec_enabled = (e && e[0] && e[0] != '0') ? 1 : 0;
    }
    if (dbg_exec_enabled != 1 || !g_prefix_len) return;
    char lp[PATH_MAX];
    snprintf(lp, sizeof(lp), "%s/tmp/nanoroot_exec.log", g_prefix);
    FILE* f = fopen(lp, "a");
    if (!f) return;
    fprintf(f, "%s\n", msg);
    fclose(f);
}

// Core compartido de execve: redirect + rewrite argv + cascada SELinux
// (execve real -> linker64 -> dlopen/dlsym(main)). execve() y execl() lo
// llaman; execl lo necesita porque bionic liga execl->execve por símbolo
// interno NO interposable — el Popen del X server (os/utils.c) usa
// execl("/bin/sh", "sh", "-c", ...) y jamás pasaba por el intercept execve.
static int nano_execve_core(const char* pathname, char* const argv[], char* const envp[]) {
    LOAD_SYM(execve);

    char new_path[PATH_MAX];
    const char* target = pathname;
    if (redirect_path(pathname, new_path, sizeof(new_path)) == 1) {
        target = new_path;
    }

    // xkbcomp: el wrapper sh de usr/bin no puede ejecutarse vía execve bajo
    // SELinux (appdomain sin execute sobre app_data_file — el kernel
    // chequea el inodo del script antes del shebang) y la cascada
    // dlopen/linker64 solo procesa ELFs. Apuntar directo al ELF real.
    {
        size_t tlen = strlen(target);
        // Sufijo "/bin/xkbcomp" mide 12 chars (antes 11: off-by-one que
        // hacía que el fix jamás aplicara y la cascada lanzara el linker64
        // contra el SCRIPT wrapper -> "bad ELF magic: 23212f73" -> keymap fail).
        if (tlen >= 12 && strcmp(target + tlen - 12, "/bin/xkbcomp") == 0) {
            int n = snprintf(new_path, sizeof(new_path), "%s/xkbcomp.real", g_prefix);
            if (n > 0 && (size_t)n < sizeof(new_path)) target = new_path;
        }
    }

    // Algunos binarios (xkbcomp, etc.) reciben argumentos con el prefijo de
    // Termux hardcodeado (p.ej. "-R/data/data/com.termux/files/usr/...").
    // redirect_path() de arriba solo corrige el ejecutable en si; esto
    // corrige el resto de los argumentos.
    char** eff_argv = rewrite_argv(argv);
    char* const* use_argv = eff_argv ? (char* const*)eff_argv : argv;

    // Diagnóstico: ver el argv exacto que recibe el linker64/Xvnc.
    if (strstr(target, "Xvnc") || strstr(target, "linker64")) {
        char buf[1024];
        int off = 0;
        for (int i = 0; use_argv && use_argv[i] && off < (int)sizeof(buf) - 64; i++) {
            off += snprintf(buf + off, sizeof(buf) - off, "[%s] ", use_argv[i]);
        }
        fprintf(stderr, "nanoroot: execve argv: %s\n", buf);
        fflush(stderr);
    }

    // Log de entrada (archivo): quién se ejecuta y con qué argv[0].
    {
        char m[1024];
        int argc = 0;
        while (use_argv && use_argv[argc]) argc++;
        snprintf(m, sizeof(m), "exec: %s -> %s argc=%d argv0=[%s]",
                 pathname, target, argc, (use_argv && use_argv[0]) ? use_argv[0] : "-");
        dbg_exec(m);
    }

    // Intento 1: execve real (funciona en dispositivos sin restricción SELinux)
    int ret = real_execve(target, use_argv, envp);

    if (ret == -1) {
        char m[1024];
        snprintf(m, sizeof(m), "exec rc=-1 errno=%d target=%s", errno, target);
        dbg_exec(m);
    }

    // Si SELinux bloqueó (EACCES), intentar alternativas
    if (ret == -1 && errno == EACCES) {
        // Intento 2: execve via linker64 (proceso real con aux vector, TLS,
        // signal dispositions reseteadas, namespaces limpios).
        // EVIDENCIA device 2026-08-12: aterm moría exit=0 a ~300ms tras
        // forkpty — el dlopen-in-process corría bash DENTRO del child de rxvt
        // sin reset de handlers; bash moría al instante y aterm salía limpio.
        // Mismo fallo documentado en nanoshell.c: openbox murió status=1 con
        // dlopen-in-process. Por eso linker64 va ANTES que dlopen.
        if (_try_linker64(target, use_argv, envp) == 0) {
            // _try_linker64 no retorna si éxito (proceso reemplazado)
            _exit(0);
        }
        dbg_exec("exec EACCES: linker64 falló");

        // Intento 3: dlopen + dlsym("main") — funciona con bash, busybox, etc.
        void* handle = dlopen(target, RTLD_NOW | RTLD_GLOBAL);
        dbg_exec(handle ? "exec EACCES: dlopen OK" : "exec EACCES: dlopen falló");
        if (handle) {
            main_t binary_main = (main_t)dlsym(handle, "main");
            dbg_exec(binary_main ? "exec EACCES: dlsym(main) OK" : "exec EACCES: dlsym(main) falló");
            if (binary_main) {
                int argc = 0;
                while (use_argv && use_argv[argc]) argc++;
                int exit_code = binary_main(argc, (char**)use_argv, (char**)envp);
                dlclose(handle);
                _exit(exit_code);
            }
            dlclose(handle);
        }

        fprintf(stderr, "nanoroot: todos los intentos fallaron para %s\r\n", target);
        if (eff_argv) free_rewritten_argv(eff_argv, argv);
        errno = ENOEXEC;
        return -1;
    }

    if (eff_argv) free_rewritten_argv(eff_argv, argv);
    return ret;
}

// execl: reconstruye argv de los varargs y delega en el core. Sin este
// intercept, el execl("/bin/sh", ...) del Popen del X server esquiva el
// redirect de /bin -> {prefix}/bin y el xkbcomp jamás se ejecuta.
int execl(const char* path, const char* arg0, ...) {
    va_list ap;
    va_start(ap, arg0);
    int cap = 16, n = 0;
    char** argv = (char**)calloc((size_t)cap, sizeof(char*));
    if (!argv) { va_end(ap); errno = ENOMEM; return -1; }
    argv[n++] = (char*)arg0;
    const char* a;
    while ((a = va_arg(ap, const char*)) != NULL) {
        if (n + 1 >= cap) {
            cap *= 2;
            char** na = (char**)realloc(argv, (size_t)cap * sizeof(char*));
            if (!na) { free(argv); va_end(ap); errno = ENOMEM; return -1; }
            argv = na;
        }
        argv[n++] = (char*)a;
    }
    va_end(ap);
    argv[n] = NULL;
    extern char** environ;
    int ret = nano_execve_core(path, argv, environ);
    free(argv);
    return ret;
}

int execve(const char* pathname, char* const argv[], char* const envp[]) {
    return nano_execve_core(pathname, argv, envp);
}

// execvp: searches PATH, then calls execve internally.
int execvp(const char* file, char* const argv[]) {
    LOAD_SYM(execvp);

    char new_path[PATH_MAX];
    const char* target = file;
    if (redirect_path(file, new_path, sizeof(new_path)) == 1) {
        target = new_path;
    }

    // xkbcomp: mismo fix que execve (wrapper sh → ELF real).
    {
        size_t tlen = strlen(target);
        // Sufijo "/bin/xkbcomp" mide 12 chars (antes 11: off-by-one que
        // hacía que el fix jamás aplicara y la cascada lanzara el linker64
        // contra el SCRIPT wrapper -> "bad ELF magic: 23212f73" -> keymap fail).
        if (tlen >= 12 && strcmp(target + tlen - 12, "/bin/xkbcomp") == 0) {
            int n = snprintf(new_path, sizeof(new_path), "%s/xkbcomp.real", g_prefix);
            if (n > 0 && (size_t)n < sizeof(new_path)) target = new_path;
        }
    }

    char** eff_argv = rewrite_argv(argv);
    char* const* use_argv = eff_argv ? (char* const*)eff_argv : argv;

    int ret = real_execvp(target, use_argv);
    if (ret == -1 && errno == EACCES) {
        // Misma cascada que execve: linker64 (proceso real) ANTES que dlopen.
        if (_try_linker64(target, use_argv, NULL) == 0) _exit(0);
        void* handle = dlopen(target, RTLD_NOW | RTLD_GLOBAL);
        if (handle) {
            main_t binary_main = (main_t)dlsym(handle, "main");
            if (binary_main) {
                int argc = 0;
                while (use_argv && use_argv[argc]) argc++;
                extern char** environ;
                int exit_code = binary_main(argc, (char**)use_argv, environ);
                dlclose(handle);
                _exit(exit_code);
            }
            dlclose(handle);
        }
        if (eff_argv) free_rewritten_argv(eff_argv, argv);
        errno = ENOENT;
        return -1;
    }
    if (eff_argv) free_rewritten_argv(eff_argv, argv);
    return ret;
}

// execvpe: like execvp but with explicit envp
int execvpe(const char* file, char* const argv[], char* const envp[]) {
    LOAD_SYM(execvpe);

    char new_path[PATH_MAX];
    const char* target = file;
    if (redirect_path(file, new_path, sizeof(new_path)) == 1) {
        target = new_path;
    }

    // xkbcomp: mismo fix que execve (wrapper sh → ELF real).
    {
        size_t tlen = strlen(target);
        // Sufijo "/bin/xkbcomp" mide 12 chars (antes 11: off-by-one que
        // hacía que el fix jamás aplicara y la cascada lanzara el linker64
        // contra el SCRIPT wrapper -> "bad ELF magic: 23212f73" -> keymap fail).
        if (tlen >= 12 && strcmp(target + tlen - 12, "/bin/xkbcomp") == 0) {
            int n = snprintf(new_path, sizeof(new_path), "%s/xkbcomp.real", g_prefix);
            if (n > 0 && (size_t)n < sizeof(new_path)) target = new_path;
        }
    }

    char** eff_argv = rewrite_argv(argv);
    char* const* use_argv = eff_argv ? (char* const*)eff_argv : argv;

    int ret = real_execvpe(target, use_argv, envp);
    if (ret == -1 && errno == EACCES) {
        // Misma cascada que execve: linker64 (proceso real) ANTES que dlopen.
        if (_try_linker64(target, use_argv, envp) == 0) _exit(0);
        void* handle = dlopen(target, RTLD_NOW | RTLD_GLOBAL);
        if (handle) {
            main_t binary_main = (main_t)dlsym(handle, "main");
            if (binary_main) {
                int argc = 0;
                while (use_argv && use_argv[argc]) argc++;
                int exit_code = binary_main(argc, (char**)use_argv, (char**)envp);
                dlclose(handle);
                _exit(exit_code);
            }
            dlclose(handle);
        }
        if (eff_argv) free_rewritten_argv(eff_argv, argv);
        errno = ENOENT;
        return -1;
    }
    if (eff_argv) free_rewritten_argv(eff_argv, argv);
    return ret;
}

// ── Intercept: open ──

int open(const char* pathname, int flags, ...) {
    LOAD_SYM(open);
    char new_path[PATH_MAX];
    if (redirect_path(pathname, new_path, sizeof(new_path)) == 1) {
        va_list ap;
        va_start(ap, flags);
        mode_t mode = 0;
        if (flags & O_CREAT) mode = va_arg(ap, mode_t);
        va_end(ap);
        return real_open(new_path, flags, mode);
    }
    va_list ap;
    va_start(ap, flags);
    mode_t mode = 0;
    if (flags & O_CREAT) mode = va_arg(ap, mode_t);
    va_end(ap);
    return real_open(pathname, flags, mode);
}

// ── Intercept: openat ──

int openat(int dirfd, const char* pathname, int flags, ...) {
    LOAD_SYM(openat);
    if (pathname && pathname[0] == '/') {
        char new_path[PATH_MAX];
        if (redirect_path(pathname, new_path, sizeof(new_path)) == 1) {
            va_list ap;
            va_start(ap, flags);
            mode_t mode = 0;
            if (flags & O_CREAT) mode = va_arg(ap, mode_t);
            va_end(ap);
            return real_openat(dirfd, new_path, flags, mode);
        }
    }
    va_list ap;
    va_start(ap, flags);
    mode_t mode = 0;
    if (flags & O_CREAT) mode = va_arg(ap, mode_t);
    va_end(ap);
    return real_openat(dirfd, pathname, flags, mode);
}

// ── Intercept: stat ──

int stat(const char* pathname, struct stat* statbuf) {
    LOAD_SYM(stat);
    char new_path[PATH_MAX];
    if (redirect_path(pathname, new_path, sizeof(new_path)) == 1) {
        return real_stat(new_path, statbuf);
    }
    return real_stat(pathname, statbuf);
}

int lstat(const char* pathname, struct stat* statbuf) {
    LOAD_SYM(lstat);
    char new_path[PATH_MAX];
    if (redirect_path(pathname, new_path, sizeof(new_path)) == 1) {
        return real_lstat(new_path, statbuf);
    }
    return real_lstat(pathname, statbuf);
}

int fstatat(int dirfd, const char* pathname, struct stat* statbuf, int flags) {
    LOAD_SYM(fstatat);
    if (pathname && pathname[0] == '/') {
        char new_path[PATH_MAX];
        if (redirect_path(pathname, new_path, sizeof(new_path)) == 1) {
            return real_fstatat(dirfd, new_path, statbuf, flags);
        }
    }
    return real_fstatat(dirfd, pathname, statbuf, flags);
}

// ── Intercept: access ──

int access(const char* pathname, int mode) {
    LOAD_SYM(access);
    char new_path[PATH_MAX];
    if (redirect_path(pathname, new_path, sizeof(new_path)) == 1) {
        return real_access(new_path, mode);
    }
    return real_access(pathname, mode);
}

int faccessat(int dirfd, const char* pathname, int mode, int flags) {
    LOAD_SYM(faccessat);
    if (pathname && pathname[0] == '/') {
        char new_path[PATH_MAX];
        if (redirect_path(pathname, new_path, sizeof(new_path)) == 1) {
            return real_faccessat(dirfd, new_path, mode, flags);
        }
    }
    return real_faccessat(dirfd, pathname, mode, flags);
}

// ── Intercept: mkdir ──

int mkdir(const char* pathname, mode_t mode) {
    LOAD_SYM(mkdir);
    char new_path[PATH_MAX];
    if (redirect_path(pathname, new_path, sizeof(new_path)) == 1) {
        return real_mkdir(new_path, mode);
    }
    return real_mkdir(pathname, mode);
}

int mkdirat(int dirfd, const char* pathname, mode_t mode) {
    LOAD_SYM(mkdirat);
    if (pathname && pathname[0] == '/') {
        char new_path[PATH_MAX];
        if (redirect_path(pathname, new_path, sizeof(new_path)) == 1) {
            return real_mkdirat(dirfd, new_path, mode);
        }
    }
    return real_mkdirat(dirfd, pathname, mode);
}

// ── Intercept: opendir ──

DIR* opendir(const char* name) {
    LOAD_SYM(opendir);
    char new_path[PATH_MAX];
    if (redirect_path(name, new_path, sizeof(new_path)) == 1) {
        return real_opendir(new_path);
    }
    return real_opendir(name);
}

// ── Intercept: dlopen ──
// El dynamic linker de Android resuelve el path con sus propios open/stat
// internos: la redirección de openat NO aplica dentro del linker. Sin este
// intercept, dlopen("/data/data/com.termux/files/usr/lib/imlib2/loaders/
// pnm.so") falla "library not found" y apps como feh/imlib2 quedan sin
// loaders ("No Imlib2 loader for that file format"), GIO sin módulos, etc.

void* dlopen(const char* filename, int flags) {
    LOAD_SYM(dlopen);
    if (filename && filename[0] == '/') {
        char new_path[PATH_MAX];
        if (redirect_path(filename, new_path, sizeof(new_path)) == 1) {
            return real_dlopen(new_path, flags);
        }
    }
    return real_dlopen(filename, flags);
}

// ── Intercept: readlink ──

ssize_t readlink(const char* pathname, char* buf, size_t bufsiz) {
    LOAD_SYM(readlink);
    char new_path[PATH_MAX];
    if (redirect_path(pathname, new_path, sizeof(new_path)) == 1) {
        return real_readlink(new_path, buf, bufsiz);
    }
    // For redirectable paths, rewrite the result to strip the prefix
    // (complex, skip for now)
    return real_readlink(pathname, buf, bufsiz);
}

// ── Intercept: realpath ──

char* realpath(const char* path, char* resolved_path) {
    LOAD_SYM(realpath);
    char new_path[PATH_MAX];
    if (redirect_path(path, new_path, sizeof(new_path)) == 1) {
        char* result = real_realpath(new_path, resolved_path);
        // TODO: strip prefix from result so it shows /usr/bin/bash, not .../files/nano/usr/bin/bash
        return result;
    }
    return real_realpath(path, resolved_path);
}

// ── Intercept: unlink ──

int unlink(const char* pathname) {
    LOAD_SYM(unlink);
    char new_path[PATH_MAX];
    if (redirect_path(pathname, new_path, sizeof(new_path)) == 1) {
        return real_unlink(new_path);
    }
    return real_unlink(pathname);
}

// ── Intercept: rename ──

int rename(const char* oldpath, const char* newpath) {
    LOAD_SYM(rename);
    char new_old[PATH_MAX], new_new[PATH_MAX];
    int r1 = redirect_path(oldpath, new_old, sizeof(new_old));
    int r2 = redirect_path(newpath, new_new, sizeof(new_new));
    const char* o = (r1 == 1) ? new_old : oldpath;
    const char* n = (r2 == 1) ? new_new : newpath;
    return real_rename(o, n);
}

// ── Intercept: shmget ──
// Kernels Android compilan con CONFIG_SYSVIPC=n: shmget (syscall arm64 194)
// devuelve ENOSYS. ColorOS ademas aplica seccomp a los procesos de la app
// que convierte esa syscall en SIGSYS y mata el proceso (lxterminal/gtk3
// muere via libGLX_mesa y libcairo, ambos usan MIT-SHM). Toda la cadena
// GTK/cairo maneja ENOSYS con fallback limpio (verificado: sin seccomp el
// mismo binario renderiza bien). Devolvemos ENOSYS sin llamar al kernel.

int shmget(key_t key, size_t size, int shmflg) {
    (void)key; (void)size; (void)shmflg;
    errno = ENOSYS;
    return -1;
}

// ── Intercept: bind ──

int bind(int sockfd, const struct sockaddr* addr, socklen_t addrlen) {
    LOAD_SYM(bind);
    // Redirigir sun_path: Xvnc crea el socket .X11-unix con el path de
    // Termux hardcodeado en sockaddr_un. mkdir/chmod/stat sí se redirigen,
    // pero bind() sin intercept apuntaría al /data/data/com.termux literal
    // (inexistente) y el listener X11 fallaría con ENOENT — dejando a
    // openbox sin display.
    if (addr && addr->sa_family == AF_UNIX && addrlen >= sizeof(sa_family_t)) {
        struct sockaddr_un* sun = (struct sockaddr_un*)addr;
        char new_path[sizeof(sun->sun_path)];
        int rd = redirect_path(sun->sun_path, new_path, sizeof(new_path));
        fprintf(stderr, "nanoroot: bind AF_UNIX pid=%d [%s] redirect=%d\n", getpid(), sun->sun_path, rd);
        fflush(stderr);
        if (rd == 1) {
            struct sockaddr_un copy = *sun;
            strncpy(copy.sun_path, new_path, sizeof(copy.sun_path) - 1);
            copy.sun_path[sizeof(copy.sun_path) - 1] = '\0';
            // El addrlen del llamador corresponde al path ORIGINAL (corto,
            // 49 chars Termux). Con el path redirigido (62 chars) y el
            // addrlen viejo, el kernel trunca sun_path a un directorio
            // (".../usr/tmp/.") y bind() devuelve EADDRINUSE — por eso el
            // socket X1 nunca se creaba aunque el dir estuviera vacío.
            socklen_t new_addrlen = (socklen_t)((char*)copy.sun_path - (char*)&copy) +
                                    (socklen_t)strlen(new_path) + 1;
            int r = real_bind(sockfd, (struct sockaddr*)&copy, new_addrlen);
            fprintf(stderr, "nanoroot: bind %s -> %s (rc=%d errno=%d)\n",
                    sun->sun_path, new_path, r, r < 0 ? errno : 0);
            fflush(stderr);
            return r;
        }
    }
    return real_bind(sockfd, addr, addrlen);
}

// ── Intercept: connect ──

int connect(int sockfd, const struct sockaddr* addr, socklen_t addrlen) {
    LOAD_SYM(connect);
    // openbox/libX11 buscan el display en /tmp/.X11-unix/X1. Redirigir
    // igual que bind() para que encuentren el socket real del rootfs.
    if (addr && addr->sa_family == AF_UNIX && addrlen >= sizeof(sa_family_t)) {
        struct sockaddr_un* sun = (struct sockaddr_un*)addr;
        char new_path[sizeof(sun->sun_path)];
        if (redirect_path(sun->sun_path, new_path, sizeof(new_path)) == 1) {
            struct sockaddr_un copy = *sun;
            strncpy(copy.sun_path, new_path, sizeof(copy.sun_path) - 1);
            copy.sun_path[sizeof(copy.sun_path) - 1] = '\0';
            // Mismo ajuste de addrlen que en bind(): sin él, el kernel
            // trunca el path redirigido y el connect apunta a un directorio.
            socklen_t new_addrlen = (socklen_t)((char*)copy.sun_path - (char*)&copy) +
                                    (socklen_t)strlen(new_path) + 1;
            int r = real_connect(sockfd, (struct sockaddr*)&copy, new_addrlen);
            fprintf(stderr, "nanoroot: connect %s -> %s (rc=%d errno=%d)\n",
                    sun->sun_path, new_path, r, r < 0 ? errno : 0);
            fflush(stderr);
            return r;
        }
    }
    return real_connect(sockfd, addr, addrlen);
}

// ── Intercept: popen ──

FILE* popen(const char* command, const char* type) {
    LOAD_SYM(popen);
    if (!command) return real_popen(command, type);

    // Xvnc invokes xkbcomp (and possibly other helpers) via a full shell
    // command string with the Termux prefix hardcoded, e.g.:
    //   "/data/data/com.termux/files/usr/bin/xkbcomp" -w 1 \
    //     "-R/data/data/com.termux/files/usr/share/X11/xkb" ... \
    //     "/data/data/com.termux/files/usr/tmp/server-0.xkm"
    // A single occurrence-based rewrite is not enough: the prefix appears
    // multiple times (binary path, -R argument, output path). Rewrite
    // every occurrence to our own rootfs prefix.
    char rewritten[4096];
    if (!rewrite_termux_refs(command, rewritten, sizeof(rewritten))) {
        return real_popen(command, type);
    }

    // El wrapper sh en usr/bin/xkbcomp NO puede ejecutarse vía execve bajo
    // SELinux: appdomain no tiene execute sobre app_data_file (el kernel
    // chequea el inodo del script antes del shebang) y la cascada
    // dlopen/linker64 de execve() solo procesa ELFs. Reescritura directa
    // al binario ELF real, que la cascada sí arranca vía linker64.
    {
        const char* hit = strstr(rewritten, "usr/bin/xkbcomp");
        if (hit) {
            char final_cmd[4096];
            size_t before = (size_t)(hit - rewritten);
            size_t after = before + strlen("usr/bin/xkbcomp");
            size_t repl_len = strlen("usr/xkbcomp.real");
            if (before + repl_len + (strlen(rewritten) - after) < sizeof(final_cmd)) {
                memcpy(final_cmd, rewritten, before);
                memcpy(final_cmd + before, "usr/xkbcomp.real", repl_len);
                strcpy(final_cmd + before + repl_len, rewritten + after);
                fprintf(stderr, "nanoroot: popen xkbcomp -> ELF real\n");
                fflush(stderr);
                return real_popen(final_cmd, type);
            }
        }
    }

    fprintf(stderr, "nanoroot: popen rewrote termux refs: %s\n", rewritten);
    fflush(stderr);
    return real_popen(rewritten, type);
}

// ── Constructor: read NANO_ROOTFS from environment ──

__attribute__((constructor)) static void nanoroot_init(void) {
    const char* env = getenv("NANO_ROOTFS");
    if (!env) {
        // Silent: no LD_PRELOAD without NANO_ROOTFS set
        return;
    }
    strncpy(g_prefix, env, sizeof(g_prefix) - 1);
    g_prefix[sizeof(g_prefix) - 1] = '\0';
    g_prefix_len = strlen(g_prefix);

    // Remove trailing slash
    while (g_prefix_len > 0 && g_prefix[g_prefix_len - 1] == '/') {
        g_prefix[--g_prefix_len] = '\0';
    }

    fprintf(stderr, "nanoroot: prefix=%s (len=%zu)\n", g_prefix, g_prefix_len);

    // Diagnóstico: cmdline real del proceso (Xvnc vía linker64).
    {
        char cmdline[1024];
        FILE* f = fopen("/proc/self/cmdline", "r");
        if (f) {
            size_t n = fread(cmdline, 1, sizeof(cmdline) - 1, f);
            fclose(f);
            cmdline[n] = '\0';
            for (size_t i = 0; i < n; i++) if (cmdline[i] == '\0') cmdline[i] = ' ';
            fprintf(stderr, "nanoroot: cmdline=[%s]\n", cmdline);
            fflush(stderr);
        }
    }
}
