#include <jni.h>
#include <llm/llm.hpp>
#include <android/log.h>
#include <atomic>
#include <chrono>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <sys/stat.h>
#include <vector>

#define LOG_TAG "MnnNativeJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

using MNN::Transformer::Llm;
namespace {
std::mutex modelMutex;
std::unique_ptr<Llm> model;
std::atomic_bool cancelRequested{false};

// Converts UTF-8 model tokens to UTF-16 so JNI safely carries emoji and CJK text.
jstring toJavaString(JNIEnv* env, const std::string& text) {
    std::vector<jchar> chars;
    for (size_t i = 0; i < text.size();) {
        const auto c = static_cast<unsigned char>(text[i]);
        uint32_t code = c;
        size_t count = c < 0x80 ? 1 : (c & 0xE0) == 0xC0 ? 2 : (c & 0xF0) == 0xE0 ? 3 : 4;
        code = count == 1 ? c : c & (count == 2 ? 0x1F : count == 3 ? 0x0F : 0x07);
        if (i + count > text.size()) { code = 0xFFFD; count = 1; }
        else for (size_t j = 1; j < count; ++j) {
            const auto tail = static_cast<unsigned char>(text[i + j]);
            if ((tail & 0xC0) != 0x80) { code = 0xFFFD; count = j; break; }
            code = (code << 6) | (tail & 0x3F);
        }
        if (code <= 0xFFFF) chars.push_back(static_cast<jchar>(code));
        else {
            code -= 0x10000;
            chars.push_back(static_cast<jchar>(0xD800 + (code >> 10)));
            chars.push_back(static_cast<jchar>(0xDC00 + (code & 0x3FF)));
        }
        i += count;
    }
    return env->NewString(chars.data(), static_cast<jsize>(chars.size()));
}

// Returns a Java exception instead of hiding a native load/generation failure.
void throwJava(JNIEnv* env, const char* message) {
    jclass type = env->FindClass("java/lang/IllegalStateException");
    if (type != nullptr) env->ThrowNew(type, message);
}
}

// Loads the downloaded model directory; C++ owns the only live LLM instance.
extern "C" JNIEXPORT jboolean JNICALL
Java_dev_nanoai_mobile_mnn_MnnNative_load(JNIEnv* env, jobject, jstring pathValue) {
    const char* chars = env->GetStringUTFChars(pathValue, nullptr);
    if (chars == nullptr) return JNI_FALSE;
    std::string path(chars);
    env->ReleaseStringUTFChars(pathValue, chars);

    struct stat info{};
    if (stat(path.c_str(), &info) == 0 && S_ISDIR(info.st_mode)) {
        // Prefer llm_config.json for lightweight text-only LLM execution
        // to prevent loading visual/audio/talker models (~2.3 GB extra RAM)
        // which triggers the Android/ColorOS Athena process memory limit.
        std::string llmConfig = path + "/llm_config.json";
        struct stat st{};
        if (stat(llmConfig.c_str(), &st) == 0 && S_ISREG(st.st_mode)) {
            path = llmConfig;
        } else {
            path += "/config.json";
        }
    } else if (path.size() >= 11 && path.compare(path.size() - 11, 11, "config.json") == 0) {
        std::string llmConfig = path.substr(0, path.size() - 11) + "llm_config.json";
        struct stat st{};
        if (stat(llmConfig.c_str(), &st) == 0 && S_ISREG(st.st_mode)) {
            path = llmConfig;
        }
    }

    LOGI("Cargando modelo MNN desde: %s", path.c_str());
    std::lock_guard<std::mutex> lock(modelMutex);
    const auto t0 = std::chrono::steady_clock::now();
    auto next = std::unique_ptr<Llm>(Llm::createLLM(path));
    if (!next) {
        LOGE("MNN createLLM retornó null para ruta: %s", path.c_str());
        throwJava(env, "MNN createLLM falló (retornó null)");
        return JNI_FALSE;
    }
    if (!next->set_config(R"({"backend_type":"cpu","thread_num":4,"use_template":false,"async":false})")) {
        LOGE("MNN set_config falló");
        throwJava(env, "MNN set_config falló");
        return JNI_FALSE;
    }
    if (!next->load()) {
        LOGE("MNN load() falló al cargar tensores y pesos");
        throwJava(env, "MNN load() falló al cargar tensores y pesos");
        return JNI_FALSE;
    }
    const auto loadMs = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - t0).count();
    LOGI("Modelo MNN cargado exitosamente en %lld ms", (long long)loadMs);
    model = std::move(next);
    return JNI_TRUE;
}

// Resets cancellation before Kotlin publishes this request to its cancel path.
extern "C" JNIEXPORT void JNICALL
Java_dev_nanoai_mobile_mnn_MnnNative_prepareGeneration(JNIEnv*, jobject) {
    std::lock_guard<std::mutex> lock(modelMutex);
    cancelRequested.store(false);
}

