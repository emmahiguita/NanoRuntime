/*
 * nanoshell.c — In-process binary execution for NanoAI.
 *
 * Problem: SELinux on OPPO/ColorOS blocks execve() from app data dirs.
 * Solution: fork() + dlopen() + call main() in child. No execve().
 *
 * Two modes:
 *   1. busybox mode: dlopen("libbusybox.so") → busybox_main (fast path)
 *   2. generic mode: dlopen("/absolute/path/to/binary.so") → main (any PIE binary)
 *
 * LD_PRELOAD support: sets LD_PRELOAD=libnanoroot.so in child if
 * NANO_ROOTFS is set, enabling fakechroot path redirection.
 */

#define _GNU_SOURCE
#include <android/log.h>
#include <dlfcn.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/resource.h>
#include <unistd.h>
#include <sys/wait.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <limits.h>
#include <poll.h>

#include "util.h"  // count_argv, apply_env (shared with pty.c)

// dlinfo() and RTLD_DI_LINKMAP are bionic-only, not in public NDK headers.
// They exist at runtime on Android 9+ (API 28) but aren't linked from libdl.so
// at compile time (NDK API 26 target). Resolve dlinfo dynamically via dlsym.
#ifndef RTLD_DI_LINKMAP
#define RTLD_DI_LINKMAP 2
#endif
typedef int (*dlinfo_fn_t)(void* handle, int request, void* info);

// â”€â”€ Forward declarations â”€â”€

int nanoshell_spawn_busybox(
    const char* const argv[],
    const char* const envp[],
    char** out_stdout,
    char** out_stderr
);

int nanoshell_spawn_generic(
    const char* binary_path,
    const char* const argv[],
    const char* const envp[],
    const char* ld_preload,
    char** out_stdout,
    char** out_stderr
);

void nanoshell_free_string(char* str);
const char* nanoshell_last_error(void);

// â”€â”€ Internal state â”€â”€

static char g_last_error[512] = {0};

// â”€â”€ Core: fork + dlopen + main â”€â”€

// _count_argv and _apply_env are now in util.h/util.c (shared with pty.c).
// Use count_argv() and apply_env() directly.

// e_entry (entry point _start) de un ELF PIE dlopen'ed. El .so se carga en
// una base aleatoria: la direccion real es base + e_entry. dl_iterate_phdr
// da el base (dlpi_addr) de cada objeto cargado; se matchea por path.
#include <link.h>
struct dl_iterate_ctx { const char* path; uintptr_t* base; };

static int _match_base(struct dl_phdr_info* info, size_t size, void* data) {
    struct dl_iterate_ctx* c = (struct dl_iterate_ctx*)data;
    (void)size;
    if (!info->dlpi_name || !info->dlpi_name[0]) return 0;
    const char* base_name = strrchr(c->path, '/');
    base_name = base_name ? base_name + 1 : c->path;

    // Exact path-boundary match: avoid false positives like
    // /a/foo.so matching /a/foobar.so (strstr alone is fragile).
    const char* found = strstr(info->dlpi_name, base_name);
    if (found) {
        // Verify match is at path boundary: followed by '\0' or '/'
        const char* after = found + strlen(base_name);
        if (*after == '\0' || *after == '/') {
            *c->base = (uintptr_t)info->dlpi_addr;
            return 1;
        }
    }
    return 0;
}

static void* _elf_entry_of(const char* path) {
    if (!path || !path[0]) return NULL;
    FILE* f = fopen(path, "rb");
    if (!f) return NULL;
    unsigned char hdr[64];
    size_t got = fread(hdr, 1, sizeof(hdr), f);
    fclose(f);
    if (got < 0x20) return NULL;
    if (hdr[0] != 0x7f || hdr[1] != 'E' || hdr[2] != 'L' || hdr[3] != 'F') return NULL;
    int is64 = (hdr[4] == 2);
    uintptr_t e_entry = 0;
    if (is64) memcpy(&e_entry, hdr + 0x18, 8);
    else { uint32_t e32; memcpy(&e32, hdr + 0x18, 4); e_entry = e32; }
    if (e_entry == 0) return NULL;

    uintptr_t base = 0;
    struct dl_iterate_ctx ctx = { path, &base };
    dl_iterate_phdr(_match_base, &ctx);

    // e_entry es un offset dentro del .so: direccion real = base + e_entry.
    return (void*)(base + e_entry);
}

// â”€â”€ Trampolín de arranque ARM64 (nivel global) â”€â”€
// Construye el stack de bionic para el _start de binarios C++ (apt):
// sp[0]=argc, sp[1..argc]=argv, sp[argc+1]=NULL, sp[argc+2]=NULL, x29=0.
#if defined(__aarch64__)
__attribute__((naked)) static void _start_trampoline_arm64(void) {
    __asm__ volatile(
        "mov x19, x0\n"
        "mov w20, w1\n"
        "mov x21, x2\n"
        "add w22, w20, #2\n"
        "lsl x22, x22, #3\n"
        "and x22, x22, #~15\n"
        "sub sp, sp, x22\n"
        "str w20, [sp]\n"
        "mov x0, x21\n"
        "add x1, sp, #8\n"
        "mov w2, w20\n"
        "cbz w2, 2f\n"
        "1:\n"
        "ldr x3, [x0], #8\n"
        "str x3, [x1], #8\n"
        "subs w2, w2, #1\n"
        "bne 1b\n"
        "2:\n"
        "add x3, sp, #8\n"
        "lsl x4, x20, #3\n"
        "add x3, x3, x4\n"
        "str xzr, [x3]\n"
        "str xzr, [x3, #8]\n"
        "mov x29, xzr\n"
        "br x19\n"
    );
}
static int _call_stack_entry(void* entry, int argc, char** argv) {
    typedef int (*fn_t)(void*, int, char**);
    ((fn_t)(uintptr_t)_start_trampoline_arm64)(entry, argc, argv);
    return 0; // no retorna: el entry hace exit()
}
#endif

