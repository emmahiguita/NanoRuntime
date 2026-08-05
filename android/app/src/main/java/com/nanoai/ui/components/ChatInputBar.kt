package com.nanoai.ui.components

import androidx.compose.animation.*
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.nanoai.ui.theme.*

/**
 * ChatInputBar PRO — Material3 compliant with:
 * - Character count with limit indicator
 * - Quick suggestions strip
 * - Voice/mic button (placeholder)
 * - Send button with animation
 * - Stop generation button
 */
@Composable
fun ChatInputBar(
    value: String,
    onValueChange: (String) -> Unit,
    onSend: () -> Unit,
    onStop: () -> Unit,
    isGenerating: Boolean,
    characterLimit: Int = 4096,
    suggestions: List<String> = emptyList(),
    onSuggestionClick: (String) -> Unit = {},
    modifier: Modifier = Modifier
) {
    val charCount = value.length
    val isNearLimit = charCount > characterLimit * 0.8f
    val hasContent = value.isNotBlank()

    Column(modifier = modifier.fillMaxWidth()) {
        // Quick suggestions strip
        AnimatedVisibility(
            visible = suggestions.isNotEmpty() && !isGenerating && value.isEmpty(),
            enter = expandVertically() + fadeIn(tween(NanoAnimationTokens.DurationFastMs)),
            exit = shrinkVertically() + fadeOut(tween(NanoAnimationTokens.DurationFastMs))
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = NanoSpacingTokens.sm, vertical = NanoSpacingTokens.xs),
                horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.sm)
            ) {
                suggestions.take(3).forEach { suggestion ->
                    QuickSuggestionChip(
                        text = suggestion,
                        onClick = { onSuggestionClick(suggestion) },
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }

        // Main input bar
        Surface(
            shape = NanoShapeTokens.large,
            color = MaterialTheme.colorScheme.surface,
            tonalElevation = 4.dp,
            shadowElevation = 2.dp,
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = NanoSpacingTokens.md, vertical = NanoSpacingTokens.xs)
            ) {
                // Text field
                TextField(
                    value = value,
                    onValueChange = { if (it.length <= characterLimit) onValueChange(it) },
                    placeholder = {
                        Text(
                            text = "Escribe un mensaje...",
                            style = NanoTypeTokens.body,
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                        )
                    },
                    textStyle = NanoTypeTokens.body.copy(color = MaterialTheme.colorScheme.onSurface),
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent
                    ),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                    keyboardActions = KeyboardActions(onSend = { if (hasContent && !isGenerating) onSend() }),
                    maxLines = 4,
                    modifier = Modifier
                        .weight(1f)
                        .semantics { contentDescription = "Barra de mensaje" }
                )

                // Voice button (placeholder)
                IconButton(
                    onClick = { /* TODO: voice input */ },
                    enabled = !isGenerating,
                    modifier = Modifier.size(40.dp)
                ) {
                    Icon(Icons.Default.Mic, "Voz", tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(20.dp))
                }

                Spacer(Modifier.width(NanoSpacingTokens.xs))

                // Send / Stop button
                if (isGenerating) {
                    IconButton(
                        onClick = onStop,
                        modifier = Modifier.size(40.dp)
                    ) {
                        Icon(Icons.Default.Close, "Detener", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(20.dp))
                    }
                } else {
                    IconButton(
                        onClick = onSend,
                        enabled = hasContent,
                        modifier = Modifier.size(40.dp)
                    ) {
                        Icon(
                            Icons.AutoMirrored.Filled.Send,
                            "Enviar",
                            tint = if (hasContent) MaterialTheme.colorScheme.primary
                                   else MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }
        }

        // Character count (shown when near limit)
        AnimatedVisibility(
            visible = isNearLimit,
            enter = fadeIn(tween(NanoAnimationTokens.DurationFastMs)),
            exit = fadeOut(tween(NanoAnimationTokens.DurationFastMs))
        ) {
            Text(
                text = "$charCount / $characterLimit",
                style = NanoTypeTokens.label,
                color = if (charCount >= characterLimit) MaterialTheme.colorScheme.error
                        else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = NanoSpacingTokens.lg, vertical = NanoSpacingTokens.xs)
            )
        }
    }
}
