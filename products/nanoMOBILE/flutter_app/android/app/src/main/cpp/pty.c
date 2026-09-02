/*
 * pty.c — Implementación de sesiones PTY (terminal interactiva).
 *
 * Compilado dentro de libnanoshell.so. Ver pty.h para la API.
 *
 * NOTA bionic/Android: openpty()/forkpty() NO están en libc bionic.
 * Implementamos openpty con primitivas POSIX disponibles:
 *   posix_openpt(O_RDWR|O_NOCTTY) → grantpt → unlockpt → ptsname → open(slave)
 * login_tty se emula con setsid() + ioctl(TIOCSCTTY) + dup2.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <limits.h>
#include <signal.h>
#include <dlfcn.h>
#include <sys/ioctl.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <termios.h>

#include "pty.h"
#include "util.h"  // count_argv, apply_env (shared with nanoshell.c)

// Reusar el buffer de error global de nanoshell.c? No — mantenerlo local.
static char g_pty_error[512] = {0};

const char* pty_last_error(void) { return g_pty_error; }

// ── openpty (implementación manual para bionic) ──
static int _openpty(int* master, int* slave, char* slave_name_out, size_t name_sz,
                    struct winsize* ws) {
    int m = posix_openpt(O_RDWR | O_NOCTTY);
    if (m < 0) { snprintf(g_pty_error, sizeof(g_pty_error), "posix_openpt: %s", strerror(errno)); return -1; }

    // grantpt no afecta fds en Android moderno pero lo llamamos por si acaso.
    if (grantpt(m) != 0) {
        snprintf(g_pty_error, sizeof(g_pty_error), "grantpt: %s", strerror(errno));
        close(m); return -1;
    }
    if (unlockpt(m) != 0) {
        snprintf(g_pty_error, sizeof(g_pty_error), "unlockpt: %s", strerror(errno));
        close(m); return -1;
    }

    char* sname = ptsname(m);
    if (!sname) {
        snprintf(g_pty_error, sizeof(g_pty_error), "ptsname: %s", strerror(errno));
        close(m); return -1;
    }

    int s = open(sname, O_RDWR | O_NOCTTY);
    if (s < 0) {
        snprintf(g_pty_error, sizeof(g_pty_error), "open(slave %s): %s", sname, strerror(errno));
        close(m); return -1;
    }

    if (ws) ioctl(s, TIOCSWINSZ, ws);
    if (slave_name_out && name_sz > 0) {
        strncpy(slave_name_out, sname, name_sz - 1);
        slave_name_out[name_sz - 1] = '\0';
    }

    *master = m;
    *slave = s;
    return 0;
}

// Convierte slave fd en terminal controlador del proceso actual.
static void _login_tty(int fd) {
    setsid();                    // nueva sesión, sin terminal controlador
    ioctl(fd, TIOCSCTTY, 0);     // este fd pasa a ser el terminal controlador
    dup2(fd, STDIN_FILENO);
    dup2(fd, STDOUT_FILENO);
    dup2(fd, STDERR_FILENO);
    if (fd > STDERR_FILENO) close(fd);
}

// apply_env() and count_argv() are now in util.h/util.c (shared with nanoshell.c).

// Ejecuta el binario por dlopen + main() en el proceso actual (sin execve).
// No retorna: hace _exit(rc). Vía necesaria en este device: SELinux deniega
// el execve de binarios app_data (Permission denied) pero el dlopen (mmap
// exec) sí está permitido. El cap RLIMIT_AS va DESPUÉS de cargar: el linker
// necesita mmap libre durante el dlopen (zonas CFI shadow de binarios PIE);
// con el cap antes, el mmap falla y el linker aborta con CHECK
// 'page != MAP_FAILED' (linker_block_allocator).
static void _run_via_dlopen(const char* bin, const char* const argv[]) {
    void* handle = dlopen(bin, RTLD_NOW | RTLD_GLOBAL);
    if (!handle) {
        fprintf(stderr, "pty: dlopen(%s) failed: %s\n", bin, dlerror());
        _exit(127);
    }

    typedef int (*main_fn)(int, char**);
    main_fn entry = (main_fn)dlsym(handle, "main");
    if (!entry) entry = (main_fn)dlsym(handle, "_main");
    if (!entry) {
        fprintf(stderr, "pty: dlsym(main) in %s failed: %s\n", bin, dlerror());
        dlclose(handle);
        _exit(127);
    }

    int argc = count_argv(argv);
    char** mutable_argv = malloc(sizeof(char*) * (argc + 1));
    if (!mutable_argv) _exit(126);
    for (int i = 0; i < argc; i++) mutable_argv[i] = strdup(argv[i]);
    mutable_argv[argc] = NULL;

    // Cap después de cargar: limita el crecimiento del binario, no el
    // arranque del linker. Floor dinámico en util.c (VA actual + margen)
    // para no bloquear mmaps legítimos del binario.
    apply_rlimit_as();

    // El main de un binario ET_DYN espera (int, char**) o (int, char**, char**).
    // 2-arg es lo estándar para binarios dlopen'eados; los que necesitan envp
    // usan environ global (llegado con apply_env).
    int rc = entry(argc, mutable_argv);

    for (int i = 0; i < argc; i++) free(mutable_argv[i]);
    free(mutable_argv);
    dlclose(handle);
    _exit(rc);   // cierra fds, termina sesión → padre ve EOF
}

// Resuelve el directorio donde vive ESTA lib (libnanoshell.so) leyendo
// /proc/self/maps. libnanoroot.so está en el mismo nativeLibraryDir del APK,
// y el dlopen RELATIVO ("libnanoroot.so") da not found en el hijo: el
// namespace heredado no resuelve el SONAME. La ruta absoluta sale del maps.
// out termina con '/'. Vacío si no se pudo resolver.
static void _find_own_libdir(char* out, size_t out_sz) {
    out[0] = '\0';
    FILE* f = fopen("/proc/self/maps", "re");
    if (!f) return;
    char line[1024];
    while (fgets(line, sizeof(line), f)) {
        const char* hit = strstr(line, "/libnanoshell.so");
        if (!hit) continue;
        // El path del mapping empieza tras el último espacio antes de hit.
        // hit apunta a la '/' de "/libnanoshell.so": incluirla (+1) para que
        // out termine con '/'. Sin ella, concatenar el SONAME daba
        // ".../lib/arm64libnanoroot.so" (ver device: "pty: preload ... no
        // existe") y el preload nunca cargó desde TER-06.
        const char* start = hit;
        while (start > line && start[-1] != ' ') start--;
        size_t len = (size_t)(hit - start) + 1;
        if (len > 0 && len < out_sz) {
            memcpy(out, start, len);
            out[len] = '\0';
            break;
        }
    }
    fclose(f);
}

int pty_spawn(PtySession* session,
              const char* const argv[],
              const char* const envp[],
              const char* ld_preload,
              unsigned short width,
              unsigned short height) {
    if (!session) { snprintf(g_pty_error, sizeof(g_pty_error), "null session"); return -1; }
    session->master_fd = -1;
    session->child_pid = -1;

    struct winsize ws;
    ws.ws_row = height > 0 ? height : 24;
    ws.ws_col = width  > 0 ? width  : 80;
    ws.ws_xpixel = 0;
    ws.ws_ypixel = 0;

    int master = -1, slave = -1;
    if (_openpty(&master, &slave, session->slave_name,
                 sizeof(session->slave_name), &ws) != 0) return -1;

    pid_t pid = fork();
    if (pid < 0) {
        snprintf(g_pty_error, sizeof(g_pty_error), "fork: %s", strerror(errno));
        close(master); close(slave);
        return -1;
    }

    if (pid == 0) {
        // === CHILD ===
        close(master);                       // el hijo cierra el master
        _login_tty(slave);                   // slave es ahora stdin/out/err

        // Cerrar fds heredados que no nos interesan
        for (int fd = 3; fd < 256; fd++) close(fd);

        // Entorno antes de dlopen para que el constructor de libnanoroot
        // lea NANO_ROOTFS.
        apply_env(envp);

        const char* bin = argv && argv[0] ? argv[0] : NULL;
        if (!bin) { _exit(127); }

        // TER-08: el environ del proceso app puede traer LD_PRELOAD
        // relativo (init TER-03: "libnanoroot.so"). El linker del binario
        // app_data no lo resuelve en su namespace → FATAL "library
        // libnanoroot.so not found: needed by main executable"
        // (logcat -b crash, 12:32 device). Absolutizar contra el
        // nativeLibraryDir (mismo dir de libnanoshell.so); si la lib no
        // existe, quitarlo — bash sin fakechroot es mejor que bash muerto.
        // LD_LIBRARY_PATH al mismo dir: resuelve NEEDED del rootfs que
        // están en jniLibs (libiconv.so, libandroid-support.so).
        {
            char libdir[512] = {0};
            _find_own_libdir(libdir, sizeof(libdir));
            if (libdir[0]) {
                const char* cur = getenv("LD_PRELOAD");
                if (cur && cur[0] && cur[0] != '/') {
                    char abs_pl[512] = {0};
                    snprintf(abs_pl, sizeof(abs_pl), "%s%s", libdir, cur);
                    if (access(abs_pl, R_OK) == 0) {
                        setenv("LD_PRELOAD", abs_pl, 1);
                    } else {
                        unsetenv("LD_PRELOAD");
                    }
                }
                const char* cur_lp = getenv("LD_LIBRARY_PATH");
                if (!cur_lp || !cur_lp[0]) {
                    setenv("LD_LIBRARY_PATH", libdir, 1);
                } else {
                    char combined[1024] = {0};
                    snprintf(combined, sizeof(combined), "%s:%s", libdir, cur_lp);
                    setenv("LD_LIBRARY_PATH", combined, 1);
                }
            }
        }

        // TER-09: el bash arranca con el cwd heredado del proceso app ("/"),
        // denegado por SELinux para listar ("ls: cannot open directory '.':
        // Permission denied"). chdir(HOME) — mismo patrón validado en el
        // worker TER-07. libnanoroot virtualiza el cwd al arrancar (getcwd
        // real bajo el rootfs → "/home").
        {
            const char* home = getenv("HOME");
            if (home && home[0]) chdir(home);
        }

        // ── Vía con fakechroot: execve(linker64) con preload ABSOLUTO ──
        // Evidencia de este device:
        //  • SELinux deniega TODO execve de binarios app_data (EACCES) —
        //    solo execve("/system/bin/linker64") pasa el kernel.
        //  • El dlopen en-proceso de binarios PIE aborta el linker
        //    (linker_block_allocator CHECK 'page != MAP_FAILED': el VA del
        //    proceso app, 15GB con Flutter+ART, colisiona con las zonas del
        //    allocator) — la vía dlopen de TER-05 no es viable aquí.
        //  • dlopen relativo ("libnanoroot.so") da not found en el hijo.
        // Queda: linker64 como primaria, con LD_PRELOAD en RUTA ABSOLUTA
        // (resuelta desde /proc/self/maps — mismo dir que libnanoshell.so).
        // Si el linker del proceso nuevo ignora el preload, emitirá su
        // warning en logcat; el fallback dlopen (abajo) queda como último
        // recurso con la ruta absoluta.
        if (ld_preload && ld_preload[0]) {
            char abs_preload[512] = {0};
            char libdir[512] = {0};
            _find_own_libdir(libdir, sizeof(libdir));
            if (libdir[0]) {
                snprintf(abs_preload, sizeof(abs_preload), "%slibnanoroot.so", libdir);
                if (access(abs_preload, R_OK) == 0) {
                    setenv("LD_PRELOAD", abs_preload, 1);
                } else {
                    fprintf(stderr, "pty: preload %s no existe\n", abs_preload);
                }
            }
            {
                int argc = count_argv(argv);
                char** linker_argv = malloc(sizeof(char*) * (argc + 2));
                if (linker_argv) {
                    linker_argv[0] = "/system/bin/linker64";
                    linker_argv[1] = (char*)bin;
                    for (int i = 1; i < argc; i++) linker_argv[i + 1] = (char*)argv[i];
                    linker_argv[argc + 1] = NULL;
                    extern char** environ;
                    execve("/system/bin/linker64", linker_argv, environ);
                    fprintf(stderr, "pty: execve(linker64,%s) falló: %s — usando dlopen\n",
                            bin, strerror(errno));
                    free(linker_argv);
                }
            }

            // ── Fallback: dlopen en-proceso con la ruta absoluta ──
            const char* preload_path = abs_preload[0] ? abs_preload : ld_preload;
            void* ph = dlopen(preload_path, RTLD_NOW | RTLD_GLOBAL);
            if (!ph) {
                fprintf(stderr, "pty: dlopen(%s) warning: %s\n", preload_path, dlerror());
            } else {
                setenv("LD_PRELOAD", preload_path, 1);
            }
            _run_via_dlopen(bin, argv);   // no retorna
        }

        // ── Vía sin preload: execve directo (igual que nanoshell.c) ──
        // El kernel invoca el PT_INTERP del binario. SIN cap RLIMIT_AS
        // antes: el límite se heredaría al proceso nuevo y su linker
        // abortaría reservando zonas (MapShadow/CFI shadow en Android 14+).
        {
            extern char** environ;
            execve(bin, (char* const*)argv, environ);
            fprintf(stderr, "pty: execve(%s) falló: %s — usando linker64\n",
                    bin, strerror(errno));
        }

        // ── Segundo intento: execve via linker64 ──
        // Solo si el execve directo falla (binario sin PT_INTERP válido).
        // Sin RLIMIT_AS por la misma razón: el linker del proceso nuevo
        // necesita VA libre para sus zonas.
        {
            int argc = count_argv(argv);
            char** linker_argv = malloc(sizeof(char*) * (argc + 2));
            if (linker_argv) {
                linker_argv[0] = "/system/bin/linker64";
                linker_argv[1] = (char*)bin;
                for (int i = 1; i < argc; i++) linker_argv[i + 1] = (char*)argv[i];
                linker_argv[argc + 1] = NULL;
                extern char** environ;
                execve("/system/bin/linker64", linker_argv, environ);
                fprintf(stderr, "pty: execve(linker64,%s) falló: %s — usando dlopen\n",
                        bin, strerror(errno));
                free(linker_argv);
            }
        }

        // ── Fallback: dlopen + main ──
        _run_via_dlopen(bin, argv);   // no retorna
    }

    // === PARENT ===
    close(slave);
    session->master_fd = master;
    session->child_pid = pid;

    // Master no bloqueante para pty_read() sin colgar.
    int flags = fcntl(master, F_GETFL, 0);
    fcntl(master, F_SETFL, flags | O_NONBLOCK);

    return 0;
}

int pty_read(int master_fd, char* buf, size_t bufsize) {
    if (bufsize == 0) return 0;
    ssize_t n = read(master_fd, buf, bufsize > 0 ? bufsize : 4096);
    if (n < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) return 0;
        return -1;
    }
    // Convertir el \r\n de pty a \n para render limpio en la UI.
    // (No lo convertimos aquí: el terminal raw en Flutter se encarga.
    //  Dejamos crudo para que el renderer del terminal lo maneje.)
    return (int)n;
}

int pty_write(int fd, const char* data, size_t len) {
    if (len == 0) return 0;
    ssize_t n = write(fd, data, len);
    if (n < 0) return (errno == EAGAIN || errno == EWOULDBLOCK) ? 0 : -1;
    return (int)n;
}

int pty_resize(int fd, unsigned short rows, unsigned short cols) {
    struct winsize ws;
    if (ioctl(fd, TIOCGWINSZ, &ws) == 0) {
        ws.ws_row = rows > 0 ? rows : ws.ws_row;
        ws.ws_col = cols > 0 ? cols : ws.ws_col;
        return ioctl(fd, TIOCSWINSZ, &ws);
    }
    ws.ws_row = rows > 0 ? rows : 24;
    ws.ws_col = cols > 0 ? cols : 80;
    ws.ws_xpixel = 0; ws.ws_ypixel = 0;
    return ioctl(fd, TIOCSWINSZ, &ws);
}

void pty_close(int fd) {
    if (fd >= 0) close(fd);
}

int pty_kill(pid_t pid, int signal) {
    if (pid <= 0) { errno = ESRCH; return -1; }
    // Signal the entire process group so children (vim, sleep, pipelines)
    // also receive the signal, not just the shell.
    return kill(-pid, signal);
}

/*
 * Comprueba si el proceso hijo sigue vivo (reap no-bloqueante).
 * @return 1 si está vivo, 0 si ha terminado (retirado), -1 error.
 * Al detectar terminación hace waitpid() con WNOHANG y WEXITSTATUS → *out_rc.
 */
int pty_is_alive(pid_t pid, int* out_rc) {
    if (pid <= 0) { if (out_rc) *out_rc = -1; return 0; }
    int st;
    pid_t r = waitpid(pid, &st, WNOHANG);
    if (r == 0) return 1;          // sigue corriendo
    if (r == pid) {                // terminó y fue reaped (o zombie listo)
        if (out_rc) {
            if (WIFEXITED(st)) *out_rc = WEXITSTATUS(st);
            else if (WIFSIGNALED(st)) *out_rc = 128 + WTERMSIG(st);
            else *out_rc = 1;
        }
        return 0;
    }
    // r < 0
    if (errno == ECHILD) {         // ya fue reaped por alguien
        if (out_rc) *out_rc = -1;
        return 0;
    }
    return -1;                     // error real (ESRCH etc.)
}