// Preload libs del rootfs que el TARGET necesita. El preload masivo (todas
// las libs) crasheaba el driver GPU del proceso principal (SIGSEGV en
// mali-compiler): dlopen de ~117 libs en el hijo dispara los hilos del GPU
// heredados. En su lugar cargamos SOLO las libs base del rootfs (las deps
// comunes de binarios Termux: libc++, android-support, crypto, etc.) —
// suficiente para que el linker resuelva el DT_NEEDED del target.
static const char* const kRootfsBaseLibs[] = {
    "libc++_shared.so",
    "libandroid-support.so",
    "libandroid-glob.so",
    "libandroid-posix-semaphore.so",
    "libandroid-selinux.so",
    "libcrypto.so.3",
    "libssl.so.3",
    "libz.so.1",
    "libzstd.so.1",
    "libbz2.so.1.0",
    "liblzma.so.5",
    "libiconv.so",
    "libcharset.so",
    "libpcre2-8.so",
    "libffi.so",
    "libpng16.so",
    "libbrotlicommon.so",
    "libbrotlidec.so",
    "libfreetype.so",
    "libXau.so",
    "libXau.so.6",
    "libXdmcp.so",
    "libXdmcp.so.6",
    "libxcb.so",
    "libxcb.so.1",
    "libX11.so",
    "libX11.so.6",
    "libXext.so",
    "libXext.so.6",
    "libpixman-1.so",
    "libpixman-1.so.0",
    "libxfont2.so",
    "libxfont2.so.2",
    "libxkbfile.so",
    "libxkbfile.so.1",
    "libunistring.so",
    "libunistring.so.5",
    "libidn2.so",
    "libidn2.so.0",
    "libexpat.so",
    "libexpat.so.1",
    "libfontconfig.so",
    "libfontconfig.so.1",
    NULL
};

static void _preload_rootfs_libs(const char* dir) {
    char path[600];

    // Cargar con android_dlopen_ext + ANDROID_DLEXT_USE_NAMESPACE en el
    // namespace del APK (classloader-namespace, clns-7). Así las libs
    // versionadas (libz.so.1) quedan registradas en clns-7 — el MISMO
    // namespace donde apt (libapt-pkg.so del APK) resuelve sus DT_NEEDED.
    typedef struct android_namespace_t android_namespace_t;
    typedef android_namespace_t* (*android_get_exported_namespace_t)(const char*);
    typedef void* (*android_dlopen_ext_t)(const char*, int, const void*);
    android_get_exported_namespace_t get_ns = NULL;
    android_dlopen_ext_t dlopen_ext = NULL;
    android_namespace_t* ns = NULL;
#if defined(__ANDROID__)
    get_ns = (android_get_exported_namespace_t)dlsym(RTLD_DEFAULT,
                "android_get_exported_namespace");
    dlopen_ext = (android_dlopen_ext_t)dlsym(RTLD_DEFAULT, "android_dlopen_ext");
    if (get_ns) ns = get_ns("classloader-namespace");
#endif

    for (int i = 0; kRootfsBaseLibs[i] != NULL; i++) {
        snprintf(path, sizeof(path), "%s/%s", dir, kRootfsBaseLibs[i]);
        void* h = NULL;
#if defined(__ANDROID__)
        if (dlopen_ext && ns) {
            // android_dlextinfo: flags + library_namespace (ANDROID_DLEXT_USE_NAMESPACE = 0x200)
            struct { uint64_t flags; const char* lp; void* fd; long off; const android_namespace_t* ns_; const char* soname; const char* sdk; const char* fdp; void* offs; } ext;
            memset(&ext, 0, sizeof(ext));
            ext.flags = 0x200;
            ext.ns_ = ns;
            h = dlopen_ext(path, RTLD_NOW | RTLD_GLOBAL, &ext);
        }
#endif
        if (!h) h = dlopen(path, RTLD_NOW | RTLD_GLOBAL);
        if (!h) {
            // No fatal: lib opcional (no todas están en todos los rootfs).
            fprintf(stderr, "nanoshell: preload %s warning: %s\n", path, dlerror());
        }
        // Keep handle open (RTLD_GLOBAL queda registrado en el proceso).
    }
    fprintf(stderr, "nanoshell: preload done for %s\n", dir);
}

