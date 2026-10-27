package dev.nanoai.mobile.mnn

import android.util.Log

fun interface MnnTokenCallback {
    fun onToken(token: String)
}

// JNI surface kept narrow: Flutter never owns or calls an MNN model object.
internal object MnnNative {
    init {
        try {
            System.loadLibrary("MNN")
            System.loadLibrary("MNN_Express")
            System.loadLibrary("MNNOpenCV")
            System.loadLibrary("MNNAudio")
            System.loadLibrary("llm")
            System.loadLibrary("nanomnn")
            Log.i("MnnNative", "Librerías nativas MNN cargadas con éxito.")
        } catch (e: Throwable) {
            Log.e("MnnNative", "Fallo al cargar librerías nativas MNN: ${e.message}", e)
        }
    }
    external fun load(modelPath: String): Boolean
    // Limpia la cancelación antes de anunciar que el request ya es cancelable.
    external fun prepareGeneration()
    external fun resetConversation()
    // Mensajes estructurados (system, history serializado, turno). El nativo
    // aplica la plantilla jinja del modelo y reutiliza KV; no recibe ChatML.
    external fun generate(system: String, history: String, prompt: String, maxTokens: Int, temperature: Double, topP: Double, callback: MnnTokenCallback): String
    external fun cancel()
    external fun unload(): Boolean
}
