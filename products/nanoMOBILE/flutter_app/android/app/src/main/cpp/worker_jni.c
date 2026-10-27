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

extern int nanoshell_worker_kill_task(const char* task_id);

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

// Los daemons detached y su recolector viven en worker_daemons_jni.c.
// Tareas síncronas y señales de grupo conservan aquí sus interfaces originales.

// Kill switch: terminate the worker process group
// El worker ejecuta tareas en threads (fork + _spawn_internal + waitpid).
// Un binario colgado (apt sin input, tar infinito) mantiene el waitpid
// bloqueado para siempre. Este JNI hace kill(-pgid, SIGKILL): como el hijo
// vive en el process group del worker (no hace setsid), cae junto con él.
// Daemons detached (Xvnc/openbox) hacen setsid() → group propio → sobreviven
// (MainActivity.onDestroy se encarga de ellos en el proceso principal).
JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_workerIsolateProcessGroup(
    JNIEnv* env, jclass cls) {
    pid_t pid = getpid();
    if (setpgid(0, 0) != 0) {
        int saved_errno = errno;
        __android_log_print(ANDROID_LOG_ERROR, "nanoshell-worker",
            "worker process-group isolation failed: pid=%d errno=%d", pid, saved_errno);
        return -saved_errno;
    }

    pid_t pgid = getpgrp();
    int rc = pgid == pid ? 0 : -EPERM;
    __android_log_print(rc == 0 ? ANDROID_LOG_INFO : ANDROID_LOG_ERROR,
        "nanoshell-worker", "worker process-group isolation: pid=%d pgid=%d rc=%d",
        pid, pgid, rc);
    return rc;
}

JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_workerKillGroup(
    JNIEnv* env, jclass cls) {
    pid_t pid = getpid();
    pid_t pgid = getpgrp();
    // Android app processes can share zygote's inherited process group. Never
    // repeat the device-observed failure that killed Nano's main process.
    if (pgid <= 0 || pgid != pid) {
        __android_log_print(ANDROID_LOG_ERROR, "nanoshell-worker",
            "refusing shared process-group kill: pid=%d pgid=%d", pid, pgid);
        return -EPERM;
    }
    // kill al group completo: hijo colgado + reaper threads + este proceso.
    int rc = kill(-pgid, SIGKILL);
    __android_log_print(ANDROID_LOG_WARN, "nanoshell-worker",
        "workerKillGroup: SIGKILL a pgid=%d rc=%d", pgid, rc);
    return rc == 0 ? 0 : -1;
}

// Kill individual de una tarea activa en el worker (ownership por tarea).
// Envía SIGTERM y luego SIGKILL si es necesario, sin afectar al worker
// ni a otras tareas concurrentes.
JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_workerKillTask(
    JNIEnv* env, jclass cls, jstring taskId) {
    if (!taskId) return -1;
    const char* tid = (*env)->GetStringUTFChars(env, taskId, NULL);
    int rc = nanoshell_worker_kill_task(tid);
    __android_log_print(ANDROID_LOG_WARN, "nanoshell-worker",
        "workerKillTask: taskId=%s rc=%d", tid ? tid : "(null)", rc);
    if (tid) (*env)->ReleaseStringUTFChars(env, taskId, tid);
    return (jint)rc;
}

