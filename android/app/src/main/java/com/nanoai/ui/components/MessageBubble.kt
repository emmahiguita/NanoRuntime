package com.nanoai.ui.components

import androidx.compose.animation.*
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.dp
import com.nanoai.ui.presentation.chat.ChatMessage
import com.nanoai.ui.presentation.chat.MessageSender
import com.nanoai.ui.presentation.chat.MessageStatus
import com.nanoai.ui.theme.*
import java.text.SimpleDateFormat
import java.util.*

/**
 * MessageBubble PRO — Material3 compliant chat bubble.
 * Features: long-press actions, code blocks, status indicators, timestamps.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun MessageBubble(
    message: ChatMessage,
    onCopy: () -> Unit,
    onDelete: () -> Unit,
    onRetry: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    var showActions by remember { mutableStateOf(false) }
    val isUser = message.isUser
    val alignment = if (isUser) Alignment.CenterEnd else Alignment.CenterStart
    val bubbleShape = if (isUser) NanoShapeTokens.userBubble else NanoShapeTokens.aiBubble
    val containerColor = if (isUser) MaterialTheme.colorScheme.primaryContainer
                         else MaterialTheme.colorScheme.surfaceVariant
    val textColor = if (isUser) MaterialTheme.colorScheme.onPrimaryContainer
                    else MaterialTheme.colorScheme.onSurface

    val timeStr = remember(message.timestamp) {
        SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(message.timestamp))
    }

    Box(modifier = modifier.fillMaxWidth().padding(vertical = NanoSpacingTokens.xs), contentAlignment = alignment) {
        Column(
            horizontalAlignment = if (isUser) Alignment.End else Alignment.Start,
            modifier = Modifier.widthIn(max = 300.dp)
        ) {
            // Message bubble
            Surface(
                shape = bubbleShape,
                color = containerColor,
                tonalElevation = if (isUser) 2.dp else 1.dp,
                modifier = Modifier
                    .combinedClickable(
                        onClick = { showActions = !showActions },
                        onLongClick = { showActions = true }
                    )
                    .semantics { contentDescription = "Mensaje de ${message.sender}" }
            ) {
                Column(modifier = Modifier.padding(NanoSpacingTokens.md)) {
                    // Render content blocks
                    if (message.contents.isNotEmpty()) {
                        message.contents.forEach { content ->
                            ContentRenderer(content = content)
                            if (content != message.contents.last()) {
                                Spacer(Modifier.height(NanoSpacingTokens.sm))
                            }
                        }
                    } else if (message.text.isNotEmpty()) {
                        Text(text = message.text, style = NanoTypeTokens.body, color = textColor)
                    }

                    Spacer(Modifier.height(NanoSpacingTokens.xs))

                    // Footer: TPS + timestamp + status
                    Row(
                        horizontalArrangement = Arrangement.End,
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        message.tokensPerSecond?.let { tps ->
                            Text("$tps t/s", style = NanoTypeTokens.label, color = textColor.copy(alpha = 0.5f))
                            Spacer(Modifier.width(NanoSpacingTokens.xs))
                        }
                        Text(timeStr, style = NanoTypeTokens.label, color = textColor.copy(alpha = 0.5f))

                        if (message.status == MessageStatus.ERROR) {
                            Spacer(Modifier.width(NanoSpacingTokens.xs))
                            Text("⚠", style = NanoTypeTokens.label)
                        }
                    }
                }
            }

            // Animated action bar
            AnimatedVisibility(
                visible = showActions,
                enter = expandVertically() + fadeIn(tween(NanoAnimationTokens.DurationFastMs)),
                exit = shrinkVertically() + fadeOut(tween(NanoAnimationTokens.DurationFastMs))
            ) {
                Spacer(Modifier.height(4.dp))
                MessageActionsPopup(
                    onCopy = onCopy,
                    onRetry = onRetry,
                    onDelete = onDelete,
                    showRetry = message.status == MessageStatus.ERROR
                )
            }
        }
    }
}
