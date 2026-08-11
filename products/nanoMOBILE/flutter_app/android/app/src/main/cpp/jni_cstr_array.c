#include "jni_cstr_array.h"

#include <stdlib.h>
#include <string.h>

char** jni_cstr_array_from_object_array(JNIEnv* env, jobjectArray arr, jsize* out_n) {
    *out_n = 0;
    if (!arr) return NULL;
    jsize n = (*env)->GetArrayLength(env, arr);
    if (n <= 0) return NULL;

    char** out = malloc(sizeof(char*) * (n + 1));
    if (!out) return NULL;

    for (jsize i = 0; i < n; i++) {
        jstring js = (jstring)(*env)->GetObjectArrayElement(env, arr, i);
        const char* utf = js ? (*env)->GetStringUTFChars(env, js, NULL) : NULL;
        out[i] = utf ? strdup(utf) : strdup("");
        if (utf) (*env)->ReleaseStringUTFChars(env, js, utf);
        if (js) (*env)->DeleteLocalRef(env, (jobject)js);
    }
    out[n] = NULL;
    *out_n = n;
    return out;
}

void jni_cstr_array_free(char** arr, jsize n) {
    if (!arr) return;
    for (jsize i = 0; i < n; i++) free(arr[i]);
    free(arr);
}
