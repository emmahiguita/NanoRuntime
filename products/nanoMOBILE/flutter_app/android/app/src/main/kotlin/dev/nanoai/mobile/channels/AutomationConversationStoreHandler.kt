package dev.nanoai.mobile.channels

import dev.nanoai.mobile.automation.AutomationStoreDb
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Aísla las rutas durables de memoria conversacional del resto del almacén.
internal class AutomationConversationStoreHandler(private val db: AutomationStoreDb) {
    /// Despacha persistencia de mensajes/estado y eventos de auditoría append-only.
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "conversationAssignmentList" -> result.success(db.listConversationAssignments())
            "conversationAssign" -> result.success(
                db.assignConversation(
                    addressKey = call.argument<String>("addressKey").orEmpty(),
                    scopeId = call.argument<String>("scopeId").orEmpty(),
                    ownerId = call.argument<String>("ownerId").orEmpty(),
                    agentId = call.argument<String>("agentId").orEmpty(),
                    previousAgentId = call.argument<String>("previousAgentId"),
                    channel = call.argument<String>("channel").orEmpty(),
                    appPackage = call.argument<String>("appPackage").orEmpty(),
                    channelAccountId = call.argument<String>("channelAccountId").orEmpty(),
                    conversationId = call.argument<String>("conversationId").orEmpty(),
                    assignedAtMs = call.argument<Number>("assignedAtMs")?.toLong() ?: 0L,
                    reason = call.argument<String>("reason").orEmpty(),
                    minimalContext = call.argument<String>("minimalContext").orEmpty(),
                ),
            )
            "conversationMessageAppend" -> result.success(
                db.appendConversationMessage(
                    scopeId = call.argument<String>("scopeId").orEmpty(),
                    eventId = call.argument<String>("eventId").orEmpty(),
                    direction = call.argument<String>("direction").orEmpty(),
                    deliveryState = call.argument<String>("deliveryState").orEmpty(),
                    sender = call.argument<String>("sender").orEmpty(),
                    body = call.argument<String>("body").orEmpty(),
                    atMs = call.argument<Number>("atMs")?.toLong() ?: 0L,
                    ruleId = call.argument<String>("ruleId").orEmpty(),
                ),
            )
            "conversationStatePut" -> result.success(
                db.putConversationDialogueState(
                    scopeId = call.argument<String>("scopeId").orEmpty(),
                    stateJson = call.argument<String>("stateJson").orEmpty(),
                    updatedAtMs = call.argument<Number>("updatedAtMs")?.toLong() ?: 0L,
                ),
            )
            "conversationClear" -> result.success(
                db.clearConversationData(
                    scopeId = call.argument<String>("scopeId").orEmpty(),
                    memoryJson = call.argument<String>("memoryJson").orEmpty(),
                ),
            )
            "conversationMessageList" -> result.success(
                db.listConversationMessages(
                    scopeId = call.argument<String>("scopeId").orEmpty(),
                    limit = call.argument<Number>("limit")?.toInt() ?: 200,
                ),
            )
            "appendEvent" -> {
                val convId = call.argument<String>("convId").orEmpty()
                val kind = call.argument<String>("kind").orEmpty()
                val detail = call.argument<String>("detail").orEmpty()
                if (kind.isEmpty()) {
                    result.error("BAD_ARG", "kind requerido", null)
                } else {
                    result.success(db.appendEvent(convId, kind, detail))
                }
            }
            else -> return false
        }
        return true
    }
}
