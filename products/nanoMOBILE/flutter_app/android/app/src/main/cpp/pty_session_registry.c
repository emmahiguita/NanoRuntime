#include "pty_session_registry.h"

#include <pthread.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>

// Máximo de sesiones PTY simultáneas. La UI no impone un límite superior,
// así que se reservan 16 slots (tabla estática, ~384 bytes en el stack).
// Auditoría BUG-02 (2026-09-09): ampliado de 8 → 16 para evitar que la
// 9ª pestaña falle silenciosamente cuando pty_registry_alloc() retorna NULL.
#define MAX_PTY_SESSIONS 16

static PtySessionRecord g_sessions[MAX_PTY_SESSIONS];
static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;
static long g_next_id = 1;

static PtySessionRecord* find_session_locked(jlong id) {
    for (int i = 0; i < MAX_PTY_SESSIONS; i++) {
        if (g_sessions[i].in_use && g_sessions[i].id == id) {
            return &g_sessions[i];
        }
    }
    return NULL;
}

/// Recolecta de forma no bloqueante cualquier proceso hijo PTY que haya
/// terminado con retraso tras el cierre de su sesión (prevención de procesos zombi).
/// QUÉ HACE: Invoca `waitpid` con `WNOHANG` sobre procesos pendientes antes de asignar slot.
/// CÓMO FUNCIONA: Si un hijo en estado D tardó >200ms en morir tras `SIGKILL` en `pty_registry_close`,
///   este barrido libera su entrada en la tabla de procesos del kernel sin bloquear hilos JNI.
/// POR QUÉ: Evita agotar PIDs o acumular procesos `<defunct>` en sesiones prolongadas.
static void _reap_delayed_zombies(void) {
    int st = 0;
    while (waitpid(-1, &st, WNOHANG) > 0) {
        // Reap completado sin bloqueo
    }
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

int pty_registry_close(jlong id) {
    int fd = -1;
    pid_t child = -1;
    pthread_mutex_lock(&g_lock);
    PtySessionRecord* rec = find_session_locked(id);
    if (rec) {
        fd = rec->pty.master_fd;
        child = rec->pty.child_pid;
        rec->pty.master_fd = -1;
        rec->pty.child_pid = -1;
        // NOTE: in_use stays 1 until the child is reaped below.
        // Clearing it here would allow a concurrent pty_open() to reuse
        // this slot while the old child process is still alive.
    }
    pthread_mutex_unlock(&g_lock);

    if (child > 0) {
        // Step 1: graceful SIGHUP to the entire process group.
        kill(-child, SIGHUP);
        // Wait up to ~300ms for voluntary exit.
        int status = 0;
        int graceful_rounds = 60; // 60 * 5ms = 300ms
        for (int i = 0; i < graceful_rounds; i++) {
            pid_t r = waitpid(child, &status, WNOHANG);
            if (r == child || r < 0) goto reaped;
            usleep(5000);
        }
        // Step 2: force SIGKILL if child is still alive.
        kill(-child, SIGKILL);
        // PROC-001 FIX: reap acotado con WNOHANG para evitar colgar el hilo JNI
        // ante procesos en D-state o reparentados. 40 rondas x 5ms = 200ms máx.
        for (int j = 0; j < 40; j++) {
            pid_t r2 = waitpid(child, &status, WNOHANG);
            if (r2 == child || r2 < 0) goto reaped;
            usleep(5000);
        }
    }
reaped:
    // Now that the child slot is fully released, mark it free.
    pthread_mutex_lock(&g_lock);
    {
        PtySessionRecord* rec2 = find_session_locked(id);
        if (rec2) rec2->in_use = 0;
    }
    pthread_mutex_unlock(&g_lock);

    if (fd >= 0) pty_close(fd);
    return fd >= 0 ? 0 : -1;
}
