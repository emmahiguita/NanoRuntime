/* Registro y recolector de hijos detached, independiente de tareas y PTY. */
#define _GNU_SOURCE
#include "worker_daemon_registry.h"
#include <android/log.h>
#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

extern int nanoshell_worker_spawn_detached(const char*, const char* const[],
                                           const char* const[]);

typedef struct daemon_entry {
    char* name;
    pid_t pid;
    int retired;
    struct daemon_entry* next;
} daemon_entry;

static daemon_entry* entries;
static pthread_mutex_t registry_lock = PTHREAD_MUTEX_INITIALIZER;
static int reaper_started; /* Solo se lee/escribe bajo registry_lock. */

// QUÉ: recoge exclusivamente hijos registrados, no roba estados de tareas/PTY.
// CÓMO: waitpid por PID con WNOHANG; EINTR se reintenta en el siguiente ciclo.
// POR QUÉ: la entrada solo desaparece al recogerlo o confirmar ECHILD.
static void reap_locked(void) {
    daemon_entry** cursor = &entries;
    while (*cursor) {
        daemon_entry* item = *cursor;
        int status = 0;
        pid_t result = waitpid(item->pid, &status, WNOHANG);
        if (result == item->pid || (result < 0 && errno == ECHILD)) {
            if (result == item->pid) {
                __android_log_print(ANDROID_LOG_INFO, "nanoshell-worker",
                    "reaped detached pid=%d retired=%d status=%d",
                    item->pid, item->retired, status);
            }
            *cursor = item->next;
            free(item->name);
            free(item);
        } else {
            cursor = &item->next;
        }
    }
}

// Un hilo por worker, sin esperas bloqueantes sobre un hijo ni hilos por PID.
static void* reaper_loop(void* unused) {
    (void)unused;
    for (;;) {
        pthread_mutex_lock(&registry_lock);
        reap_locked();
        int active = entries != NULL;
        pthread_mutex_unlock(&registry_lock);
        usleep(active ? 250000 : 2000000);
    }
    return NULL;
}

// Se inicia ANTES del fork: si falla, no se deja un hijo sin recolector.
static int ensure_reaper_locked(void) {
    if (reaper_started) return 0;
    pthread_t thread;
    int result = pthread_create(&thread, NULL, reaper_loop, NULL);
    if (result != 0) { errno = result; return -1; }
    pthread_detach(thread);
    reaper_started = 1;
    __android_log_print(ANDROID_LOG_INFO, "nanoshell-worker",
        "Single native reaper thread started for detached daemons");
    return 0;
}

// QUÉ: reemplaza el daemon activo, conservando los anteriores hasta recogerlos.
// CÓMO: reserva memoria antes del fork y serializa matar/fork/registro.
// POR QUÉ: ni un fallo de memoria ni un spawn concurrente debe perder un PID.
int worker_daemon_spawn(const char* binary, const char* const argv[],
                        const char* const envp[]) {
    if (!binary || !binary[0]) { errno = EINVAL; return -1; }
    const char* name = strrchr(binary, '/');
    name = name ? name + 1 : binary;
    daemon_entry* item = calloc(1, sizeof(*item));
    if (!item) return -1;
    item->name = strdup(name);
    if (!item->name) { free(item); return -1; }
    pthread_mutex_lock(&registry_lock);
    reap_locked();
    if (ensure_reaper_locked() != 0) {
        pthread_mutex_unlock(&registry_lock);
        free(item->name);
        free(item);
        return -1;
    }
    for (daemon_entry* old = entries; old; old = old->next) {
        if (!old->retired && strcmp(old->name, name) == 0) {
            // El lock impide recoger/reutilizar el PID entre validar y matar.
            if (kill(old->pid, SIGKILL) != 0 && errno != ESRCH) {
                pthread_mutex_unlock(&registry_lock);
                free(item->name);
                free(item);
                return -1;
            }
            old->retired = 1; /* NO se borra ni se sobrescribe su PID. */
            __android_log_print(ANDROID_LOG_INFO, "nanoshell-worker",
                "retiring duplicate pid=%d before spawn", old->pid);
        }
    }
    int pid = nanoshell_worker_spawn_detached(binary, argv, envp);
    if (pid > 0) {
        item->pid = pid;
        item->next = entries;
        entries = item;
    } else {
        free(item->name);
        free(item);
    }
    pthread_mutex_unlock(&registry_lock);
    return pid;
}

// Una entrada retirada o ya recogida no puede presentarse como motor listo.
int worker_daemon_is_alive(int pid) {
    if (pid <= 0) return 0;
    int alive = 0;
    pthread_mutex_lock(&registry_lock);
    reap_locked();
    for (daemon_entry* item = entries; item; item = item->next) {
        if (item->pid == pid && !item->retired) {
            alive = kill(pid, 0) == 0 || errno == EPERM;
            break;
        }
    }
    pthread_mutex_unlock(&registry_lock);
    return alive;
}

// Ownership y señal bajo el mismo lock: nunca mata un PID ajeno o reciclado.
int worker_daemon_kill(int pid) {
    if (pid <= 0) return -1;
    int result = -1;
    pthread_mutex_lock(&registry_lock);
    reap_locked();
    for (daemon_entry* item = entries; item; item = item->next) {
        if (item->pid == pid) {
            result = kill(pid, SIGKILL) == 0 ? 0 : -1;
            if (result == 0) item->retired = 1;
            break;
        }
    }
    pthread_mutex_unlock(&registry_lock);
    __android_log_print(ANDROID_LOG_INFO, "nanoshell-worker",
        "workerKillPid: registered pid=%d rc=%d", pid, result);
    return result;
}
