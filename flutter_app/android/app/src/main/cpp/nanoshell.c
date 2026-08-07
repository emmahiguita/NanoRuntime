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
#include <dlfcn.h>
#include <dirent.h>
#include <unistd.h>
#include <sys/wait.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <limits.h>

// ── Forward declarations ──

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

// ── Internal state ──

static char g_last_error[512] = {0};

// ── Core: fork + dlopen + main ──

static char* _slurp_fd(int fd, size_t* out_len) {
    size_t cap = 4096;
    char* buf = malloc(cap);
    if (!buf) return NULL;
    size_t total = 0;
    ssize_t n;
    while ((n = read(fd, buf + total, cap - total)) > 0) {
        total += n;
        if (total >= cap - 1) {
            cap *= 2;
            char* newbuf = realloc(buf, cap);
            if (!newbuf) { free(buf); return NULL; }
            buf = newbuf;
        }
    }
    // NO recortar trailing newline — corrompe datos binarios (tar, xz, etc.)
    buf[total] = '\0';
    *out_len = total;
    return buf;
}

static int _count_argv(const char* const argv[]) {
    int n = 0;
    while (argv[n]) n++;
    return n;
}

// Apply envp to process environment. Only modifies current process.
static void _apply_env(const char* const envp[]) {
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
    if (strstr(info->dlpi_name, base_name)) {
        *c->base = (uintptr_t)info->dlpi_addr;
        return 1;
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

// ── Trampolín de arranque ARM64 (nivel global) ──
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

        // Apply environment variables BEFORE dlopen so that
        // libnanoroot's constructor can read NANO_ROOTFS from env.
        _apply_env(envp);

        // ── Vía primaria: execve via linker64 ──
        // Termux en producción usa execve("/system/bin/linker64", [binary, ...])
        // porque el linker está en /system (SELinux lo permite) y construye
        // un proceso completo con aux vector, TLS, y namespaces correctos.
        // LD_PRELOAD funciona nativamente con execve (no requiere dlopen manual).
        // Solo aplica en modo genérico (lib_path != NULL; busybox no necesita esto).
        if (lib_path && lib_path[0]) {
            // Construir argv para linker64: ["linker64", binary, arg1, arg2, ...]
            int argc = _count_argv(argv);
            char** linker_argv = malloc(sizeof(char*) * (argc + 2));
            if (linker_argv) {
                linker_argv[0] = "/system/bin/linker64";
                linker_argv[1] = (char*)lib_path;
                for (int i = 1; i < argc; i++) linker_argv[i + 1] = (char*)argv[i];
                linker_argv[argc + 1] = NULL;
                extern char** environ;
                execve("/system/bin/linker64", linker_argv, environ);
                // Si execve falla (EACCES en OPPO/ColorOS, linker64 no existe,
                // etc.), caemos al fallback dlopen. linker_argv se pierde con
                // el fork — no hay leak.
                fprintf(stderr, "nanoshell: execve(linker64,%s) falló: %s — usando dlopen\n",
                        lib_path, strerror(errno));
                free(linker_argv);
            }
        }

        // ── Fallback: dlopen + main / trampolín ──
        // Preload fakechroot library BEFORE the target binary.
        if (ld_preload && ld_preload[0]) {
            void* preload_handle = dlopen(ld_preload, RTLD_NOW | RTLD_GLOBAL);
            if (!preload_handle) {
                fprintf(stderr, "nanoshell: dlopen(%s) warning: %s\n",
                        ld_preload, dlerror());
            }
            setenv("LD_PRELOAD", ld_preload, 1);
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

        // Build mutable argv
        int argc = _count_argv(argv);
        char** mutable_argv = malloc(sizeof(char*) * (argc + 1));
        for (int i = 0; i < argc; i++) {
            mutable_argv[i] = strdup(argv[i]);
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

    // Read pipes BEFORE waitpid to avoid deadlock.
    // If child produces > pipe buffer (64KB), it blocks on write.
    // Parent must drain pipes concurrently with child execution.
    size_t out_len = 0, err_len = 0;
    char* stdout_str = _slurp_fd(out_pipe[0], &out_len);
    char* stderr_str = _slurp_fd(err_pipe[0], &err_len);
    close(out_pipe[0]);
    close(err_pipe[0]);

    // Now wait for child to finish (pipes are already drained)
    int status;
    waitpid(pid, &status, 0);

    *out_stdout = stdout_str ? stdout_str : strdup("");
    *out_stderr = stderr_str ? stderr_str : strdup("");
    if (out_stdout_len) *out_stdout_len = out_len;
    if (out_stderr_len) *out_stderr_len = err_len;

    if (WIFEXITED(status)) return WEXITSTATUS(status);
    if (WIFSIGNALED(status)) return 128 + WTERMSIG(status);
    return -1;
}

// ── Public API ──

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

// ── Worker-process spawn (sin GPU) ──
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
    if (task_id && task_id[0] && files_dir && files_dir[0]) {
        snprintf(out_path, sizeof(out_path), "%s/worker_out_%s", files_dir, task_id);
        snprintf(err_path, sizeof(err_path), "%s/worker_err_%s", files_dir, task_id);
        snprintf(rc_path, sizeof(rc_path), "%s/worker_rc_%s", files_dir, task_id);

        FILE* fo = fopen(out_path, "wb");
        if (fo) { if (out_s) fwrite(out_s, 1, out_len, fo); fclose(fo); }
        FILE* fe = fopen(err_path, "wb");
        if (fe) { if (err_s) fwrite(err_s, 1, err_len, fe); fclose(fe); }
        FILE* fr = fopen(rc_path, "wb");
        if (fr) { fprintf(fr, "%d", rc); fclose(fr); }
    }

    free(out_s);
    free(err_s);
    return rc;
}

// ── Daemon spawn (sin esperar) ──
// Para procesos long-running (Xvnc, openbox, etc.). fork+exec sin waitpid.
// Redirige stdout/stderr a /dev/null. Retorna PID (>0) o -1 si falla.
int nanoshell_worker_spawn_detached(
    const char* binary_path,
    const char* const argv[],
    const char* const envp[])
{
    // Aplicar environment en el padre (se hereda en el fork)
    if (envp) {
        for (int i = 0; envp[i]; i++) {
            char* eq = strchr(envp[i], '=');
            if (eq) {
                *eq = '\0';
                setenv(envp[i], eq + 1, 1);
                *eq = '=';
            }
        }
    }

    pid_t pid = fork();
    if (pid < 0) return -1;

    if (pid == 0) {
        // ── HIJO ──
        // Cerrar FDs heredados excepto 0/1/2
        for (int fd = 3; fd < 256; fd++) close(fd);

        // Redirigir stdout/stderr a archivo para diagnóstico
        int logfd = open("/data/data/dev.nanoai.mobile/files/nano/tmp/vnc_daemon.log",
                         O_WRONLY | O_CREAT | O_APPEND, 0600);
        if (logfd >= 0) {
            dup2(logfd, STDOUT_FILENO);
            dup2(logfd, STDERR_FILENO);
            if (logfd > 2) close(logfd);
        } else {
            int devnull = open("/dev/null", O_WRONLY);
            if (devnull >= 0) { dup2(devnull, STDOUT_FILENO); dup2(devnull, STDERR_FILENO); if (devnull > 2) close(devnull); }
        }

        // setsid: desacoplar del terminal y grupo de procesos
        setsid();

        // ── Vía primaria: execve via linker64 ──
        int argc = _count_argv(argv);
        char** linker_argv = malloc(sizeof(char*) * (argc + 2));
        if (linker_argv) {
            linker_argv[0] = "/system/bin/linker64";
            linker_argv[1] = (char*)binary_path;
            for (int i = 1; i < argc; i++) linker_argv[i + 1] = (char*)argv[i];
            linker_argv[argc + 1] = NULL;
            extern char** environ;
            execve("/system/bin/linker64", linker_argv, environ);
            free(linker_argv);
        }

        // ── Fallback: execve directo ──
        execve(binary_path, (char* const*)argv, environ);

        // ── Fallback final: dlopen con preload de libnanoroot ──
        fprintf(stderr, "DAEMON: linker64 y execve fallaron, usando dlopen\n");
        void* preload = dlopen("libnanoroot.so", RTLD_NOW | RTLD_GLOBAL);
        fprintf(stderr, "DAEMON: preload=%p err=%s\n", preload, dlerror());
        void* handle = dlopen(binary_path, RTLD_NOW | RTLD_GLOBAL);
        if (handle) {
            typedef int (*main_t)(int, char**, char**);
            main_t fn = (main_t)dlsym(handle, "main");
            fprintf(stderr, "DAEMON: dlopen ok, main=%p\n", fn);
            if (fn) _exit(fn(argc, (char**)argv, environ));
        }
        fprintf(stderr, "DAEMON: dlopen(%s) falló: %s\n", binary_path, dlerror());

        _exit(127);
    }

    // ── PADRE ──
    return (int)pid;
}
