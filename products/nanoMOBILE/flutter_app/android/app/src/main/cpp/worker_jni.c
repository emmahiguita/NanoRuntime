/*
 * worker_jni.c - JNI bridge for detached/background nanoshell workers.
 *
 * Keeps process orchestration separate from PTY session handling so pty_jni.c
 * remains focused on terminal sessions only.
 */

#define _GNU_SOURCE
#include <errno.h>
#include <jni.h>
#include <pthread.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <android/log.h>

#include "jni_cstr_array.h"
// workerSpawn (process :nanoshell, no GPU)
// Declarado en nanoshell.c; ejecuta _spawn_internal y escribe a archivos.
extern int nanoshell_worker_spawn(
    const char* binary_path,
    const char* const argv[],
    const char* const envp[],
    const char* ld_preload,
    const char* task_id,
    const char* files_dir);

JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_workerSpawn(
    JNIEnv* env, jclass cls,
    jstring binaryPath,
    jobjectArray argv,
    jobjectArray envp,
    jstring ldPreload,
    jstring taskId,
    jstring filesDir) {

    const char* bin = binaryPath ? (*env)->GetStringUTFChars(env, binaryPath, NULL) : NULL;
    const char* ld = ldPreload ? (*env)->GetStringUTFChars(env, ldPreload, NULL) : NULL;
    const char* tid = taskId ? (*env)->GetStringUTFChars(env, taskId, NULL) : NULL;
    const char* fdir = filesDir ? (*env)->GetStringUTFChars(env, filesDir, NULL) : NULL;

    jsize nargv = 0, nenvp = 0;
    char** cargv = jni_cstr_array_from_object_array(env, argv, &nargv);
    char** cenvp = jni_cstr_array_from_object_array(env, envp, &nenvp);

    int rc = nanoshell_worker_spawn(bin, cargv, cenvp, ld, tid, fdir);

    jni_cstr_array_free(cargv, nargv);
    jni_cstr_array_free(cenvp, nenvp);
    if (bin) (*env)->ReleaseStringUTFChars(env, binaryPath, bin);
    if (ld) (*env)->ReleaseStringUTFChars(env, ldPreload, ld);
    if (tid) (*env)->ReleaseStringUTFChars(env, taskId, tid);
    if (fdir) (*env)->ReleaseStringUTFChars(env, filesDir, fdir);
    return (jint)rc;
}

// Daemon spawn (no wait, no stdout/stderr capture)
extern int nanoshell_worker_spawn_detached(
    const char* binary_path,
    const char* const argv[],
    const char* const envp[]);

// ── Registro de daemons por binario (anti-duplicados) ─────────────────────
// Cada spawn detached de un mismo binario reemplaza al anterior: el viejo se
// mata con SIGKILL antes del fork. Evidencia device 2026-08-12 (ColorOS):
// app muere por ANR, daemons huérfanos (hijos del worker) sobreviven ocupando
// 5901/6001, el Xvnc nuevo muere status=1 ("Address already in use"), openbox
// nuevo status=0 (otro WM en el display) y awaitReady da ready falso contra
// el servidor ajeno. El worker vive entre ciclos de app, así que el registro
// persiste y limpia la cascada de duplicados de raíz.
#define MAX_TRACKED_DAEMONS 8

typedef struct {
    char name[64];
    pid_t pid;
} tracked_daemon_t;

static tracked_daemon_t g_daemons[MAX_TRACKED_DAEMONS];
static pthread_mutex_t g_daemons_lock = PTHREAD_MUTEX_INITIALIZER;

// Registra (o vacía, con pid=-1) el slot del binario y devuelve el pid previo.
static pid_t _swap_daemon_pid(const char* basename, pid_t new_pid) {
    pid_t old = -1;
    pthread_mutex_lock(&g_daemons_lock);
    int slot = -1, free_slot = -1;
    for (int i = 0; i < MAX_TRACKED_DAEMONS; i++) {
        if (g_daemons[i].pid > 0 && strcmp(g_daemons[i].name, basename) == 0) {
            slot = i;
            break;
        }
        if (free_slot < 0 && g_daemons[i].pid <= 0) free_slot = i;
    }
    if (slot >= 0) {
        old = g_daemons[slot].pid;
        g_daemons[slot].pid = new_pid;
    } else if (free_slot >= 0) {
        strncpy(g_daemons[free_slot].name, basename, sizeof(g_daemons[free_slot].name) - 1);
        g_daemons[free_slot].name[sizeof(g_daemons[free_slot].name) - 1] = '\0';
        g_daemons[free_slot].pid = new_pid;
    }
    pthread_mutex_unlock(&g_daemons_lock);
    return old;
}

// Marca el slot del registro cuyo pid coincida con el proceso reapeado.
// Así workerIsProcessAlive puede distinguir "vivo" de "pid reciclado":
// sin esta marca, un pid reutilizado por Android tras la muerte del daemon
// devolvería un falso positivo en kill(pid, 0).
static void _daemon_mark_reaped(pid_t pid) {
    pthread_mutex_lock(&g_daemons_lock);
    for (int i = 0; i < MAX_TRACKED_DAEMONS; i++) {
        if (g_daemons[i].pid == pid) {
            g_daemons[i].pid = 0;
            break;
        }
    }
    pthread_mutex_unlock(&g_daemons_lock);
}

