/*
 * pty_jni.c — Puente JNI entre Kotlin (NanoshellBridge) y las sesiones PTY.
 *
 * Expone a Kotlin:
 *   ptySpawn(argv, envp, ldPreload, rows, cols) → long sessionId
 *   ptyWrite(sessionId, bytes)  → int
 *   ptyRead(sessionId, maxBytes) → byte[]
 *   ptyResize(sessionId, rows, cols) → int
 *   ptyKill(sessionId, signal) → int
 *   ptyClose(sessionId) → void
 *
 * Mantiene un registro global de sesiones activas (PtySession) con mutex
 * para operar de forma segura desde threads de background de Kotlin.
 */

#define _GNU_SOURCE
#include <jni.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>

#include "pty.h"

// ── Registro de sesiones ──

#define MAX_PTY_SESSIONS 8

typedef struct SessionRec {
    jlong id;            // opaque handle devuelto a Kotlin
    PtySession pty;
    int in_use;
} SessionRec;

static SessionRec g_sessions[MAX_PTY_SESSIONS];
static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;
static long g_next_id = 1;

static SessionRec* _alloc_session(void) {
    pthread_mutex_lock(&g_lock);
    for (int i = 0; i < MAX_PTY_SESSIONS; i++) {
        if (!g_sessions[i].in_use) {
            SessionRec* rec = &g_sessions[i];
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

static SessionRec* _find_session(jlong id) {
    pthread_mutex_lock(&g_lock);
    for (int i = 0; i < MAX_PTY_SESSIONS; i++) {
        if (g_sessions[i].in_use && g_sessions[i].id == id) {
            pthread_mutex_unlock(&g_lock);
            return &g_sessions[i];
        }
    }
    pthread_mutex_unlock(&g_lock);
    return NULL;
}

static void _free_session(SessionRec* rec) {
    pthread_mutex_lock(&g_lock);
    rec->in_use = 0;
    pthread_mutex_unlock(&g_lock);
}

// ── Helpers de conversión ──

static char** _build_carray(JNIEnv* env, jobjectArray arr, int* out_n) {
    *out_n = 0;
    if (!arr) return NULL;
    jsize n = (*env)->GetArrayLength(env, arr);
    if (n <= 0) return NULL;
    char** carr = malloc(sizeof(char*) * (n + 1));
    if (!carr) return NULL;
    for (int i = 0; i < n; i++) {
        jstring js = (jstring)(*env)->GetObjectArrayElement(env, arr, i);
        const char* utf = js ? (*env)->GetStringUTFChars(env, js, NULL) : NULL;
        carr[i] = utf ? strdup(utf) : strdup("");
        if (utf) (*env)->ReleaseStringUTFChars(env, js, utf);
        if (js) (*env)->DeleteLocalRef(env, (jobject)js);
    }
    carr[n] = NULL;
    *out_n = (int)n;
    return carr;
}

static void _free_carray(char** carray, int n) {
    if (!carray) return;
    for (int i = 0; i < n; i++) if (carray[i]) free(carray[i]);
    free(carray);
}

// ── ptySpawn ──

JNIEXPORT jlong JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_ptySpawn(
    JNIEnv* env, jclass cls,
    jobjectArray argv, jobjectArray envp,
    jstring ldPreload, jint rows, jint cols) {

    int nArgv = 0, nEnvp = 0;
    char** cargv = _build_carray(env, argv, &nArgv);
    char** cenvp = _build_carray(env, envp, &nEnvp);

    const char* ld = NULL;
    char ld_buf[256] = {0};
    if (ldPreload) {
        const char* u = (*env)->GetStringUTFChars(env, ldPreload, NULL);
        if (u) {
            strncpy(ld_buf, u, sizeof(ld_buf) - 1);
            ld = ld_buf;
            (*env)->ReleaseStringUTFChars(env, ldPreload, u);
        }
    }

    jlong id = 0;
    if (nArgv > 0) {
        SessionRec* rec = _alloc_session();
        if (rec) {
            int rc = pty_spawn(&rec->pty, cargv, cenvp, ld,
                               (unsigned short)cols, (unsigned short)rows);
            if (rc == 0) {
                id = rec->id;
            } else {
                _free_session(rec);
            }
        }
    }

    _free_carray(cargv, nArgv);
    _free_carray(cenvp, nEnvp);
    return id;
}

// ── ptyWrite: envía bytes al master (input del usuario al terminal) ──

JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_ptyWrite(
    JNIEnv* env, jclass cls, jlong id, jbyteArray data) {

    SessionRec* rec = _find_session(id);
    if (!rec || rec->pty.master_fd < 0) return -1;

    jsize len = data ? (*env)->GetArrayLength(env, data) : 0;
    if (len <= 0) return 0;

    jbyte* buf = (*env)->GetByteArrayElements(env, data, NULL);
    if (!buf) return -1;
    int n = pty_write(rec->pty.master_fd, (const char*)buf, (size_t)len);
    (*env)->ReleaseByteArrayElements(env, data, buf, JNI_ABORT);
    return n;
}

// ── ptyRead: lectura no bloqueante, devuelve byte[] (null si sin datos) ──

JNIEXPORT jbyteArray JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_ptyRead(
    JNIEnv* env, jclass cls, jlong id, jint maxBytes) {

    SessionRec* rec = _find_session(id);
    if (!rec || rec->pty.master_fd < 0) return NULL;

    int cap = maxBytes > 0 ? maxBytes : 4096;
    char* buf = malloc(cap);
    if (!buf) return NULL;

    int n = pty_read(rec->pty.master_fd, buf, (size_t)cap);
    if (n <= 0) { free(buf); return NULL; }

    jbyteArray out = (*env)->NewByteArray(env, n);
    if (out) (*env)->SetByteArrayRegion(env, out, 0, n, (const jbyte*)buf);
    free(buf);
    return out;
}

// ── ptyResize ──

JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_ptyResize(
    JNIEnv* env, jclass cls, jlong id, jint rows, jint cols) {

    SessionRec* rec = _find_session(id);
    if (!rec || rec->pty.master_fd < 0) return -1;
    return pty_resize(rec->pty.master_fd,
                      (unsigned short)rows, (unsigned short)cols);
}

// ── ptyKill: envía señal al proceso hijo ──

JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_ptyKill(
    JNIEnv* env, jclass cls, jlong id, jint signal) {

    SessionRec* rec = _find_session(id);
    if (!rec) return -1;
    return pty_kill(rec->pty.child_pid, signal);
}

// ── ptyClose: cierra fd master y libera la sesión ──

JNIEXPORT void JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_ptyClose(
    JNIEnv* env, jclass cls, jlong id) {

    SessionRec* rec = _find_session(id);
    if (!rec) return;
    pty_close(rec->pty.master_fd);
    rec->pty.master_fd = -1;
    _free_session(rec);
}

// ── ptyGetPid: para debugging ──

JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_ptyGetPid(
    JNIEnv* env, jclass cls, jlong id) {

    SessionRec* rec = _find_session(id);
    if (!rec) return -1;
    return (jint)rec->pty.child_pid;
}

// ── ptyIsAlive: 1 vivo, 0 terminado (out_rc = exit code) ──

JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_ptyIsAlive(
    JNIEnv* env, jclass cls, jlong id) {

    SessionRec* rec = _find_session(id);
    if (!rec) return 0;
    return pty_is_alive(rec->pty.child_pid, NULL);
}
// ── workerSpawn (proceso :nanoshell, sin GPU) ──
// Declarado en nanoshell.c; ejecuta _spawn_internal y escribe a archivos.
extern int nanoshell_worker_spawn(
    const char* binary_path,
    const char* const argv[],
    const char* const envp[],
    const char* ld_preload,
    const char* task_id,
    const char* files_dir);

// JNI helper: String[] → char** (malloc). Caller free() cada elemento + array.
static char** _jstrarr_to_c(JNIEnv* env, jobjectArray arr, jsize* out_n) {
    if (!arr) { *out_n = 0; return NULL; }
    jsize n = (*env)->GetArrayLength(env, arr);
    char** out = malloc(sizeof(char*) * (n + 1));
    if (!out) { *out_n = 0; return NULL; }
    for (jsize i = 0; i < n; i++) {
        jstring js = (jstring)(*env)->GetObjectArrayElement(env, arr, i);
        const char* utf = js ? (*env)->GetStringUTFChars(env, js, NULL) : NULL;
        out[i] = utf ? strdup(utf) : strdup("");
        if (utf) (*env)->ReleaseStringUTFChars(env, js, utf);
    }
    out[n] = NULL;
    *out_n = n;
    return out;
}

static void _free_cstrarr(char** arr, jsize n) {
    if (!arr) return;
    for (jsize i = 0; i < n; i++) free(arr[i]);
    free(arr);
}

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
    char** cargv = _jstrarr_to_c(env, argv, &nargv);
    char** cenvp = _jstrarr_to_c(env, envp, &nenvp);

    int rc = nanoshell_worker_spawn(bin, cargv, cenvp, ld, tid, fdir);

    _free_cstrarr(cargv, nargv);
    _free_cstrarr(cenvp, nenvp);
    if (bin) (*env)->ReleaseStringUTFChars(env, binaryPath, bin);
    if (ld) (*env)->ReleaseStringUTFChars(env, ldPreload, ld);
    if (tid) (*env)->ReleaseStringUTFChars(env, taskId, tid);
    if (fdir) (*env)->ReleaseStringUTFChars(env, filesDir, fdir);
    return (jint)rc;
}

// ── Daemon spawn (sin esperar, sin captura stdout/stderr) ──
extern int nanoshell_worker_spawn_detached(
    const char* binary_path,
    const char* const argv[],
    const char* const envp[]);

JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_workerSpawnDetached(
    JNIEnv* env, jclass cls,
    jstring binaryPath,
    jobjectArray argv,
    jobjectArray envp) {

    const char* bin = binaryPath ? (*env)->GetStringUTFChars(env, binaryPath, NULL) : NULL;
    jsize nargv = 0, nenvp = 0;
    char** cargv = _jstrarr_to_c(env, argv, &nargv);
    char** cenvp = _jstrarr_to_c(env, envp, &nenvp);

    int pid = nanoshell_worker_spawn_detached(bin, cargv, cenvp);

    _free_cstrarr(cargv, nargv);
    _free_cstrarr(cenvp, nenvp);
    if (bin) (*env)->ReleaseStringUTFChars(env, binaryPath, bin);
    return (jint)pid;
}
