package com.nanoai.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.nanoai.ui.theme.*

/**
 * NanoErrorState Component (Sección 9 Specification Compliant)
 *
 * Enforces SOLID Principles:
 * - Single Responsibility: Displays standardized error screens with error codes, expandable stacktraces, and retry action.
 */

@Composable
fun NanoErrorState(
    errorMessage: String,
    modifier: Modifier = Modifier,
    errorCode: String? = null,
    technicalDetails: String? = null,
    onRetry: (() -> Unit)? = null
) {
    var isDetailsExpanded by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(NanoSpacingTokens.xl)
            .semantics { contentDescription = "Error: $errorMessage" },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.ErrorOutline,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = MaterialTheme.colorScheme.error
        )

        Spacer(modifier = Modifier.height(NanoSpacingTokens.md))

        if (errorCode != null) {
            NanoBadge(
                text = errorCode,
                status = BadgeStatus.ERROR,
                showDot = false
            )
            Spacer(modifier = Modifier.height(NanoSpacingTokens.xs))
        }

        Text(
            text = "Ha ocurrido un error",
            style = NanoTypeTokens.title,
            color = MaterialTheme.colorScheme.onSurface,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(NanoSpacingTokens.xs))

        Text(
            text = errorMessage,
            style = NanoTypeTokens.body,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )

        if (technicalDetails != null) {
            Spacer(modifier = Modifier.height(NanoSpacingTokens.md))

            Row(
                modifier = Modifier
                    .clickable { isDetailsExpanded = !isDetailsExpanded }
                    .padding(NanoSpacingTokens.xs),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = if (isDetailsExpanded) "Ocultar diagnóstico técnico" else "Ver diagnóstico técnico",
                    style = NanoTypeTokens.caption,
                    color = MaterialTheme.colorScheme.primary
                )
                Icon(
                    imageVector = if (isDetailsExpanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(16.dp)
                )
            }

            AnimatedVisibility(
                visible = isDetailsExpanded,
                enter = expandVertically(),
                exit = shrinkVertically()
            ) {
                NanoCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = NanoSpacingTokens.xs),
                    containerColor = MaterialTheme.colorScheme.background,
                    borderColor = MaterialTheme.colorScheme.error.copy(alpha = 0.3f)
                ) {
                    Text(
                        text = technicalDetails,
                        style = NanoTypeTokens.caption.copy(fontFamily = FontFamily.Monospace),
                        color = MaterialTheme.colorScheme.error
                    )
                }
            }
        }

        if (onRetry != null) {
            Spacer(modifier = Modifier.height(NanoSpacingTokens.lg))

            NanoButton(
                text = "Reintentar",
                onClick = onRetry,
                variant = NanoButtonVariant.PRIMARY,
                leadingIcon = Icons.Default.Refresh
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
fun NanoErrorStatePreview() {
    NanoAITheme {
        Box(modifier = Modifier.fillMaxSize()) {
            NanoErrorState(
                errorMessage = "Memoria RAM insuficiente para cargar el modelo Qwen2.5-7B FP16.",
                errorCode = "ERR_RAM_OOM_3860MB",
                technicalDetails = "std::bad_alloc at llama_model_load(): required=7200MB, available=3860MB",
                onRetry = {}
            )
        }
    }
}