// Reaper thread: espera a que un proceso detached muera y lo recolecta
// para evitar zombies. Se lanza en background inmediatamente despues
// del spawn; bloquea en waitpid hasta que el hijo termina.

static void* _reap_detached(void* arg) {
    int pid = *(int*)arg;
    free(arg);
    int status;
    waitpid(pid, &status, 0);
    _daemon_mark_reaped(pid);
    // H3: un segfault (139) reportaba 0 porque WEXITSTATUS sin chequear
    // WIFSIGNALED enmascara la señal. Reportar señal real cuando muere
    // por señal (evidencia device 2026-08-13: tint2 segfault en librsvg
    // aparecía como "status=0" en el log del worker).
    if (WIFSIGNALED(status)) {
        __android_log_print(ANDROID_LOG_WARN, "nanoshell-worker",
            "reaped detached pid=%d signal=%d%s", pid, WTERMSIG(status),
            WCOREDUMP(status) ? " (core)" : "");
    } else {
        __android_log_print(ANDROID_LOG_DEBUG, "nanoshell-worker",
            "reaped detached pid=%d status=%d", pid, WEXITSTATUS(status));
    }
    return NULL;
}

JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_workerSpawnDetached(
    JNIEnv* env, jclass cls,
    jstring binaryPath,
    jobjectArray argv,
    jobjectArray envp) {

    const char* bin = binaryPath ? (*env)->GetStringUTFChars(env, binaryPath, NULL) : NULL;
    jsize nargv = 0, nenvp = 0;
    char** cargv = jni_cstr_array_from_object_array(env, argv, &nargv);
    char** cenvp = jni_cstr_array_from_object_array(env, envp, &nenvp);

    // Anti-duplicados: el spawn de un daemon reemplaza al anterior del mismo
    // binario. El viejo muere ANTES del fork para que el nuevo pueda bindear
    // 5901/6001 (evidencia device: Xvnc nuevo status=1 por "Address already
    // in use" cuando el huérfano del ciclo previo seguía vivo).
    const char* base = bin ? strrchr(bin, '/') : NULL;
    base = base ? base + 1 : bin;
    if (base && base[0]) {
        pid_t prev = _swap_daemon_pid(base, -1);
        if (prev > 0) {
            kill(prev, SIGKILL);
            __android_log_print(ANDROID_LOG_WARN, "nanoshell-worker",
                "matando duplicado %s pid=%d antes del spawn", base, prev);
        }
    }

    int pid = nanoshell_worker_spawn_detached(bin, cargv, cenvp);

    if (pid > 0 && base && base[0]) {
        _swap_daemon_pid(base, pid);
    }

    // Lanzar reaper thread para evitar zombie cuando el proceso detached muera
    if (pid > 0) {
        pthread_t reaper;
        int* pid_copy = malloc(sizeof(int));
        if (pid_copy) {
            *pid_copy = pid;
            if (pthread_create(&reaper, NULL, _reap_detached, pid_copy) == 0) {
                pthread_detach(reaper);
            } else {
                free(pid_copy);
            }
        }
    }

    jni_cstr_array_free(cargv, nargv);
    jni_cstr_array_free(cenvp, nenvp);
    if (bin) (*env)->ReleaseStringUTFChars(env, binaryPath, bin);
    return (jint)pid;
}

// ── Liveness de daemons detached (Xvnc/openbox) ─────────────────────────
// El proceso PRINCIPAL no puede leer /proc/<pid> de los hijos del worker
// (Android restringe /proc a los hijos directos del proceso lector — el
// refactor al worker :nanoshell dejó ciego al backend). El worker es el
// PADRE: puede preguntar por sus hijos con kill(pid, 0) sin tocar sockets
// ni /proc. La marca del reaper (_daemon_mark_reaped) cierra la brecha del
// pid reciclado: alive = registro aún apunta al pid Y kill(0) lo confirma.
JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_workerIsProcessAlive(
    JNIEnv* env, jclass cls, jint pid) {
    if (pid <= 0) return 0;
    pthread_mutex_lock(&g_daemons_lock);
    int registered = 0;
    for (int i = 0; i < MAX_TRACKED_DAEMONS; i++) {
        if (g_daemons[i].pid == pid) {
            registered = 1;
            break;
        }
    }
    pthread_mutex_unlock(&g_daemons_lock);
    if (!registered) return 0;
    if (kill(pid, 0) == 0) return 1;
    return (errno == EPERM) ? 1 : 0;
}

// Kill switch: terminate the worker process group
// El worker ejecuta tareas en threads (fork + _spawn_internal + waitpid).
// Un binario colgado (apt sin input, tar infinito) mantiene el waitpid
// bloqueado para siempre. Este JNI hace kill(-pgid, SIGKILL): como el hijo
// vive en el process group del worker (no hace setsid), cae junto con él.
// Daemons detached (Xvnc/openbox) hacen setsid() → group propio → sobreviven
// (MainActivity.onDestroy se encarga de ellos en el proceso principal).
JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_workerKillGroup(
    JNIEnv* env, jclass cls) {
    pid_t pgid = getpgrp();
    if (pgid <= 0) return -1;
    // kill al group completo: hijo colgado + reaper threads + este proceso.
    int rc = kill(-pgid, SIGKILL);
    __android_log_print(ANDROID_LOG_WARN, "nanoshell-worker",
        "workerKillGroup: SIGKILL a pgid=%d rc=%d", pgid, rc);
    return rc == 0 ? 0 : -1;
}