// Prefills the full conversation, emits decoded tokens and returns measured timings.
extern "C" JNIEXPORT jstring JNICALL
Java_dev_nanoai_mobile_mnn_MnnNative_generate(JNIEnv* env, jobject, jstring promptValue,
                                               jint maxTokens, jdouble temperature, jdouble topP,
                                               jobject callback) {
    const char* chars = env->GetStringUTFChars(promptValue, nullptr);
    if (chars == nullptr) return nullptr;
    const std::string prompt(chars);
    env->ReleaseStringUTFChars(promptValue, chars);
    std::lock_guard<std::mutex> lock(modelMutex);
    if (!model) {
        LOGE("Intento de generar sin modelo MNN cargado");
        throwJava(env, "No hay modelo MNN cargado");
        return nullptr;
    }

    LOGI("Iniciando inferencia MNN (prompt len=%zu, maxTokens=%d)", prompt.size(), maxTokens);
    // Configura muestreo y penalización antes de procesar el contexto de cada turno.
    std::ostringstream sampling;
    sampling << "{\"backend_type\":\"cpu\",\"thread_num\":4,\"use_template\":false,\"async\":false,"
             << "\"sampler_type\":\"mixed\",\"mixed_samplers\":[\"penalty\",\"topK\",\"topP\",\"temperature\"],"
             << "\"temperature\":" << temperature << ",\"top_p\":" << topP
             << ",\"top_k\":40,\"repetition_penalty\":1.1}";
    if (!model->set_config(sampling.str())) {
        LOGE("MNN no pudo aplicar los parámetros de muestreo");
        throwJava(env, "MNN no pudo aplicar los parámetros de muestreo");
        return nullptr;
    }
    model->reset();
    std::ostringstream prefill;
    const auto started = std::chrono::steady_clock::now();
    model->response(prompt, &prefill, nullptr, 0);
    const auto prefillMs = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - started).count();
    LOGI("MNN prefill completado en %lld ms", (long long)prefillMs);

    long long ttftMs = -1;
    int generated = 0;
    auto* context = model->getContext();
    jclass cbClass = env->FindClass("dev/nanoai/mobile/mnn/MnnTokenCallback");
    jmethodID onTokenMid = nullptr;
    bool isVoidMethod = false;
    if (cbClass != nullptr) {
        onTokenMid = env->GetMethodID(cbClass, "onToken", "(Ljava/lang/String;)V");
        if (onTokenMid != nullptr) isVoidMethod = true;
    }
    if (onTokenMid == nullptr) {
        env->ExceptionClear();
        jclass objClass = env->GetObjectClass(callback);
        if (objClass != nullptr) {
            onTokenMid = env->GetMethodID(objClass, "onToken", "(Ljava/lang/String;)V");
            if (onTokenMid != nullptr) {
                isVoidMethod = true;
            } else {
                env->ExceptionClear();
                onTokenMid = env->GetMethodID(objClass, "invoke", "(Ljava/lang/Object;)Ljava/lang/Object;");
                isVoidMethod = false;
            }
        }
    }
    if (onTokenMid == nullptr) {
        LOGE("No se pudo resolver methodID del callback MNN");
        env->ExceptionClear();
    }

    while (!cancelRequested.load() && !model->stoped() && generated < maxTokens) {
        model->generate(1);
        context = model->getContext();
        if (context == nullptr) break;
        if (context->status == MNN::Transformer::LlmStatus::INTERNAL_ERROR) {
            LOGE("MNN reportó error interno durante la generación");
            throwJava(env, "MNN reportó un error durante la generación");
            return nullptr;
        }
        ++generated;
        const int token = context->current_token;
        if (model->is_stop(token)) {
            LOGI("MNN stop token alcanzado (token=%d)", token);
            break;
        }
        const auto decoded = model->tokenizer_decode(token);
        if (decoded.empty()) continue;
        if (ttftMs < 0) {
            ttftMs = std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::steady_clock::now() - started).count();
            LOGI("MNN primer token (TTFT) en %lld ms: '%s'", ttftMs, decoded.c_str());
        }
        if (onTokenMid != nullptr) {
            jstring text = toJavaString(env, decoded);
            if (text != nullptr) {
                if (isVoidMethod) {
                    env->CallVoidMethod(callback, onTokenMid, text);
                } else {
                    jobject ret = env->CallObjectMethod(callback, onTokenMid, text);
                    if (ret != nullptr) env->DeleteLocalRef(ret);
                }
                env->DeleteLocalRef(text);
                if (env->ExceptionCheck()) {
                    LOGE("MNN: Excepción en Java callback onToken");
                    env->ExceptionClear();
                    break;
                }
            }
        }
    }
    context = model->getContext();
    const double decodeSeconds = context == nullptr ? 0.0 : context->decode_us / 1e6;
    const double tokensPerSecond = decodeSeconds > 0 ? generated / decodeSeconds : 0.0;
    LOGI("MNN generación terminada: %d tokens, %.2f tok/s, TTFT=%lld ms", generated, tokensPerSecond, ttftMs);
    std::ostringstream metrics;
    metrics << "{\"ttft_ms\":" << (ttftMs < 0 ? 0 : ttftMs)
            << ",\"decode_tok_s\":" << tokensPerSecond
            << ",\"generated_tokens\":" << generated << "}";
    return toJavaString(env, metrics.str());
}

// Cancellation is atomic; unload waits on modelMutex until the active decode exits.
extern "C" JNIEXPORT void JNICALL
Java_dev_nanoai_mobile_mnn_MnnNative_cancel(JNIEnv*, jobject) {
    LOGI("Solicitud de cancelación MNN recibida");
    cancelRequested.store(true);
}

// The mutex makes unload wait for generation, preventing use-after-free in JNI.
extern "C" JNIEXPORT jboolean JNICALL
Java_dev_nanoai_mobile_mnn_MnnNative_unload(JNIEnv*, jobject) {
    LOGI("Descargando modelo MNN de memoria nativa...");
    std::lock_guard<std::mutex> lock(modelMutex);
    model.reset();
    cancelRequested.store(false);
    LOGI("Modelo MNN liberado");
    return JNI_TRUE;
}