// The actual fork+exec logic, shared by busybox and generic variants.
// In child: dlopen the library, find main(), call it.
// In parent: collect stdout/stderr, wait for child.
static int _spawn_internal(
    const char* lib_path,
    const char* main_symbol,
    const char* const argv[],
    const char* const envp[],
    const char* ld_preload,
    char** out_stdout,
    char** out_stderr,
    size_t* out_stdout_len,
    size_t* out_stderr_len
) {
    *out_stdout = NULL;
    *out_stderr = NULL;
    *out_stdout_len = 0;
    *out_stderr_len = 0;
    g_last_error[0] = '\0';

    if (!argv || !argv[0]) {
        snprintf(g_last_error, sizeof(g_last_error), "NULL argv");
        return -1;
    }

    int out_pipe[2], err_pipe[2];
    if (pipe(out_pipe) < 0) { snprintf(g_last_error, sizeof(g_last_error), "pipe(out): %s", strerror(errno)); return -1; }
    if (pipe(err_pipe) < 0) { snprintf(g_last_error, sizeof(g_last_error), "pipe(err): %s", strerror(errno)); close(out_pipe[0]); close(out_pipe[1]); return -1; }

    pid_t pid = fork();
    if (pid < 0) {
        snprintf(g_last_error, sizeof(g_last_error), "fork: %s", strerror(errno));
        close(out_pipe[0]); close(out_pipe[1]);
        close(err_pipe[0]); close(err_pipe[1]);
        return -1;
    }

    if (pid == 0) {
        // === CHILD ===
        close(out_pipe[0]);
        close(err_pipe[0]);
        dup2(out_pipe[1], STDOUT_FILENO);
        dup2(err_pipe[1], STDERR_FILENO);
        close(out_pipe[1]);
        close(err_pipe[1]);

        // Close all other fds (simple heuristic)
        for (int fd = 3; fd < 256; fd++) {
            if (fd != STDOUT_FILENO && fd != STDERR_FILENO) close(fd);
        }

        // Cap virtual memory BEFORE starting the binary: a runaway tar/leaky
        // daemon can't exhaust device RAM (worker process, shared with app).
        // Override via NANOAI_RLIMIT_AS_MB.
        apply_rlimit_as();

        // Apply environment variables BEFORE dlopen so that
        // libnanoroot's constructor can read NANO_ROOTFS from env.
        apply_env(envp);

        // â”€â”€ Memory limit (512 MB soft cap) â”€â”€
        // Delegates to util.c which reads NANOAI_RLIMIT_AS_MB env override.
        apply_rlimit_as();

        // Set LD_PRELOAD before execve so the kernel linker loads it.
        if (ld_preload && ld_preload[0]) {
            setenv("LD_PRELOAD", ld_preload, 1);
        }

        // Prefer direct execve with the prepared environment. On ColorOS,
        // forcing /system/bin/linker64 can abort with MapShadow before the
        // target binary starts, so we only fall back to dlopen here.
        if (lib_path && lib_path[0]) {
            extern char** environ;
            execve(lib_path, (char* const*)argv, environ);
            fprintf(stderr, "nanoshell: execve(%s) fallo: %s -- usando dlopen\n",
                    lib_path, strerror(errno));
        }

        // â”€â”€ Fallback: dlopen + main / trampolín â”€â”€
        // Preload fakechroot library BEFORE the target binary.
        if (ld_preload && ld_preload[0]) {
            void* preload_handle = dlopen(ld_preload, RTLD_NOW | RTLD_GLOBAL);
            if (!preload_handle) {
                fprintf(stderr, "nanoshell: dlopen(%s) warning: %s\n",
                        ld_preload, dlerror());
            }
        }

        // Preload libs of the rootfs (usr/lib) with RTLD_GLOBAL so the app
        // namespace can resolve the target's DT_NEEDED. Android namespaces
        // ignore LD_LIBRARY_PATH; dlopen manual registra las libs en el
        // namespace del proceso y el linker las encuentra después.
        // NANO_ROOTFS (inyectado por execRootfs) localiza usr/lib.
        {
            const char* nano_rootfs = getenv("NANO_ROOTFS");
            if (nano_rootfs && nano_rootfs[0]) {
                char libdir[512];
                snprintf(libdir, sizeof(libdir), "%s/lib", nano_rootfs);
                // El linker del namespace reporta paths canónicos
                // (/data/data/... porque user/0 es symlink). Si preloadamos
                // con /data/user/0/..., el registro no coincide con lo que el
                // linker busca → "not found". realpath() canoniza.
                char canon[PATH_MAX];
                if (realpath(libdir, canon)) {
                    _preload_rootfs_libs(canon);
                } else {
                    _preload_rootfs_libs(libdir);
                }
            }
        }

        // Determine what to dlopen. Usar realpath: el linker reporta el
        // binario como /data/data/... (user/0 es symlink); dlopen con
        // /data/user/0/... puede entrar en un namespace distinto.
        char dl_real[PATH_MAX];
        const char* dl_path = lib_path ? lib_path : "libbusybox.so";
        if (lib_path && lib_path[0] == '/' && realpath(lib_path, dl_real)) {
            dl_path = dl_real;
        }

        // Android aísla namespaces: un dlopen simple de apt usa el namespace
        // por defecto, que NO ve libs de usr/lib (solo APK/system). La vía
        // oficial: android_create_namespace con permitted_paths=usr/lib, y
        // cargar apt en ese namespace con android_dlopen_ext. Fallback con
        // ANDROID_DLEXT_EXTEND_RELAXED (extiende el namespace del proceso).
        void* handle = NULL;
#if defined(__ANDROID__)
        {
            typedef struct android_namespace_t android_namespace_t;
            typedef android_namespace_t* (*android_create_namespace_t)(
                const char* name, const char* ld_library_path,
                const char* default_library_path, uint64_t type,
                const char* permitted_when_isolated, android_namespace_t* parent);
            typedef android_namespace_t* (*android_get_exported_namespace_t)(const char*);
            typedef void* (*android_dlopen_ext_t)(const char*, int, const void*);

            static const uint64_t ANDROID_NAMESPACE_TYPE_ISOLATED_ = 0x1;
            static const uint64_t ANDROID_DLEXT_USE_NAMESPACE_ = 0x200;
            // ANDROID_DLEXT_EXTEND_RELAXED = 0x8000: permite que un dlopen
            // extienda el namespace actual con rutas no estándar.
            static const uint64_t ANDROID_DLEXT_EXTEND_RELAXED_ = 0x8000;

            android_create_namespace_t create_ns =
                (android_create_namespace_t)dlsym(RTLD_DEFAULT, "android_create_namespace");
            android_dlopen_ext_t dlopen_ext =
                (android_dlopen_ext_t)dlsym(RTLD_DEFAULT, "android_dlopen_ext");
            android_get_exported_namespace_t get_ns =
                (android_get_exported_namespace_t)dlsym(RTLD_DEFAULT,
                    "android_get_exported_namespace");

            const char* nano_rootfs = getenv("NANO_ROOTFS");
            char libdir[512];
            if (nano_rootfs && nano_rootfs[0]) {
                snprintf(libdir, sizeof(libdir), "%s/lib", nano_rootfs);
            } else {
                snprintf(libdir, sizeof(libdir), "%s", "/data/data/com.termux/files/usr/lib");
            }

            struct {
                uint64_t flags;
                const char* library_path;
                void* library_fd;
                long library_offset;
                const android_namespace_t* library_namespace;
                const char* library_soname;
                const char* target_sdk_version;
                const char* library_path_fd;
                void* library_path_offsets;
            } ext;
            memset(&ext, 0, sizeof(ext));

            // Intento 1: namespace aislado con permitted_paths=usr/lib.
            if (create_ns && dlopen_ext) {
                android_namespace_t* app_ns = get_ns ? get_ns("classloader-namespace") : NULL;
                android_namespace_t* ns = create_ns("nanoai_rootfs", libdir, libdir,
                                       ANDROID_NAMESPACE_TYPE_ISOLATED_,
                                       libdir, app_ns);
                if (ns) {
                    ext.flags = ANDROID_DLEXT_USE_NAMESPACE_;
                    ext.library_namespace = ns;
                    handle = dlopen_ext(dl_path, RTLD_NOW | RTLD_GLOBAL, &ext);
                    if (!handle) fprintf(stderr, "nanoshell: ns1+parent: %s\n", dlerror());
                }
            }
            // Intento 2: EXTEND_RELAXED + library_path=usr/lib: el campo
            // library_path del dlextinfo extiende la ruta de búsqueda de libs
            // para la lib CARGADA (apt), permitiendo resolver DT_NEEDED de
            // usr/lib (libz.so.1, libssl.so.3...) en el namespace del proceso.
            if (!handle && dlopen_ext) {
                memset(&ext, 0, sizeof(ext));
                ext.flags = ANDROID_DLEXT_EXTEND_RELAXED_;
                ext.library_path = libdir;
                handle = dlopen_ext(dl_path, RTLD_NOW | RTLD_GLOBAL, &ext);
                if (!handle) fprintf(stderr, "nanoshell: ns2 relaxed: %s\n", dlerror());
            }
            if (!handle && create_ns) {
                // Intento 3: namespace sin parent (raíz) con usr/lib.
                android_namespace_t* ns = create_ns("nanoai_rootfs2", libdir, libdir,
                                       ANDROID_NAMESPACE_TYPE_ISOLATED_,
                                       libdir, NULL);
                if (ns) {
                    memset(&ext, 0, sizeof(ext));
                    ext.flags = ANDROID_DLEXT_USE_NAMESPACE_;
                    ext.library_namespace = ns;
                    handle = dlopen_ext(dl_path, RTLD_NOW | RTLD_GLOBAL, &ext);
                    if (!handle) fprintf(stderr, "nanoshell: ns3 raiz: %s\n", dlerror());
                }
            }
        }
        if (!handle) handle = dlopen(dl_path, RTLD_NOW | RTLD_GLOBAL);
#else
        handle = dlopen(dl_path, RTLD_NOW | RTLD_GLOBAL);
#endif
        if (!handle) {
            fprintf(stderr, "nanoshell: dlopen(%s) failed: %s\n", dl_path, dlerror());
            _exit(127);
        }

        // Find main function. Try the specified symbol first, then fallbacks.
        typedef int (*main_fn)(int, char**, char**);
        static int _use_stack_entry = 0;
        static void* _stack_entry = NULL;
        main_fn entry = NULL;

        // Try requested symbol
        entry = (main_fn)dlsym(handle, main_symbol);

        // Fallbacks for common naming conventions
        if (!entry) entry = (main_fn)dlsym(handle, "main");
        if (!entry) entry = (main_fn)dlsym(handle, "_main");

        if (!entry) {
            // Binarios C++ (apt) NO exportan "main": su entry es el e_entry
            // del ELF (_start). El _start de bionic espera el STACK de
            // arranque ARM64: sp[0]=argc, sp[1..]=argv, luego envp=NULL, y
            // el vector auxiliar. Se construye ese frame y se salta con la
            // ABI del proceso (x29=0, x30=exit). No es una llamada C normal.
            void* elf_entry = _elf_entry_of(lib_path);
            if (elf_entry) {
                fprintf(stderr, "nanoshell: usando e_entry 0x%llx de %s\n",
                        (unsigned long long)(uintptr_t)elf_entry, dl_path);
                entry = (main_fn)elf_entry;
                _stack_entry = elf_entry;
                _use_stack_entry = 1;
            }
        }

        if (!entry) {
            fprintf(stderr, "nanoshell: dlsym(%s or main) failed: %s\n", main_symbol, dlerror());
            dlclose(handle);
            _exit(127);
        }

        // Build mutable argv (NULL-checked: OOM in child → _exit gracefully)
        int argc = count_argv(argv);
        char** mutable_argv = malloc(sizeof(char*) * (argc + 1));
        if (!mutable_argv) {
            fprintf(stderr, "nanoshell: malloc(mutable_argv) failed (OOM)\n");
            _exit(126);
        }
        for (int i = 0; i < argc; i++) {
            mutable_argv[i] = strdup(argv[i]);
            if (!mutable_argv[i]) _exit(126); // Check for OOM to prevent malformation
        }
        mutable_argv[argc] = NULL;

        int rc = 0;
        if (_use_stack_entry && _stack_entry) {
#if defined(__aarch64__)
            _call_stack_entry(_stack_entry, argc, mutable_argv);
            // No retorna: _start hace exit(). Evitar retorno no definido.
            _exit(0);
#else
            rc = entry(argc, mutable_argv, (char**)envp);
#endif
        } else {
            rc = entry(argc, mutable_argv, (char**)envp);
        }

        for (int i = 0; i < argc; i++) free(mutable_argv[i]);
        free(mutable_argv);
        dlclose(handle);
        _exit(rc);
    }

    // === PARENT ===
    close(out_pipe[1]);
    close(err_pipe[1]);

    // Read stdout and stderr CONCURRENTLY with poll().
    // Sequential _slurp_fd(out) → _slurp_fd(err) causes deadlock when
    // child writes >64KB to stderr while parent blocks on stdout read.
    // poll() drains whichever pipe has data, then waitpid() safely.
    size_t out_len = 0, err_len = 0;
    size_t out_cap = 4096, err_cap = 4096;
    char* stdout_buf = malloc(out_cap);
    char* stderr_buf = malloc(err_cap);
    if (!stdout_buf || !stderr_buf) {
        free(stdout_buf); free(stderr_buf);
        close(out_pipe[0]); close(err_pipe[0]);
        waitpid(pid, NULL, 0);
        *out_stdout = strdup("");
        *out_stderr = strdup("");
        return -1;
    }

    int out_eof = 0, err_eof = 0;
    struct pollfd fds[2];
    fds[0].fd = out_pipe[0]; fds[0].events = POLLIN;
    fds[1].fd = err_pipe[0]; fds[1].events = POLLIN;

    while (!out_eof || !err_eof) {
        int ret = poll(fds, 2, 30000); // 30s timeout — child hung
        if (ret < 0) {
            if (errno == EINTR) continue;
            break;
        }
        if (ret == 0) {
            fprintf(stderr, "nanoshell: poll timeout — killing child\n");
            kill(pid, SIGKILL);
            break;
        }

        // stdout
        if (fds[0].revents & (POLLIN | POLLHUP)) {
            ssize_t n = read(out_pipe[0],
                stdout_buf + out_len, out_cap - out_len - 1);
            if (n > 0) {
                out_len += n;
                if (out_len >= out_cap - 1) {
                    out_cap *= 2;
                    char* nb = realloc(stdout_buf, out_cap);
                    if (!nb) break;
                    stdout_buf = nb;
                }
            } else {
                out_eof = 1;
                fds[0].fd = -1; // stop polling this fd
            }
        }

        // stderr
        if (fds[1].revents & (POLLIN | POLLHUP)) {
            ssize_t n = read(err_pipe[0],
                stderr_buf + err_len, err_cap - err_len - 1);
            if (n > 0) {
                err_len += n;
                if (err_len >= err_cap - 1) {
                    err_cap *= 2;
                    char* nb = realloc(stderr_buf, err_cap);
                    if (!nb) break;
                    stderr_buf = nb;
                }
            } else {
                err_eof = 1;
                fds[1].fd = -1;
            }
        }
    }

    if (stdout_buf) stdout_buf[out_len] = '\0';
    if (stderr_buf) stderr_buf[err_len] = '\0';
    close(out_pipe[0]);
    close(err_pipe[0]);

    // Now wait for child to finish (pipes already drained concurrently)
    int status;
    waitpid(pid, &status, 0);

    *out_stdout = stdout_buf ? stdout_buf : strdup("");
    *out_stderr = stderr_buf ? stderr_buf : strdup("");
    if (out_stdout_len) *out_stdout_len = out_len;
    if (out_stderr_len) *out_stderr_len = err_len;

    if (WIFEXITED(status)) return WEXITSTATUS(status);
    if (WIFSIGNALED(status)) return 128 + WTERMSIG(status);
    return -1;
}

