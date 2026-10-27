#include "pty_session_registry.h"

#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>

// Tabla estática de sesiones PTY. La UI limita nuevas pestañas a 16.
// Cada slot reserva descriptor/PID hasta completar su recolección propietaria.
#define MAX_PTY_SESSIONS 16

static PtySessionRecord g_sessions[MAX_PTY_SESSIONS];
static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;
static long g_next_id = 1;

static PtySessionRecord* find_session_locked(jlong id) {
    for (int i = 0; i < MAX_PTY_SESSIONS; i++) {
        if (g_sessions[i].in_use == 1 && g_sessions[i].id == id) {
            return &g_sessions[i];
        }
    }
    return NULL;
}

// Estados: 0 libre, 1 activa, 2 cierre en curso, 3 espera de recolección.
// Solo recogemos hijos PTY propios; waitpid(-1) robaría salidas a nanoshell.
static void _reap_delayed_zombies(void) {
    pthread_mutex_lock(&g_lock);
    for (int i = 0; i < MAX_PTY_SESSIONS; i++) {
        PtySessionRecord* rec = &g_sessions[i];
        if (rec->in_use != 3) continue;
        int status = 0;
        pid_t r = waitpid(rec->pty.child_pid, &status, WNOHANG);
        if (r == rec->pty.child_pid || (r < 0 && errno == ECHILD)) {
            rec->pty.child_pid = -1;
            rec->in_use = 0;
        }
    }
    pthread_mutex_unlock(&g_lock);
}

PtySessionRecord* pty_registry_alloc(void) {
    _reap_delayed_zombies();
    pthread_mutex_lock(&g_lock);
    for (int i = 0; i < MAX_PTY_SESSIONS; i++) {
        if (!g_sessions[i].in_use) {
            PtySessionRecord* rec = &g_sessions[i];
            rec->in_use = 1;
            rec->pty.master_fd = -1;
            rec->pty.child_pid = -1;
            rec->id = (jlong)(g_next_id++);
            pthread_mutex_unlock(&g_lock);
            return rec;
        }
    }
    pthread_mutex_unlock(&g_lock);
    return NULL;
}

void pty_registry_free(PtySessionRecord* rec) {
    if (!rec) return;
    pthread_mutex_lock(&g_lock);
    rec->in_use = 0;
    pthread_mutex_unlock(&g_lock);
}

int pty_registry_dup_fd(jlong id) {
    int fd = -1;
    pthread_mutex_lock(&g_lock);
    PtySessionRecord* rec = find_session_locked(id);
    if (rec && rec->pty.master_fd >= 0) fd = dup(rec->pty.master_fd);
    pthread_mutex_unlock(&g_lock);
    return fd;
}

pid_t pty_registry_pid(jlong id) {
    pid_t pid = -1;
    pthread_mutex_lock(&g_lock);
    PtySessionRecord* rec = find_session_locked(id);
    if (rec) pid = rec->pty.child_pid;
    pthread_mutex_unlock(&g_lock);
    return pid;
}

// Espera acotada por PID: EINTR no significa que el hijo haya terminado.
static int reap_owned_child(pid_t child, int rounds) {
    for (int i = 0; i < rounds; i++) {
        int status = 0;
        pid_t r = waitpid(child, &status, WNOHANG);
        if (r == child || (r < 0 && errno == ECHILD)) return 1;
        usleep(5000);
    }
    return 0;
}

// Desconecta el descriptor y reserva el slot hasta recoger SU proceso hijo.
// La espera ocurre en el trabajador Kotlin, nunca en el hilo de presentación.
int pty_registry_close(jlong id) {
    pthread_mutex_lock(&g_lock);
    PtySessionRecord* rec = find_session_locked(id);
    if (!rec) {
        pthread_mutex_unlock(&g_lock);
        return -1;
    }
    int fd = rec->pty.master_fd;
    pid_t child = rec->pty.child_pid;
    rec->pty.master_fd = -1;
    rec->in_use = 2; // Impide doble cierre y reutilización concurrente.
    pthread_mutex_unlock(&g_lock);

    int reaped = child <= 0;
    if (!reaped) {
        kill(-child, SIGHUP);
        reaped = reap_owned_child(child, 60);
        if (!reaped) {
            kill(-child, SIGKILL);
            reaped = reap_owned_child(child, 40);
        }
    }
    pthread_mutex_lock(&g_lock);
    // Un proceso lento conserva su PID para el próximo barrido propietario.
    rec->in_use = reaped ? 0 : 3;
    if (reaped) rec->pty.child_pid = -1;
    pthread_mutex_unlock(&g_lock);
    if (fd >= 0) pty_close(fd);
    return fd >= 0 ? 0 : -1;
}
