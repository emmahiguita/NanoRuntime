package com.nanoai.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nanoai.ui.presentation.chat.ChatMessage
import com.nanoai.ui.presentation.chat.ContentType
import com.nanoai.ui.presentation.chat.MessageContent
import com.nanoai.ui.presentation.chat.MessageSender
import com.nanoai.ui.theme.*

/* ================================================================
   ChatDateSeparator — groups messages by date
   ================================================================ */
@Composable
fun ChatDateSeparator(
    label: String,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth().padding(vertical = NanoSpacingTokens.md),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Surface(
            shape = RoundedCornerShape(12.dp),
            color = MaterialTheme.colorScheme.surfaceVariant,
            tonalElevation = 2.dp
        ) {
            Text(
                text = label,
                style = NanoTypeTokens.label,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp)
            )
        }
    }
}

/* ================================================================
   TypingIndicator — animated typing dots
   ================================================================ */
@Composable
fun TypingIndicator(modifier: Modifier = Modifier) {
    val infiniteTransition = rememberInfiniteTransition(label = "typing")
    val dot1 by infiniteTransition.animateFloat(0f, 1f, infiniteRepeatable(tween(400)), label = "d1")
    val dot2 by infiniteTransition.animateFloat(0f, 1f, infiniteRepeatable(tween(400, 200)), label = "d2")
    val dot3 by infiniteTransition.animateFloat(0f, 1f, infiniteRepeatable(tween(400, 400)), label = "d3")

    Surface(
        modifier = modifier,
        shape = NanoShapeTokens.aiBubble,
        color = MaterialTheme.colorScheme.surfaceVariant,
        tonalElevation = 2.dp
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            listOf(dot1, dot2, dot3).forEach { alpha ->
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = alpha.coerceIn(0.2f, 1f)))
                )
            }
        }
    }
}

/* ================================================================
   QuickSuggestionChip — tappable suggestion for empty state
   ================================================================ */
@Composable
fun QuickSuggestionChip(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier,
        onClick = onClick,
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Text(
            text = text,
            style = NanoTypeTokens.caption,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp)
        )
    }
}

/* ================================================================
   MessageActionChip — floating action chip on long-press
   ================================================================ */
@Composable
fun MessageActionsPopup(
    onCopy: () -> Unit,
    onRetry: (() -> Unit)? = null,
    onDelete: () -> Unit,
    showRetry: Boolean = false,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.xs)
    ) {
        IconButton(onClick = onCopy, modifier = Modifier.size(32.dp)) {
            Icon(Icons.Default.ContentCopy, "Copiar", tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(16.dp))
        }
        if (showRetry && onRetry != null) {
            IconButton(onClick = onRetry, modifier = Modifier.size(32.dp)) {
                Icon(Icons.Default.Refresh, "Reintentar", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(16.dp))
            }
        }
        IconButton(onClick = onDelete, modifier = Modifier.size(32.dp)) {
            Icon(Icons.Default.Delete, "Eliminar", tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(16.dp))
        }
    }
}

/* ================================================================
   CodeBlock — professional code display with language tag
   ================================================================ */
@Composable
fun CodeBlock(
    code: String,
    language: String? = null,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        color = MaterialTheme.colorScheme.inverseSurface.copy(alpha = 0.08f),
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Column {
            if (language != null) {
                Text(
                    text = language.uppercase(),
                    style = NanoTypeTokens.label,
                    color = nanoColors().TerminalGreen,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                )
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            }
            Text(
                text = code,
                style = NanoTypeTokens.monospace.copy(fontSize = 12.sp),
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.padding(12.dp)
            )
        }
    }
}

/* ================================================================
   ContentRenderer — renders text, code, and markdown content blocks
   ================================================================ */
@Composable
fun ContentRenderer(
    content: MessageContent,
    modifier: Modifier = Modifier
) {
    when (content.type) {
        ContentType.TEXT -> {
            Text(
                text = content.text,
                style = NanoTypeTokens.body,
                modifier = modifier
            )
        }
        ContentType.CODE -> {
            CodeBlock(code = content.text, language = content.language, modifier = modifier)
        }
        ContentType.MARKDOWN -> {
            // Simplified markdown: render **bold** and `code`
            Text(
                text = content.text,
                style = NanoTypeTokens.body,
                modifier = modifier
            )
        }
    }
}