// â”€â”€ Public API â”€â”€

int nanoshell_spawn_busybox(
    const char* const argv[],
    const char* const envp[],
    char** out_stdout,
    char** out_stderr
) {
    return _spawn_internal(
        NULL,              // lib_path = NULL → dlopen("libbusybox.so")
        "busybox_main",    // main_symbol
        argv, envp,
        NULL,              // no LD_PRELOAD for standalone busybox
        out_stdout, out_stderr,
        NULL, NULL         // no length tracking needed for text
    );
}

int nanoshell_spawn_generic(
    const char* binary_path,
    const char* const argv[],
    const char* const envp[],
    const char* ld_preload,
    char** out_stdout,
    char** out_stderr
) {
    return _spawn_internal(
        binary_path,
        "main",
        argv, envp,
        ld_preload,
        out_stdout, out_stderr,
        NULL, NULL
    );
}

void nanoshell_free_string(char* str) {
    free(str);
}

const char* nanoshell_last_error(void) {
    return g_last_error;
}

// â”€â”€ Worker-process spawn (sin GPU) â”€â”€
// Ejecuta el binario vía _spawn_internal y escribe stdout/stderr/rc a
// archivos en filesDir (el proceso principal los lee; los punteros nativos
// no cruzan procesos). Solo se invoca desde NanoshellWorkerService (proceso
// :nanoshell, sin Flutter/GPU → fork+dlopen seguro).
int nanoshell_worker_spawn(
    const char* binary_path,
    const char* const argv[],
    const char* const envp[],
    const char* ld_preload,
    const char* task_id,
    const char* files_dir
) {
    char* out_s = NULL;
    char* err_s = NULL;
    size_t out_len = 0, err_len = 0;
    int rc = _spawn_internal(binary_path, "main", argv, envp, ld_preload,
                             &out_s, &err_s, &out_len, &err_len);

    char out_path[512], err_path[512], rc_path[512];
    char tmp_out[530], tmp_err[530], tmp_rc[530];
    if (task_id && task_id[0] && files_dir && files_dir[0]) {
        snprintf(out_path, sizeof(out_path), "%s/worker_out_%s", files_dir, task_id);
        snprintf(err_path, sizeof(err_path), "%s/worker_err_%s", files_dir, task_id);
        snprintf(rc_path, sizeof(rc_path), "%s/worker_rc_%s", files_dir, task_id);
        // Atomic rename: escribir a temp + rename evita que el proceso Dart
        // lea archivos parcialmente escritos (TOCTOU entre existsSync y read).
        snprintf(tmp_out, sizeof(tmp_out), "%s.tmp", out_path);
        snprintf(tmp_err, sizeof(tmp_err), "%s.tmp", err_path);
        snprintf(tmp_rc, sizeof(tmp_rc), "%s.tmp", rc_path);

        FILE* fo = fopen(tmp_out, "wb");
        if (fo) { if (out_s) fwrite(out_s, 1, out_len, fo); fclose(fo); rename(tmp_out, out_path); }
        FILE* fe = fopen(tmp_err, "wb");
        if (fe) { if (err_s) fwrite(err_s, 1, err_len, fe); fclose(fe); rename(tmp_err, err_path); }
        FILE* fr = fopen(tmp_rc, "wb");
        if (fr) { fprintf(fr, "%d", rc); fclose(fr); rename(tmp_rc, rc_path); }
    }

    free(out_s);
    free(err_s);
    return rc;
}

