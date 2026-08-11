#ifndef NANOAI_JNI_CSTR_ARRAY_H
#define NANOAI_JNI_CSTR_ARRAY_H

#include <jni.h>

char** jni_cstr_array_from_object_array(JNIEnv* env, jobjectArray arr, jsize* out_n);
void jni_cstr_array_free(char** arr, jsize n);

#endif
