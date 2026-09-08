package dev.nanoai.mobile.channels

import android.content.Context
import android.icu.text.BreakIterator
import android.icu.text.Normalizer2
import android.icu.util.ULocale
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.textclassifier.ConversationAction
import android.view.textclassifier.ConversationActions
import android.view.textclassifier.TextClassificationManager
import android.view.textclassifier.TextClassifier
import android.view.textclassifier.TextLanguage
import android.view.textservice.SentenceSuggestionsInfo
import android.view.textservice.SpellCheckerSession
import android.view.textservice.TextInfo
import android.view.textservice.TextServicesManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.FutureTask
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.TimeUnit

/**
 * Android como coprocesador lingüístico (A03-A06):
 *
 *  - `normalize` (A03): ICU NFKC + segmentación por palabras/frases. El texto
 *    crudo jamás se muta: el resultado normalizado viaja en `normalized` y el
 *    caller conserva el original (RAW INPUT MUST REMAIN IMMUTABLE).
 *  - `spellCheck` (A04): SpellCheckerSession del sistema reutilizada, con
 *    timeout corto y degradación honesta. Devuelve SOLO señales (offset,
 *    longitud, sugerencias) — nunca reescribe el texto.
 *  - `detectLanguage` (A05): TextClassifier.detectLanguage (API 29+), señal
 *    de idioma con confianza, sin ML Kit nuevo.
 *  - `conversationActions` (A06): suggestConversationActions (API 28+) como
 *    HINTS. TYPE_TEXT_REPLY es candidato barato, jamás respuesta autorizada.
 *
 * Threading: el trabajo bloqueante corre en un executor de un hilo con
 * timeout (get con límite); el result del MethodChannel se resuelve SIEMPRE
 * en main. Sin sesiones duplicadas, sin listeners huérfanos (close() en
 * onDestroy de MainActivity).
 */
class LanguageAssistChannelHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/language_assist"
        private const val TAG = "NanoLangAssist"

        // Señales baratas: si el sistema no contesta en este margen, el
        // pipeline sigue SIN la señal (fail-open a LLM, nunca inventar).
        private const val SPELL_TIMEOUT_MS = 600L
        private const val CLASSIFIER_TIMEOUT_MS = 1200L
        private const val SPELL_MAX_SUGGESTIONS = 2
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    // Un solo hilo para llamadas bloqueantes del TextClassifier (pueden
    // tardar segundos). Acotado por diseño: 1 hilo, timeout en get().
    private val classifierExecutor = ThreadPoolExecutor(1, 1, 0L, TimeUnit.MILLISECONDS, ArrayBlockingQueue<Runnable>(8))

    // Sesión de spell checker reutilizada (una por app, cerrada en close()).
    private var spellSession: SpellCheckerSession? = null

    private fun <T> runClassifier(result: MethodChannel.Result, fallback: T, operation: () -> T) {
        var resolved = false // accessed only on main
        lateinit var timeout: Runnable
        val task = object : FutureTask<T>(java.util.concurrent.Callable { operation() }) {
            override fun done() {
                val value = try { get() } catch (_: Exception) { fallback }
                mainHandler.post {
                    if (!resolved) {
                        resolved = true
                        mainHandler.removeCallbacks(timeout)
                        result.success(value)
                    }
                }
            }
        }
        timeout = Runnable {
            if (!resolved) {
                resolved = true
                task.cancel(true)
                classifierExecutor.purge()
                result.success(fallback)
            }
        }
        mainHandler.postDelayed(timeout, CLASSIFIER_TIMEOUT_MS)
        try {
            classifierExecutor.execute(task)
        } catch (_: RejectedExecutionException) {
            mainHandler.removeCallbacks(timeout)
            resolved = true
            result.success(fallback)
        }
    }

    private fun capabilities(): Map<String, Any?> {
        val tsm = context.getSystemService(Context.TEXT_SERVICES_MANAGER_SERVICE)
            as? TextServicesManager
        val spellEnabled = try {
            tsm?.isSpellCheckerEnabled == true
        } catch (_: Exception) {
            false
        }
        return mapOf(
            "icu" to true, // android.icu API 24+; minSdk 26 lo garantiza
            "spellChecker" to spellEnabled,
            "spellCheckerSpanish" to (spellSpanishLocale() != null),
            // API 34+: TextLanguage multi-locale (getLocale(int) +
            // getConfidenceScore(ULocale)); el jar 34+ eliminó las variantes
            // sin argumento. La matriz refleja la API que COMPILAMOS.
            "languageDetect" to (Build.VERSION.SDK_INT >= 34),
            // Request.Builder(List<ConversationActions.Message>) = API 30+.
            "conversationActions" to (Build.VERSION.SDK_INT >= 30),
            "thermalApi" to (Build.VERSION.SDK_INT >= 29),
        )
    }

    private fun spellSpanishLocale(): java.util.Locale? {
        val tsm = context.getSystemService(Context.TEXT_SERVICES_MANAGER_SERVICE)
            as? TextServicesManager ?: return null
        return try {
            val infos = tsm.enabledSpellCheckerInfos ?: return null
            for (info in infos) {
                for (i in 0 until info.subtypeCount) {
                    val locale = info.getSubtypeAt(i).locale
                    if (locale.startsWith("es")) {
                        return java.util.Locale.forLanguageTag(locale)
                    }
                }
            }
            null
        } catch (_: Exception) {
            null
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capabilities" -> result.success(capabilities())
            "thermalStatus" -> result.success(thermalStatus())
            "normalize" -> result.success(normalize(call.argument<String>("text").orEmpty()))
            "spellCheck" -> spellCheck(call.argument<String>("text").orEmpty(), result)
            "detectLanguage" -> detectLanguage(call.argument<String>("text").orEmpty(), result)
            "conversationActions" ->
                conversationActions(call.argument<String>("text").orEmpty(), result)
            "close" -> {
                close()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** A03 — NFKC + conteo de palabras/frases. Síncrono y barato (µs). */
    private fun normalize(text: String): Map<String, Any?> {
        val normalized = try {
            Normalizer2.getNFKCInstance().normalize(text)
        } catch (_: Exception) {
            text
        }
        var wordCount = 0
        var sentenceCount = 0
        try {
            val words = BreakIterator.getWordInstance(ULocale.forLanguageTag("es"))
            words.setText(normalized)
            var start = words.first()
            var end = words.next()
            while (end != BreakIterator.DONE) {
                if (normalized.substring(start, end).any { it.isLetterOrDigit() }) {
                    wordCount++
                }
                start = end
                end = words.next()
            }
            val sentences = BreakIterator.getSentenceInstance(ULocale.forLanguageTag("es"))
            sentences.setText(normalized)
            var s = sentences.first()
            var e = sentences.next()
            while (e != BreakIterator.DONE) {
                if (normalized.substring(s, e).any { it.isLetterOrDigit() }) {
                    sentenceCount++
                }
                s = e
                e = sentences.next()
            }
        } catch (_: Exception) {
            wordCount = 0
            sentenceCount = 0
        }
        return mapOf(
            "normalized" to normalized,
            "wordCount" to wordCount,
            "sentenceCount" to sentenceCount,
        )
    }

    /** A04 — sugerencias del corrector del sistema, sin mutar el texto. */
    private fun spellCheck(text: String, result: MethodChannel.Result) {
        if (text.isBlank()) {
            result.success(emptyList<Any>())
            return
        }
        val tsm = context.getSystemService(Context.TEXT_SERVICES_MANAGER_SERVICE)
            as? TextServicesManager
        if (tsm == null || !tsm.isSpellCheckerEnabled) {
            result.error("spell_disabled", "corrector del sistema deshabilitado", null)
            return
        }
        if (pendingSpell != null) {
            result.error("spell_busy", "corrector ocupado", null)
            return
        }
        val created = if (spellSession == null) try {
            // @Nullable en el jar: algunos OEM pueden devolver null.
            tsm.newSpellCheckerSession(
                null,
                spellSpanishLocale(),
                spellListener,
                true, // respeta el ajuste de idioma del usuario
            )
        } catch (_: Exception) {
            null
        } else null
        val session = spellSession ?: created
        if (session == null) {
            result.error("spell_unavailable", "sin sesión de corrector", null)
            return
        }
        spellSession = session

        val cookie = ++spellCookie
        var resolved = false
        val pending: (Map<String, Any?>) -> Unit = { payload ->
            if (!resolved) {
                resolved = true
                result.success(payload)
            }
        }
        pendingSpell = pending
        // Timeout: el corrector puede no contestar nunca en algunos OEM.
        mainHandler.postDelayed({
            if (!resolved) {
                resolved = true
                pendingSpell = null
                spellSession?.close()
                spellSession = null
                result.error("spell_timeout", "corrector no contestó", null)
            }
        }, SPELL_TIMEOUT_MS)
        try {
            session.getSentenceSuggestions(
                arrayOf(TextInfo(text, cookie, cookie)),
                SPELL_MAX_SUGGESTIONS,
            )
        } catch (_: Exception) {
            if (!resolved) {
                resolved = true
                pendingSpell = null
                result.error("spell_error", "corrector falló", null)
            }
        }
    }

    private var spellCookie = 0
    private var pendingSpell: ((Map<String, Any?>) -> Unit)? = null

    private val spellListener = object : SpellCheckerSession.SpellCheckerSessionListener {
        override fun onGetSuggestions(results: Array<out android.view.textservice.SuggestionsInfo>?) {
            // No se usa (solo se piden sugerencias de frase).
        }

        override fun onGetSentenceSuggestions(results: Array<out SentenceSuggestionsInfo>?) {
            val first = results?.firstOrNull()
            if (first != null && first.suggestionsCount > 0 &&
                first.getSuggestionsInfoAt(0)?.cookie != spellCookie) return
            val pending = pendingSpell
            pendingSpell = null
            if (pending == null) return
            val words = mutableListOf<Map<String, Any?>>()
            results?.firstOrNull()?.let { sentence ->
                for (i in 0 until sentence.suggestionsCount) {
                    val info = sentence.getSuggestionsInfoAt(i)
                    if (info != null && info.suggestionsCount > 0) {
                        val suggestions = (0 until info.suggestionsCount)
                            .map { info.getSuggestionAt(it) }
                            .filter { it.isNotBlank() }
                        words.add(
                            mapOf(
                                "start" to sentence.getOffsetAt(i),
                                "length" to sentence.getLengthAt(i),
                                "suggestions" to suggestions,
                            ),
                        )
                    }
                }
            }
            pending(mapOf("words" to words))
        }
    }

    /** A05 — idioma dominante con confianza (API 34+: TextLanguage
     *  multi-locale; el jar 34+ eliminó getLocale()/getConfidenceScore()
     *  sin argumento). */
    private fun detectLanguage(text: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 34) {
            result.success(null)
            return
        }
        if (text.isBlank()) {
            result.success(null)
            return
        }
        val classifier = try {
            (context.getSystemService(Context.TEXT_CLASSIFICATION_SERVICE)
                as TextClassificationManager).textClassifier
        } catch (_: Exception) {
            result.success(null)
            return
        }
        runClassifier<Map<String, Any?>?>(result, null) {
            try {
                val response = classifier.detectLanguage(
                    TextLanguage.Request.Builder(text).build(),
                )
                if (response.localeHypothesisCount <= 0) {
                    null
                } else {
                    val locale = response.getLocale(0)
                    if (locale == null || locale.toLanguageTag().isBlank()) {
                        null
                    } else {
                        mapOf(
                            "language" to locale.language,
                            "locale" to locale.toLanguageTag(),
                            "confidence" to response.getConfidenceScore(locale),
                        )
                    }
                }
            } catch (_: Exception) {
                null
            }
        }

    }

    /** A06 — acciones conversacionales como hints (API 30+: el Builder solo
     *  acepta ConversationActions.Message; el texto viaja en el Message). */
    private fun conversationActions(text: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 30) {
            result.success(emptyList<Any>())
            return
        }
        if (text.isBlank()) {
            result.success(emptyList<Any>())
            return
        }
        val classifier = try {
            (context.getSystemService(Context.TEXT_CLASSIFICATION_SERVICE)
                as TextClassificationManager).textClassifier
        } catch (_: Exception) {
            result.success(emptyList<Any>())
            return
        }
        runClassifier<List<Map<String, Any?>>>(result, emptyList()) {
            try {
                val message = ConversationActions.Message.Builder(
                    ConversationActions.Message.PERSON_USER_SELF,
                ).setText(text).build()
                val request = ConversationActions.Request.Builder(listOf(message))
                    .setTypeConfig(
                        TextClassifier.EntityConfig.createWithExplicitEntityList(
                            listOf(
                                ConversationAction.TYPE_TEXT_REPLY,
                                ConversationAction.TYPE_CALL_PHONE,
                                ConversationAction.TYPE_OPEN_URL,
                                ConversationAction.TYPE_CREATE_REMINDER,
                                ConversationAction.TYPE_VIEW_MAP,
                            ),
                        ),
                    )
                    .build()
                classifier.suggestConversationActions(request).conversationActions.map {
                    mapOf(
                        "type" to it.type,
                        "textReply" to it.textReply,
                        "confidence" to it.confidenceScore,
                    )
                }
            } catch (_: Exception) {
                emptyList()
            }
        }

    }

    /** A12 — estado térmico del sistema (PowerManager, API 29+). Síncrono y
     *  barato; -1 = API ausente o lectura fallida (degradación honesta). */
    private fun thermalStatus(): Int {
        if (Build.VERSION.SDK_INT < 29) return -1
        return try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            pm.currentThermalStatus
        } catch (_: Exception) {
            -1
        }
    }

    /** Cierra la sesión de corrector y el executor (A13). Idempotente. */
    fun close() {
        Log.d(TAG, "close — sesión de corrector y executor liberados")
        spellSession?.close()
        spellSession = null
        pendingSpell = null
        mainHandler.removeCallbacksAndMessages(null)
        classifierExecutor.shutdownNow()
    }
}
