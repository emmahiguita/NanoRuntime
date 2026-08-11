#include "pty_session_registry.h"

#include <pthread.h>
#include <unistd.h>

#define MAX_PTY_SESSIONS 8

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

PtySessionRecord* pty_registry_alloc(void) {
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
    pthread_mutex_lock(&g_lock);
    PtySessionRecord* rec = find_session_locked(id);
    if (rec) {
        fd = rec->pty.master_fd;
        rec->pty.master_fd = -1;
        rec->pty.child_pid = -1;
        rec->in_use = 0;
    }
    pthread_mutex_unlock(&g_lock);
    if (fd >= 0) pty_close(fd);
    return fd >= 0 ? 0 : -1;
}