// â”€â”€ Daemon spawn (sin esperar) â”€â”€
// Para procesos long-running (Xvnc, openbox, etc.). fork+exec sin waitpid.
// Redirige stdout/stderr a /dev/null. Retorna PID (>0) o -1 si falla.
//
// setenv("LD_PRELOAD", ...) here is the critical part: daemons like Xvnc
// are launched below via execve() (directly, or via /system/bin/linker64).
// execve() replaces the whole process image, so a dlopen() done in THIS
// process before the call is discarded and never applies to the exec'd
// binary. Setting LD_PRELOAD in the environment survives execve() because
// bionic's dynamic linker reads it again when loading the new image, so it
// preloads libnanoroot.so and its open()/unlink()/mkdir() wrappers into
// Xvnc itself. Without this, Xvnc's hardcoded Termux paths
// (/data/data/com.termux/files/usr/tmp/.tX0-lock) never get redirected to
// our own rootfs prefix and Xvnc aborts with "Could not create lock file".
static void _load_nanoroot_for_detached(void) {
    const char* native_dir = getenv("NANO_NATIVE_LIB_DIR");
    static char preload_path[PATH_MAX];
    const char* target = "libnanoroot.so";

    if (native_dir && native_dir[0]) {
        snprintf(preload_path, sizeof(preload_path), "%s/libnanoroot.so", native_dir);
        target = preload_path;
    }

    setenv("LD_PRELOAD", target, 1);

    void* h = dlopen(target, RTLD_NOW | RTLD_GLOBAL);
    if (!h) {
        __android_log_print(ANDROID_LOG_WARN, "nanoshell-detached",
            "dlopen nanoroot failed (%s): %s", target, dlerror());
    } else {
        __android_log_print(ANDROID_LOG_INFO, "nanoshell-detached",
            "nanoroot loaded for detached daemon: %s", target);
    }
}

