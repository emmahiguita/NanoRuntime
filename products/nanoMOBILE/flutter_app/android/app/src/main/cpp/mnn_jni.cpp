#include <jni.h>
#include <llm/llm.hpp>
#include "llmconfig.hpp"
#include "jni_scoped_utf_chars.h"
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

// QUÉ: caché del prompt multi-turno para reutilizar KV (reuse_kv).
// CÓMO: guarda el ChatML completo del turno anterior + respuesta del modelo.
// POR QUÉ: si el prompt nuevo extiende ese prefijo, solo se prefila el sufijo
// nuevo (delta); si diverge, se reinicia con prefill completo. Semántica
// idéntica al prompt-cache interno de MNN response(ChatMessages).
std::string cachedPromptText;

constexpr char kAssistantGen[] = "<|im_start|>assistant\n";
// Capacidad KV del paquete Omni (default de MNN LlmConfig::max_all_tokens).
constexpr int kKvCapacity = 2048;

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

// QUÉ: compara texto nuevo contra el caché y devuelve los tokens delta.
// CÓMO: tokeniza el prompt completo y camina los tokens decodificados hasta
// cubrir el prefijo común (byte-BPE decodifica exacto), igual que el
// prompt-cache de MNN upstream. Devuelve vacío si no hay reutilización.
// POR QUÉ: prefillar solo el sufijo nuevo reduce el TTFT multi-turno.
std::vector<int> deltaTokensIfReusable(Llm& llm,
                                        const std::string& prompt,
                                        const std::string& compareText,
                                        const std::vector<int>& fullTokens,
                                        bool& reusable) {
    reusable = false;
    if (cachedPromptText.empty() || compareText.size() < cachedPromptText.size() ||
        compareText.compare(0, cachedPromptText.size(), cachedPromptText) != 0) {
        return {};
    }
    const size_t textCommon = cachedPromptText.size();
    // El tokenizer puede anteponer tokens fijos (BOS) que no corresponden a texto.
    const size_t prefixCount = llm.tokenizer_encode("").size();
    size_t charPos = 0;
    size_t tokenSplit = prefixCount;
    for (size_t i = prefixCount; i < fullTokens.size(); ++i) {
        const std::string piece = llm.tokenizer_decode(fullTokens[i]);
        if (charPos + piece.size() > textCommon) break;
        charPos += piece.size();
        tokenSplit++;
    }
    if (tokenSplit >= fullTokens.size()) {
        // Nada nuevo que prefilar: no hay turno que responder.
        return {};
    }
    reusable = true;
    return std::vector<int>(fullTokens.begin() + tokenSplit, fullTokens.end());
}
}

