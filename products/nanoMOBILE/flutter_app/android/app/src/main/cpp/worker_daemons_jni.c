/* QUÉ: conserva los métodos JNI públicos de daemons, sin lógica de ownership.
 * CÓMO: convierte argumentos y delega spawn/liveness/kill al registro.
 * POR QUÉ: el recolector tiene un único responsable y no afecta a las tareas.
 */
#include <jni.h>
#include "jni_cstr_array.h"
#include "worker_daemon_registry.h"

JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_workerSpawnDetached(
    JNIEnv* env, jclass cls, jstring binaryPath,
    jobjectArray argv, jobjectArray envp) {
    (void)cls;
    const char* bin = binaryPath
        ? (*env)->GetStringUTFChars(env, binaryPath, NULL) : NULL;
    jsize nargv = 0, nenvp = 0;
    char** cargv = jni_cstr_array_from_object_array(env, argv, &nargv);
    char** cenvp = jni_cstr_array_from_object_array(env, envp, &nenvp);
    int pid = -1;
    // Un error JNI (por ejemplo OOM) no debe iniciar un proceso parcial.
    if (!(*env)->ExceptionCheck(env)) {
        pid = worker_daemon_spawn(bin, cargv, cenvp);
    }
    jni_cstr_array_free(cargv, nargv);
    jni_cstr_array_free(cenvp, nenvp);
    if (bin) (*env)->ReleaseStringUTFChars(env, binaryPath, bin);
    return (jint)pid;
}

// La comprobación se realiza en el padre real del daemon (:nanoshell).
JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_workerIsProcessAlive(
    JNIEnv* env, jclass cls, jint pid) {
    (void)env; (void)cls;
    return worker_daemon_is_alive(pid);
}

// Mantiene la misma interfaz Kotlin; el registro valida ownership del PID.
JNIEXPORT jint JNICALL
Java_dev_nanoai_mobile_NanoshellBridge_workerKillPid(
    JNIEnv* env, jclass cls, jint pid) {
    (void)env; (void)cls;
    return worker_daemon_kill(pid);
}
