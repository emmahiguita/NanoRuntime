package dev.nanoai.mobile.channels

import dev.nanoai.mobile.automation.AutomationStoreDb
import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Lecturas existentes separadas del despachador; mantiene argumentos y límites. */
internal class NotificationHistoryChannelHandler(private val db: AutomationStoreDb, context: Context) {
    private val pages = NotificationHistoryPageReader(context)
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "notificationHistoryPage" -> pages.read(call, result)
            "notificationHistoryList" -> result.success(
                db.listNotificationConversations(call.argument<Number>("limit")?.toInt() ?: 100),
            )
            "notificationHistoryMessages" -> {
                val historyId = call.argument<String>("historyId").orEmpty()
                if (historyId.isBlank()) {
                    result.error("BAD_ARG", "historyId requerido", null)
                    return true
                }
                result.success(db.listNotificationMessages(
                    historyId, call.argument<Number>("limit")?.toInt() ?: 500,
                ))
            }
            else -> return false
        }
        return true
    }
}