int nanoshell_worker_spawn_detached(
    const char* binary_path,
    const char* const argv[],
    const char* const envp[])
{
    if (!binary_path || !binary_path[0]) {
        __android_log_print(ANDROID_LOG_ERROR, "nanoshell-detached",
            "spawn rejected: empty binary_path");
        return -1;
    }

    const char* base_name = strrchr(binary_path, '/');
    base_name = base_name ? base_name + 1 : binary_path;
    const char* fallback_argv[] = { base_name, NULL };
    const char* const* safe_argv = (argv && argv[0]) ? argv : fallback_argv;

    pid_t pid = fork();
    if (pid < 0) {
        __android_log_print(ANDROID_LOG_ERROR, "nanoshell-detached",
            "fork failed for %s: %s", binary_path, strerror(errno));
        return -1;
    }

    if (pid == 0) {
        // Child path for graphical daemons. Keep inherited FDs because Xvnc
        // launches helper processes such as xkbcomp.

        // Do not apply RLIMIT_AS to graphical daemons. Xvnc and X11 libs map
        // large virtual regions even when RSS stays moderate.

        // Grupo propio: los daemons gráficos (Xvnc/openbox/tint2) NO deben
        // vivir en el process group del worker — workerKillGroup() mata con
        // kill(-getpgrp(), SIGKILL) y se llevaría el escritorio entero. Con
        // setsid() sobreviven al kill del worker y solo mueren por su PID
        // explícito (backend.stop()/cleanupProcesses). El reaper del worker
        // sigue cubriéndolos (siguen siendo sus hijos).
        if (setsid() < 0) {
            __android_log_print(ANDROID_LOG_WARN, "nanoshell-detached",
                "setsid() failed: %s (daemon queda en el grupo del worker)",
                strerror(errno));
        }

        if (envp) {
            for (int i = 0; envp[i]; i++) {
                char* dup = strdup(envp[i]);
                if (dup) {
                    char* eq = strchr(dup, '=');
                    if (eq) {
                        *eq = '\0';
                        setenv(dup, eq + 1, 1);
                    }
                    free(dup);
                }
            }
        }

        // NO pisar el entorno que Kotlin ya construyó (baseEnv) — una sola
        // fuente de verdad para LD_LIBRARY_PATH/HOME/TMPDIR. El fallback
        // hardcodeado solo aplica para callers que no pasan envp.
        if (!getenv("LD_LIBRARY_PATH")) {
            setenv("LD_LIBRARY_PATH",
                   "/data/user/0/dev.nanoai.mobile/files/nano/usr/lib:"
                   "/data/data/dev.nanoai.mobile/files/nano/usr/lib:"
                   "/system/lib64", 1);
        }
        if (!getenv("HOME")) {
            setenv("HOME", "/data/user/0/dev.nanoai.mobile/files/nano/home", 1);
        }
        if (!getenv("TMPDIR")) {
            setenv("TMPDIR", "/data/user/0/dev.nanoai.mobile/files/nano/usr/tmp", 1);
        }
        if (!getenv("NANO_ROOTFS")) {
            setenv("NANO_ROOTFS", "/data/user/0/dev.nanoai.mobile/files/nano/usr", 1);
        }
        _load_nanoroot_for_detached();

        mkdir("/data/user/0/dev.nanoai.mobile/files/nano/usr/tmp", 0700);
        // Log por proceso: cada daemon escribe su propio stderr. Un archivo
        // compartido se pisaba (openbox/tint2 truncaban el FatalError de Xvnc).
        char logname[64];
        const char* lbase = binary_path ? strrchr(binary_path, '/') : NULL;
        lbase = lbase ? lbase + 1 : (binary_path ? binary_path : "daemon");
        int li = 0;
        for (; lbase[li] && li < 47; li++)
            logname[li] = (lbase[li] >= 'A' && lbase[li] <= 'Z') ? lbase[li] + 32 : lbase[li];
        memcpy(logname + li, "_err.txt", 9);
        char logpath[576];
        snprintf(logpath, sizeof(logpath),
                 "/data/user/0/dev.nanoai.mobile/files/nano/usr/tmp/%s", logname);
        __android_log_print(ANDROID_LOG_DEBUG, "nanoshell-detached",
            "opening log %s for %s", logpath, binary_path);
        int logfd = open(logpath, O_WRONLY | O_CREAT | O_TRUNC, 0600);
        if (logfd >= 0) {
            dup2(logfd, STDOUT_FILENO);
            dup2(logfd, STDERR_FILENO);
            if (logfd > 2) close(logfd);
            __android_log_print(ANDROID_LOG_DEBUG, "nanoshell-detached",
                "stderr redirected to %s (fd=%d)", logpath, STDERR_FILENO);
        } else {
            __android_log_print(ANDROID_LOG_WARN, "nanoshell-detached",
                "failed to open log %s: %s (stderr stays inherited)",
                logpath, strerror(errno));
        }

        int argc = count_argv(safe_argv);
        extern char** environ;

        // 1. execve directo del binario. En ColorOS falla con EACCES sobre
        // binarios del sandbox; en otros dispositivos es el camino bueno.
        __android_log_print(ANDROID_LOG_INFO, "nanoshell-detached",
            "execve(%s) argc=%d", binary_path ? binary_path : "<null>", argc);
        execve(binary_path, (char* const*)safe_argv, environ);
        __android_log_print(ANDROID_LOG_WARN, "nanoshell-detached",
            "execve(%s) failed: %s — trying linker64",
            binary_path ? binary_path : "<null>", strerror(errno));
        fprintf(stderr, "nanoshell-detached: execve(%s) failed: %s\n",
                binary_path ? binary_path : "<null>", strerror(errno));

        // 2. execve(/system/bin/linker64, binario): crea su propio namespace
        //    y resuelve DT_NEEDED vía LD_LIBRARY_PATH. Evidencia device
        //    2026-08-12: Xvnc, tint2 y openbox SOLO funcionan por esta vía.
        //    El dlopen in-process (paso 3) hace que openbox muera status=1
        //    (~400ms): sin input method, sin rc.xml, sin theme — binarios X11
        //    asumen proceso real. Por eso linker64 va ANTES que dlopen.
        //
        //    El linker64 entrega al target argv[0] = binary_path y coloca el
        //    argv original como argumentos a partir de argv[1]. Si el argv
        //    del spawn trae argv[0] = basename del binario (p. ej. "openbox"),
        //    el target lo recibe como ARGUMENTO y lo rechaza: "Invalid command
        //    line argument 'openbox'". Se dropea ese duplicado del nombre.
        //    (argv[0] = ":1" de Xvnc no es duplicado → no se dropea nada.)
        {
            int args_start = 0;
            if (argc > 0 && safe_argv[0] && strcmp(safe_argv[0], base_name) == 0) {
                args_start = 1;
            }
            int n_args = argc - args_start;
            char** linker_argv = calloc((size_t)n_args + 3, sizeof(char*));
            if (linker_argv) {
                linker_argv[0] = "/system/bin/linker64";
                linker_argv[1] = (char*)binary_path;
                for (int i = 0; i < n_args; i++) {
                    linker_argv[i + 2] = (char*)safe_argv[args_start + i];
                }
                linker_argv[n_args + 2] = NULL;
                __android_log_print(ANDROID_LOG_INFO, "nanoshell-detached",
                    "execve(linker64,%s) argc=%d (args=%d)",
                    binary_path, argc, n_args);
                execve("/system/bin/linker64", linker_argv, environ);
                fprintf(stderr, "nanoshell-detached: execve(linker64,%s) failed: %s\n",
                        binary_path, strerror(errno));
                free(linker_argv);
            }
        }

        // 3. Fallback dlopen in-process. Solo si linker64 falló.
        typedef void* (*android_dlopen_ext_t)(const char*, int, const void*);
        android_dlopen_ext_t dlopen_ext_fn =
            (android_dlopen_ext_t)dlsym(RTLD_DEFAULT, "android_dlopen_ext");

        char libdir[512];
        const char* bin_sep = binary_path ? strstr(binary_path, "/bin/") : NULL;
        if (bin_sep) {
            int prefix_len = (int)(bin_sep - binary_path);
            snprintf(libdir, sizeof(libdir), "%.*s/lib", prefix_len, binary_path);
        } else {
            snprintf(libdir, sizeof(libdir),
                "/data/user/0/dev.nanoai.mobile/files/nano/usr/lib");
        }

        struct {
            uint64_t flags;
            const char* library_path;
            void* library_fd;
            long library_offset;
            void* library_namespace;
            const char* library_soname;
            const char* target_sdk_version;
            const char* library_path_fd;
            void* library_path_offsets;
        } ext_info;
        memset(&ext_info, 0, sizeof(ext_info));
        ext_info.flags = 0x1; // ANDROID_DLEXT_USE_LIBRARY_PATH
        ext_info.library_path = libdir;

        void* handle = NULL;
        if (dlopen_ext_fn) {
            __android_log_print(ANDROID_LOG_DEBUG, "nanoshell-detached",
                "trying android_dlopen_ext(%s) with lib path %s", binary_path, libdir);
            handle = dlopen_ext_fn(binary_path, RTLD_NOW | RTLD_GLOBAL, &ext_info);
            if (!handle) {
                const char* err = dlerror();
                fprintf(stderr, "nanoshell-detached: android_dlopen_ext(%s) failed: %s\n",
                        binary_path ? binary_path : "<null>", err ? err : "<no dlerror>");
                __android_log_print(ANDROID_LOG_WARN, "nanoshell-detached",
                    "android_dlopen_ext(%s) failed: %s", binary_path, err ? err : "<no dlerror>");
            }
        }
        if (!handle) {
            handle = dlopen(binary_path, RTLD_NOW | RTLD_GLOBAL);
            if (!handle) {
                const char* err = dlerror();
                fprintf(stderr, "nanoshell-detached: dlopen(%s) failed: %s\n",
                        binary_path ? binary_path : "<null>", err ? err : "<no dlerror>");
                __android_log_print(ANDROID_LOG_ERROR, "nanoshell-detached",
                    "dlopen(%s) failed: %s — no more fallbacks", binary_path, err ? err : "<no dlerror>");
            } else {
                __android_log_print(ANDROID_LOG_INFO, "nanoshell-detached",
                    "plain dlopen(%s) succeeded", binary_path);
            }
        }

        if (handle) {
            __android_log_print(ANDROID_LOG_INFO, "nanoshell-detached",
                "dlopen OK for %s, searching entry point", binary_path);

            typedef int (*main_fn)(int, char**, char**);
            main_fn entry = (main_fn)dlsym(handle, "main");
            if (!entry) entry = (main_fn)dlsym(handle, "_main");
            if (entry) {
                __android_log_print(ANDROID_LOG_INFO, "nanoshell-detached",
                    "found main symbol, calling directly");
                int rc = entry(argc, (char**)safe_argv, environ);
                fprintf(stderr, "nanoshell-detached: entry returned rc=%d\n", rc);
                dlclose(handle);
                _exit(rc);
            }

#if defined(__aarch64__)
            // Binarios C++ (openbox, tint2) no exportan "main": su entry
            // real es el e_entry del ELF. Primero dlinfo para obtener la
            // base address directamente del link_map; si falla, _elf_entry_of
            // como fallback (usa dl_iterate_phdr que a veces no matchea).
            void* elf_entry = NULL;

            // Method 1: dlinfo → link_map → base + e_entry
            struct link_map* lm = NULL;
            dlinfo_fn_t dlinfo_fn = (dlinfo_fn_t)dlsym(RTLD_DEFAULT, "dlinfo");
            if (dlinfo_fn && dlinfo_fn(handle, RTLD_DI_LINKMAP, &lm) == 0
                && lm && lm->l_addr) {
                __android_log_print(ANDROID_LOG_DEBUG, "nanoshell-detached",
                    "dlinfo base=0x%lx for %s", (unsigned long)lm->l_addr, binary_path);
                FILE* ef = fopen(binary_path, "rb");
                if (ef) {
                    unsigned char ehdr[64];
                    size_t egot = fread(ehdr, 1, sizeof(ehdr), ef);
                    fclose(ef);
                    if (egot >= 0x20 && ehdr[0] == 0x7f && ehdr[1] == 'E'
                        && ehdr[2] == 'L' && ehdr[3] == 'F') {
                        uintptr_t e_entry = 0;
                        if (ehdr[4] == 2) memcpy(&e_entry, ehdr + 0x18, 8);
                        else { uint32_t e32; memcpy(&e32, ehdr + 0x18, 4); e_entry = e32; }
                        if (e_entry) {
                            elf_entry = (void*)(lm->l_addr + e_entry);
                            __android_log_print(ANDROID_LOG_INFO, "nanoshell-detached",
                                "elf entry via dlinfo: %p (base=0x%lx + e_entry=0x%lx)",
                                elf_entry, (unsigned long)lm->l_addr, (unsigned long)e_entry);
                        }
                    }
                }
            }

            // Method 2: fallback to _elf_entry_of (dl_iterate_phdr)
            if (!elf_entry) {
                __android_log_print(ANDROID_LOG_DEBUG, "nanoshell-detached",
                    "dlinfo failed, trying _elf_entry_of for %s", binary_path);
                elf_entry = _elf_entry_of(binary_path);
            }

            if (elf_entry) {
                __android_log_print(ANDROID_LOG_INFO, "nanoshell-detached",
                    "calling ELF entry %p for %s", elf_entry, binary_path);
                int rc = _call_stack_entry(elf_entry, argc, (char**)safe_argv);
                fprintf(stderr, "nanoshell-detached: entry returned rc=%d\n", rc);
                _exit(rc);
            }
#endif

            fprintf(stderr, "nanoshell-detached: no entry symbol in %s\n",
                    binary_path ? binary_path : "<null>");
            __android_log_print(ANDROID_LOG_ERROR, "nanoshell-detached",
                "no entry symbol found for %s", binary_path);
            dlclose(handle);
        }

        fprintf(stderr, "nanoshell-detached: giving up with rc=127\n");
        __android_log_print(ANDROID_LOG_ERROR, "nanoshell-detached",
            "giving up on %s with rc=127 (all methods failed)",
            binary_path ? binary_path : "<null>");
        _exit(127);
    }

    return (int)pid;
}


