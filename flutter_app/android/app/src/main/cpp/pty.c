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
#include <sys/wait.h>
#include <termios.h>

#include "pty.h"

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

// Aplica envp al entorno actual (para el hijo antes de dlopen).
static void _apply_env(const char* const envp[]) {
    if (!envp) return;
    for (int i = 0; envp[i]; i++) {
        char* kv = strdup(envp[i]);
        if (!kv) continue;
        char* eq = strchr(kv, '=');
        if (eq) { *eq = '\0'; setenv(kv, eq + 1, 1); }
        free(kv);
    }
}

static int _count_argv(const char* const argv[]) {
    int n = 0; while (argv && argv[n]) n++; return n;
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
        _apply_env(envp);

        const char* bin = argv && argv[0] ? argv[0] : NULL;
        if (!bin) { _exit(127); }

        // ── Vía primaria: execve via linker64 ──
        // Construye proceso completo con aux vector, TLS y namespaces.
        // LD_PRELOAD se hereda vía environ (aplicado con _apply_env arriba).
        {
            int argc = _count_argv(argv);
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
        // Preload fakechroot (igual que nanoshell.c)
        if (ld_preload && ld_preload[0]) {
            void* ph = dlopen(ld_preload, RTLD_NOW | RTLD_GLOBAL);
            if (!ph) {
                fprintf(stderr, "pty: dlopen(%s) warning: %s\n", ld_preload, dlerror());
            } else {
                setenv("LD_PRELOAD", ld_preload, 1);
            }
        }

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

        int argc = _count_argv(argv);
        char** mutable_argv = malloc(sizeof(char*) * (argc + 1));
        if (!mutable_argv) _exit(126);
        for (int i = 0; i < argc; i++) mutable_argv[i] = strdup(argv[i]);
        mutable_argv[argc] = NULL;

        // pty: el main de un binario ET_DYN espera (int, char**) o (int, char**, char**).
        // Intentamos la variante de 3 args primero via trampa? No — usar 2-arg
        // es lo estándar para binarios dlopen'eados. Los que necesitan envp
        // usan environ global (llegado con _apply_env).
        int rc = entry(argc, mutable_argv);

        for (int i = 0; i < argc; i++) free(mutable_argv[i]);
        free(mutable_argv);
        dlclose(handle);
        _exit(rc);   // cierra fds, termina sesión → padre ve EOF
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
    return kill(pid, signal);
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