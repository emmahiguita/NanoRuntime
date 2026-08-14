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
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

#include "pty.h"
#include "pty_session_registry.h"
#include "jni_cstr_array.h"

// â”€â”€ Registro de sesiones â”€â”€

static int _valid_pty_size(jint rows, jint cols) {
    return rows >= 1 && rows <= 200 && cols >= 1 && cols <= 400;
}

JNIEXPORT jlong JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_ptySpawn(
    JNIEnv* env, jclass cls,
    jobjectArray argv, jobjectArray envp,
    jstring ldPreload, jint rows, jint cols) {

    jsize nArgv = 0, nEnvp = 0;
    char** cargv = jni_cstr_array_from_object_array(env, argv, &nArgv);
    char** cenvp = jni_cstr_array_from_object_array(env, envp, &nEnvp);

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
    if (!_valid_pty_size(rows, cols)) {
        jni_cstr_array_free(cargv, nArgv);
        jni_cstr_array_free(cenvp, nEnvp);
        return 0;
    }
    if (nArgv > 0) {
        PtySessionRecord* rec = pty_registry_alloc();
        if (rec) {
            int rc = pty_spawn(&rec->pty, cargv, cenvp, ld,
                               (unsigned short)cols, (unsigned short)rows);
            if (rc == 0) {
                id = rec->id;
            } else {
                pty_registry_free(rec);
            }
        }
    }

    jni_cstr_array_free(cargv, nArgv);
    jni_cstr_array_free(cenvp, nEnvp);
    return id;
}

// â”€â”€ ptyWrite: envía bytes al master (input del usuario al terminal) â”€â”€

JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_ptyWrite(
    JNIEnv* env, jclass cls, jlong id, jbyteArray data) {

    int fd = pty_registry_dup_fd(id);
    if (fd < 0) return -1;

    jsize len = data ? (*env)->GetArrayLength(env, data) : 0;
    if (len <= 0) { close(fd); return 0; }

    jbyte* buf = (*env)->GetByteArrayElements(env, data, NULL);
    if (!buf) { close(fd); return -1; }
    int n = pty_write(fd, (const char*)buf, (size_t)len);
    close(fd);
    (*env)->ReleaseByteArrayElements(env, data, buf, JNI_ABORT);
    return n;
}

// â”€â”€ ptyRead: lectura no bloqueante, devuelve byte[] (null si sin datos) â”€â”€

JNIEXPORT jbyteArray JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_ptyRead(
    JNIEnv* env, jclass cls, jlong id, jint maxBytes) {

    int fd = pty_registry_dup_fd(id);
    if (fd < 0) return NULL;

    int cap = maxBytes > 0 ? maxBytes : 4096;
    if (cap > 65536) cap = 65536;
    char* buf = malloc(cap);
    if (!buf) { close(fd); return NULL; }

    int n = pty_read(fd, buf, (size_t)cap);
    close(fd);
    if (n <= 0) { free(buf); return NULL; }

    jbyteArray out = (*env)->NewByteArray(env, n);
    if (out) (*env)->SetByteArrayRegion(env, out, 0, n, (const jbyte*)buf);
    free(buf);
    return out;
}

// â”€â”€ ptyResize â”€â”€

JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_ptyResize(
    JNIEnv* env, jclass cls, jlong id, jint rows, jint cols) {

    if (!_valid_pty_size(rows, cols)) return -1;
    int fd = pty_registry_dup_fd(id);
    if (fd < 0) return -1;
    int rc = pty_resize(fd, (unsigned short)rows, (unsigned short)cols);
    close(fd);
    return rc;
}

// â”€â”€ ptyKill: envía señal al proceso hijo â”€â”€

JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_ptyKill(
    JNIEnv* env, jclass cls, jlong id, jint signal) {

    pid_t pid = pty_registry_pid(id);
    if (pid <= 0) return -1;
    return pty_kill(pid, signal);
}

// â”€â”€ ptyClose: cierra fd master y libera la sesión â”€â”€

JNIEXPORT void JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_ptyClose(
    JNIEnv* env, jclass cls, jlong id) {

    pty_registry_close(id);
}

// â”€â”€ ptyGetPid: para debugging â”€â”€

JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_ptyGetPid(
    JNIEnv* env, jclass cls, jlong id) {

    pid_t pid = pty_registry_pid(id);
    return pid > 0 ? (jint)pid : -1;
}

// â”€â”€ ptyIsAlive: 1 vivo, 0 terminado (out_rc = exit code) â”€â”€

JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_ptyIsAlive(
    JNIEnv* env, jclass cls, jlong id) {

    pid_t pid = pty_registry_pid(id);
    if (pid <= 0) return 0;
    return pty_is_alive(pid, NULL);
}

