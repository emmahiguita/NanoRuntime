/*
 * pty.h — Emulación de terminal interactiva (PTY) para NanoAI.
 *
 * Da a los binarios del rootfs un pseudo-terminal real: isatty() == true,
 * raw mode, control de jobs, señales (^C/^Z), y window resizing.
 * Esto permite vim, htop, python REPL, nano, less, etc.
 *
 * Estrategia: openpty() (implementado con posix_openpt + grantpt + unlockpt)
 * + fork() + en el hijo: setsid(), TIOCSCTTY, dup2 slave→stdin/out/err,
 * luego dlopen() del binario (mismo bypass SELinux que nanoshell.c).
 *
 * El fd master queda en el padre y es leído/escrito vía read/write/resize.
 * Todo compilado dentro de libnanoshell.so.
 */

#pragma once
#ifndef PTY_H
#define PTY_H

#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int   master_fd;   // fd del master PTY (en el padre)
    pid_t child_pid;   // pid del proceso hijo (para señales)
    char  slave_name[256];
} PtySession;

/*
 * Crea una sesión PTY y hace fork + dlopen del binario en el hijo.
 *
 * @param session      out: master_fd + child_pid
 * @param argv         argv del binario (terminado en NULL)
 * @param envp         entorno (terminado en NULL), puede ser NULL
 * @param ld_preload   tele "<libnanoroot.so>" para fakechroot, o NULL
 * @param width        columnas iniciales (para TIOCSWINSZ)
 * @param height       filas iniciales
 * @return 0 en éxito, -1 en error (ver nanoshell_last_error)
 */
int  pty_spawn(PtySession* session,
               const char* const argv[],
               const char* const envp[],
               const char* ld_preload,
               unsigned short width,
               unsigned short height);

/*
 * Lectura no bloqueante del master PTY.
 * @return n>0 bytes leídos, 0 si no hay datos (EAGAIN), -1 error.
 */
int pty_read(int master_fd, char* buf, size_t bufsize);

// Escritura al master PTY (envía input al terminal del hijo).
int pty_write(int master_fd, const char* data, size_t len);

// Cambia el tamaño de ventana del PTY (ioctl TIOCSWINSZ).
int pty_resize(int master_fd, unsigned short rows, unsigned short cols);

// Cierra el master fd.
void pty_close(int master_fd);

// Envía una señal al proceso hijo (SIGINT, SIGTERM, SIGKILL...).
int pty_kill(pid_t pid, int signal);

// True si el proceso hijo sigue vivo; reaps el zombie del proyecto.
int pty_is_alive(pid_t pid, int* out_rc);

#ifdef __cplusplus
}
#endif

#endif // PTY_H