// Loads the downloaded model directory; C++ owns the only live LLM instance.
extern "C" JNIEXPORT jboolean JNICALL
Java_dev_nanoai_mobile_mnn_MnnNative_load(JNIEnv* env, jobject, jstring pathValue) {
    std::string path;
    {
        const ScopedUtfChars chars(env, pathValue);
        if (!chars) return JNI_FALSE;
        path.assign(chars.get());
    }  // Release the Java buffer before file checks and heavyweight model loading.

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
    // QUÉ: el adaptador Nano expone texto, no el pipeline Omni multimodal.
    // CÓMO: LlmConfig fusiona llm_config.json, cuyas banderas Omni siguen true
    // incluso al abrir ese archivo directamente. Desactiva modalidades ANTES
    // de construir Llm: createLLM habría creado Omni y cargado visual/audio/talker.
    // POR QUÉ: esos pesos innecesarios presionaban RAM/swap y mataban WhatsApp.
    // LlmConfig y el constructor pertenecen a la versión MNN 3.6.1 fijada aquí.
    auto textConfig = std::make_shared<MNN::Transformer::LlmConfig>(path);
    textConfig->config_.merge(ujson::json::parse(
        R"({"is_visual":false,"is_audio":false,"has_talker":false,"precision":"low","memory":"low"})"));
    auto next = std::unique_ptr<Llm>(new Llm(textConfig));
    LOGI("Perfil MNN: texto; vision=false audio=false talker=false");
    if (!next) {
        LOGE("MNN createLLM retornó null para ruta: %s", path.c_str());
        throwJava(env, "MNN createLLM falló (retornó null)");
        return JNI_FALSE;
    }
    // reuse_kv: conserva la caché KV entre turnos; el JNI prefila solo el delta.
    // jinja: plantilla ChatML del modelo aplicada en nativo (minijinja); Dart
    // ya no ensambla ChatML a mano. El paquete Omni no trae template en su
    // config.json, así que se inyecta la plantilla oficial de Qwen2.5/Omni.
    if (!next->set_config(R"({"backend_type":"cpu","thread_num":4,"use_template":false,"async":false,"reuse_kv":true,)" R"("jinja":{"chat_template":"{%- for message in messages %}{% if message['role'] == 'system' %}<|im_start|>system\n{{ message['content'] }}<|im_end|>\n{% elif message['role'] == 'user' %}<|im_start|>user\n{{ message['content'] }}<|im_end|>\n{% elif message['role'] == 'assistant' %}<|im_start|>assistant\n{{ message['content'] }}<|im_end|>\n{% endif %}{%- endfor %}{% if add_generation_prompt %}<|im_start|>assistant\n{% endif %}","eos":"<|im_end|>"}})")) {
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
    cachedPromptText.clear();
    return JNI_TRUE;
}

// Resets cancellation before Kotlin publishes this request to its cancel path.
extern "C" JNIEXPORT void JNICALL
Java_dev_nanoai_mobile_mnn_MnnNative_prepareGeneration(JNIEnv*, jobject) {
    std::lock_guard<std::mutex> lock(modelMutex);
    cancelRequested.store(false);
}

// Cambiar de sesión invalida KV sin volver a cargar los pesos. Sin sesión
// estable tampoco se reutiliza memoria de un consumidor anónimo previo.
extern "C" JNIEXPORT void JNICALL
Java_dev_nanoai_mobile_mnn_MnnNative_resetConversation(JNIEnv*, jobject) {
    std::lock_guard<std::mutex> lock(modelMutex);
    if (model) model->reset();
    cachedPromptText.clear();
}

// Prefill delta (KV reuse) o completo (divergencia), luego decodifica con
// callback por token y devuelve métricas medidas, nunca estimadas.
// Recibe mensajes estructurados (system + history serializado + turno) y
// renderiza la plantilla jinja del modelo en nativo.
extern "C" JNIEXPORT jstring JNICALL
Java_dev_nanoai_mobile_mnn_MnnNative_generate(JNIEnv* env, jobject,
                                               jstring systemValue, jstring historyValue,
                                               jstring promptValue,
                                               jint maxTokens, jdouble temperature, jdouble topP,
                                               jobject callback) {
    // QUÉ: copia los tres mensajes JNI que forman el prompt del turno.
    // CÓMO: ScopedUtfChars libera cada búfer incluso si otra lectura o copia falla.
    // POR QUÉ: el motor no debe mantener cadenas Java fijadas durante inferencia.
    std::string systemText;
    std::string historyText;
    std::string userText;
    {
        const ScopedUtfChars sysChars(env, systemValue);
        const ScopedUtfChars histChars(env, historyValue);
        const ScopedUtfChars userChars(env, promptValue);
        if (!sysChars || !histChars || !userChars) return nullptr;
        systemText.assign(sysChars.get());
        historyText.assign(histChars.get());
        userText.assign(userChars.get());
    }  // Release JNI buffers before model inference can take a long time.

    std::lock_guard<std::mutex> lock(modelMutex);
    if (!model) {
        LOGE("Intento de generar sin modelo MNN cargado");
        throwJava(env, "No hay modelo MNN cargado");
        return nullptr;
    }

    // Mensajes estructurados: system, historial con roles y turno del usuario.
    // El serializado Kotlin usa \u0001 entre rol y contenido, \u0002 entre
    // mensajes; el contenido de chat no contiene esos caracteres de control.
    using MNN::Transformer::ChatMessage;
    std::vector<ChatMessage> messages;
    messages.emplace_back("system", systemText);
    size_t start = 0;
    while (start < historyText.size()) {
        const size_t sep = historyText.find('\u0002', start);
        const std::string entry = historyText.substr(
            start, sep == std::string::npos ? std::string::npos : sep - start);
        const size_t roleEnd = entry.find('\u0001');
        if (roleEnd != std::string::npos && roleEnd + 1 < entry.size()) {
            const std::string role = entry.substr(0, roleEnd);
            if (role == "user" || role == "assistant") {
                messages.emplace_back(role, entry.substr(roleEnd + 1));
            }
        }
        if (sep == std::string::npos) break;
        start = sep + 1;
    }
    messages.emplace_back("user", userText);

    // La plantilla (jinja) vive en el modelo; Dart ya no la ensambla.
    const std::string prompt = model->apply_chat_template(messages);
    if (prompt.empty()) {
        LOGE("MNN: la plantilla del modelo no produjo prompt");
        throwJava(env, "MNN: plantilla de chat vacía");
        return nullptr;
    }

    LOGI("Iniciando inferencia MNN (system=%zu, historyMsgs=%zu, user=%zu, maxTokens=%d, cacheLen=%zu)",
         systemText.size(), messages.size() - 2, userText.size(), maxTokens, cachedPromptText.size());
    // Configura muestreo y penalización por turno; no toca reuse_kv ni el KV.
    std::ostringstream sampling;
    sampling << "{\"reuse_kv\":true,"
             << "\"sampler_type\":\"mixed\",\"mixed_samplers\":[\"penalty\",\"topK\",\"topP\",\"temperature\"],"
             << "\"temperature\":" << temperature << ",\"top_p\":" << topP
             << ",\"top_k\":40,\"repetition_penalty\":1.1}";
    if (!model->set_config(sampling.str())) {
        LOGE("MNN no pudo aplicar los parámetros de muestreo");
        throwJava(env, "MNN no pudo aplicar los parámetros de muestreo");
        return nullptr;
    }

    // El prompt llega como ChatML terminado en el gen-prompt del asistente.
    const std::string gen(kAssistantGen);
    std::string compareText = prompt;
    if (compareText.size() >= gen.size() &&
        compareText.compare(compareText.size() - gen.size(), gen.size(), gen) == 0) {
        compareText.resize(compareText.size() - gen.size());
    }

    const auto started = std::chrono::steady_clock::now();
    const std::vector<int> fullTokens = model->tokenizer_encode(prompt);
    bool reused = false;
    const std::vector<int> delta = deltaTokensIfReusable(
        *model, prompt, compareText, fullTokens, reused);

    // Protege el KV: entrada + salida no pueden exceder la capacidad del paquete.
    const int positionAfterPrefill = reused
        ? static_cast<int>(model->getCurrentHistory()) + static_cast<int>(delta.size())
        : static_cast<int>(fullTokens.size());
    if (positionAfterPrefill >= kKvCapacity) {
        LOGE("Prompt excede la capacidad KV (%d tokens): %d", kKvCapacity, positionAfterPrefill);
        throwJava(env, "CONTEXT_CAPACITY_EXCEEDED: reduce contexto para MNN");
        return nullptr;
    }
    int budget = maxTokens;
    if (positionAfterPrefill + budget > kKvCapacity) {
        budget = kKvCapacity - positionAfterPrefill;
        LOGW("MNN maxTokens recortado a %d por capacidad KV", budget);
    }

    long long prefillMs = -1;
    if (reused) {
        // Turno extendido: generate_init conserva el KV (reuse_kv=true) y
        // generate(delta, 0) prefila únicamente el sufijo nuevo.
        model->generate_init();
        const auto prefillStart = std::chrono::steady_clock::now();
        model->generate(delta, 0);
        prefillMs = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - prefillStart).count();
        LOGI("MNN prefill DELTA (%d tokens, reutilizando %d) en %lld ms",
             (int)delta.size(), (int)model->getCurrentHistory() - (int)delta.size(),
             (long long)prefillMs);
    } else {
        // Primer turno o historial divergente: reinicia KV y prefila todo.
        model->reset();
        cachedPromptText.clear();
        model->generate_init();
        const auto prefillStart = std::chrono::steady_clock::now();
        model->generate(fullTokens, 0);
        prefillMs = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - prefillStart).count();
        LOGI("MNN prefill COMPLETO (%d tokens) en %lld ms",
             (int)fullTokens.size(), (long long)prefillMs);
    }

    long long ttftMs = -1;
    int generated = 0;
    bool stoppedByModel = false;
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

    std::string responseText;
    while (!cancelRequested.load() && !model->stoped() && generated < budget) {
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
            stoppedByModel = true;
            LOGI("MNN stop token alcanzado (token=%d)", token);
            break;
        }
        const auto decoded = model->tokenizer_decode(token);
        if (decoded.empty()) continue;
        if (ttftMs < 0) {
            ttftMs = std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::steady_clock::now() - started).count();
            LOGI("MNN primer token (TTFT) en %lld ms", ttftMs);
        }
        responseText += decoded;
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
    LOGI("MNN generación terminada: %d tokens, %.2f tok/s, TTFT=%lld ms, prefill=%lld ms",
         generated, tokensPerSecond, ttftMs, prefillMs);

    // Solo un turno cerrado por stop token extiende la caché; cancelado,
    // recortado o con error obliga a prefill completo la próxima vez.
    if (stoppedByModel && !cancelRequested.load()) {
        cachedPromptText = prompt + responseText + "<|im_end|>\n";
    } else {
        cachedPromptText.clear();
    }
    LOGI("MNN caché de turno %s (%zu chars)",
         cachedPromptText.empty() ? "invalidada" : "actualizada", cachedPromptText.size());

    std::ostringstream metrics;
    metrics << "{\"ttft_ms\":" << (ttftMs < 0 ? 0 : ttftMs)
            << ",\"cache_reused\":" << (reused ? "true" : "false")
            << ",\"prefill_tokens\":" << (reused ? delta.size() : fullTokens.size())
            << ",\"decode_tok_s\":" << tokensPerSecond
            << ",\"prefill_ms\":" << (prefillMs < 0 ? 0 : prefillMs)
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
    cachedPromptText.clear();
    cancelRequested.store(false);
    LOGI("Modelo MNN liberado");
    return JNI_TRUE;
}
