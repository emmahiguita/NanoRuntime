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
 *   mkdir, mkdirat, opendir, readlink, realpath, unlink, rename.
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

// ── State ──

static char g_prefix[PATH_MAX] = {0};
static size_t g_prefix_len = 0;

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
static int (*real_execve)(const char*, char* const*, char* const*) = NULL;
static int (*real_execvp)(const char*, char* const*) = NULL;
static int (*real_execvpe)(const char*, char* const*, char* const*) = NULL;

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
    if (strncmp(path, "/data/data/com.termux/files/usr", 33) == 0) {
        int n = snprintf(out, out_size, "%s%s", g_prefix, path + 33);
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
    } else {
        // /etc, /tmp, /var, /home, /bin, /sbin, /lib → {parent}/path
        if (parent_len + strlen(path) >= out_size) return -1;
        memcpy(out, g_prefix, parent_len);
        strcpy(out + parent_len, path);
        return 1;
    }
}

// ── Intercept: execve → linker64 / dlopen (SELinux bypass) ──
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

int execve(const char* pathname, char* const argv[], char* const envp[]) {
    LOAD_SYM(execve);

    char new_path[PATH_MAX];
    const char* target = pathname;
    if (redirect_path(pathname, new_path, sizeof(new_path)) == 1) {
        target = new_path;
    }

    // Intento 1: execve real (funciona en dispositivos sin restricción SELinux)
    int ret = real_execve(target, argv, envp);

    // Si SELinux bloqueó (EACCES), intentar alternativas
    if (ret == -1 && errno == EACCES) {
        // Intento 2: dlopen + dlsym("main") — funciona con bash, busybox, etc.
        void* handle = dlopen(target, RTLD_NOW | RTLD_GLOBAL);
        if (handle) {
            main_t binary_main = (main_t)dlsym(handle, "main");
            if (binary_main) {
                int argc = 0;
                while (argv && argv[argc]) argc++;
                int exit_code = binary_main(argc, argv, (char**)envp);
                dlclose(handle);
                _exit(exit_code);
            }
            dlclose(handle);
        }

        // Intento 3: execve via linker64 (binarios stripped sin "main")
        // linker64 construye proceso completo con aux vector, TLS, namespaces.
        if (_try_linker64(target, argv, envp) == 0) {
            // _try_linker64 no retorna si éxito (proceso reemplazado)
            _exit(0);
        }

        fprintf(stderr, "nanoroot: todos los intentos fallaron para %s\r\n", target);
        errno = ENOEXEC;
        return -1;
    }

    return ret;
}

// execvp: searches PATH, then calls execve internally.
int execvp(const char* file, char* const argv[]) {
    LOAD_SYM(execvp);

    char new_path[PATH_MAX];
    const char* target = file;
    if (redirect_path(file, new_path, sizeof(new_path)) == 1) {
        target = new_path;
    }

    int ret = real_execvp(target, argv);
    if (ret == -1 && errno == EACCES) {
        // Misma cascada que execve: dlopen → linker64
        void* handle = dlopen(target, RTLD_NOW | RTLD_GLOBAL);
        if (handle) {
            main_t binary_main = (main_t)dlsym(handle, "main");
            if (binary_main) {
                int argc = 0;
                while (argv && argv[argc]) argc++;
                extern char** environ;
                int exit_code = binary_main(argc, argv, environ);
                dlclose(handle);
                _exit(exit_code);
            }
            dlclose(handle);
        }
        if (_try_linker64(target, argv, NULL) == 0) _exit(0);
        errno = ENOENT;
        return -1;
    }
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

    int ret = real_execvpe(target, argv, envp);
    if (ret == -1 && errno == EACCES) {
        void* handle = dlopen(target, RTLD_NOW | RTLD_GLOBAL);
        if (handle) {
            main_t binary_main = (main_t)dlsym(handle, "main");
            if (binary_main) {
                int argc = 0;
                while (argv && argv[argc]) argc++;
                int exit_code = binary_main(argc, argv, (char**)envp);
                dlclose(handle);
                _exit(exit_code);
            }
            dlclose(handle);
        }
        if (_try_linker64(target, argv, envp) == 0) _exit(0);
        errno = ENOENT;
        return -1;
    }
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
}
