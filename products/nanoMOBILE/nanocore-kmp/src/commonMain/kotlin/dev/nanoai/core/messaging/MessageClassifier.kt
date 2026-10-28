// ─────────────────────────────────────────────────────────────────────────────
// commonMain · dev.nanoai.core.messaging · MessageClassifier.kt
//
// QUÉ  : Clasificador de mensajes entrantes: separa chats reales de
//         notificaciones de estado, reacciones y avisos del sistema.
//         Extrae la lógica pura de WhatsAppConversationNotificationClassifier.kt
//         (Android) hacia commonMain, donde puede usarse en iOS también.
// CÓMO : En Android el `actual` alimenta el resultado con los extras de la
//         notificación. En iOS el `actual` recibe el payload del UNNotification.
//         La decisión de admisión (admits()) vive aquí, compartida.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.messaging

/** Evidencia normalizada de una notificación de mensaje. */
data class MessageEvidence(
    /** Texto principal del mensaje recibido. Puede estar vacío. */
    val text: String,
    /** Identificador de la conversación (JID, shortcutId, locusId…). */
    val conversationId: String,
    /** Nombre del remitente según la plataforma de mensajería. */
    val senderName: String,
    /** Identificador del paquete / bundle de la app de origen. */
    val sourcePackage: String,
    /** true si la notificación es un resumen de grupo (debe ignorarse). */
    val isGroupSummary: Boolean,
    /** true si la notificación está marcada como "ongoing" (debe ignorarse). */
    val isOngoing: Boolean,
)

/** Resultado de la clasificación. */
enum class MessageClass {
    /** Mensaje de chat real al que el agente puede responder. */
    CONVERSATION,

    /** Reacción a un estado, canal o aviso del sistema — ignorar. */
    STATUS_OR_SYSTEM,

    /** El mensaje no viene de WhatsApp / aplicación de mensajería conocida. */
    FOREIGN,
}

private val WHATSAPP_PACKAGES = setOf("com.whatsapp", "com.whatsapp.w4b")

// Patrones de texto que indican reacciones a estado o avisos internos.
private val STATUS_REACTION_RE = Regex(
    """((reaccion[oó]|respondi[oó]|le gusta|dio me gusta|liked|reacted|replied).{0,48}(tu estado|your status|seu status)|(tu estado|your status|seu status).{0,48}(le gusta|liked|reacted))""",
    setOf(RegexOption.IGNORE_CASE),
)
private val SYSTEM_NOTICE_RE = Regex(
    """buscando mensajes nuevos|comprobando si hay|checking for new messages|whatsapp web|copia de seguridad|backup in progress""",
    setOf(RegexOption.IGNORE_CASE),
)
private val STATUS_TITLES = setOf(
    "actualizaciones de estado", "status updates", "actualizaciones", "novedades",
)
private val JID_STATUS_MARKERS = setOf("status@broadcast", "@newsletter")
private val JID_CHAT_MARKERS   = listOf("@s.whatsapp.net", "@c.us", "@g.us", "@lid")

/**
 * Clasificador puro: dada la [MessageEvidence] decide si es un chat real.
 * No toca ninguna API de plataforma — 100 % testable en commonTest.
 */
object MessageClassifier {
    fun classify(evidence: MessageEvidence): MessageClass {
        if (evidence.sourcePackage !in WHATSAPP_PACKAGES) return MessageClass.FOREIGN
        if (evidence.isGroupSummary || evidence.isOngoing)  return MessageClass.STATUS_OR_SYSTEM

        val searchable = listOf(
            evidence.conversationId,
            evidence.text,
        ).joinToString(" ").lowercase()

        if (STATUS_TITLES.any { it in searchable }) return MessageClass.STATUS_OR_SYSTEM
        if (JID_STATUS_MARKERS.any { it in searchable }) return MessageClass.STATUS_OR_SYSTEM
        if (STATUS_REACTION_RE.containsMatchIn(searchable)) return MessageClass.STATUS_OR_SYSTEM
        if (SYSTEM_NOTICE_RE.containsMatchIn(searchable))   return MessageClass.STATUS_OR_SYSTEM

        val hasText = evidence.text.isNotBlank()
        val hasIdentity = evidence.conversationId.isNotBlank() ||
            JID_CHAT_MARKERS.any { it in searchable } ||
            evidence.senderName.isNotBlank()

        return if (hasText && hasIdentity) MessageClass.CONVERSATION
               else MessageClass.STATUS_OR_SYSTEM
    }

    /** Atajo directo para el caso de admisión simple. */
    fun admits(evidence: MessageEvidence): Boolean =
        classify(evidence) == MessageClass.CONVERSATION
}
