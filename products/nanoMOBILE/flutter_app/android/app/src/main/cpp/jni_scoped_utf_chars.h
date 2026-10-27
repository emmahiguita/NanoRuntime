#ifndef NANO_JNI_SCOPED_UTF_CHARS_H
#define NANO_JNI_SCOPED_UTF_CHARS_H

#include <jni.h>

// QUÉ: es dueño del búfer UTF que devuelve GetStringUTFChars.
// CÓMO: lo libera al salir del ámbito, incluso ante retornos tempranos o
// excepciones mientras el código copia el texto a una cadena nativa.
// POR QUÉ: JNI mantiene fijada la cadena Java hasta llamar ReleaseStringUTFChars.
class ScopedUtfChars final {
public:
    ScopedUtfChars(JNIEnv* env, jstring value)
        : env_(env),
          value_(value),
          chars_(value == nullptr ? nullptr : env->GetStringUTFChars(value, nullptr)) {}

    ~ScopedUtfChars() {
        if (chars_ != nullptr) env_->ReleaseStringUTFChars(value_, chars_);
    }

    ScopedUtfChars(const ScopedUtfChars&) = delete;
    ScopedUtfChars& operator=(const ScopedUtfChars&) = delete;

    explicit operator bool() const { return chars_ != nullptr; }
    const char* get() const { return chars_; }

private:
    JNIEnv* env_;
    jstring value_;
    const char* chars_;
};

#endif  // NANO_JNI_SCOPED_UTF_CHARS_H
