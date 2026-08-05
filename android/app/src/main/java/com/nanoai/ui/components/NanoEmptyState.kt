package com.nanoai.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.nanoai.ui.theme.*

/**
 * NanoEmptyState Component (Sección 9 Specification Compliant)
 *
 * Enforces SOLID Principles:
 * - Single Responsibility: Displays contextual empty state messaging with illustrative icon & action button.
 */

@Composable
fun NanoEmptyState(
    title: String,
    description: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    actionText: String? = null,
    onActionClick: (() -> Unit)? = null
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(NanoSpacingTokens.xl)
            .semantics { contentDescription = "Estado vacío: $title" },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
        )

        Spacer(modifier = Modifier.height(NanoSpacingTokens.md))

        Text(
            text = title,
            style = NanoTypeTokens.title,
            color = MaterialTheme.colorScheme.onSurface,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(NanoSpacingTokens.xs))

        Text(
            text = description,
            style = NanoTypeTokens.body,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )

        if (actionText != null && onActionClick != null) {
            Spacer(modifier = Modifier.height(NanoSpacingTokens.lg))

            NanoButton(
                text = actionText,
                onClick = onActionClick,
                variant = NanoButtonVariant.SECONDARY,
                size = NanoButtonSize.MEDIUM
            )
        }
    }
}

// Contextual Helper Composables
@Composable
fun EmptyChatState(onStartChat: () -> Unit) {
    NanoEmptyState(
        title = "Sin Conversaciones Activas",
        description = "Empieza a chatear con los modelos LLM locales optimizados sin depender de conexión a internet.",
        icon = Icons.AutoMirrored.Filled.Chat,
        actionText = "Nuevo Chat",
        onActionClick = onStartChat
    )
}

@Composable
fun EmptyModelsState(onClearSearch: () -> Unit) {
    NanoEmptyState(
        title = "No se encontraron modelos",
        description = "Intenta ajustar el filtro de búsqueda o el tipo de cuantización.",
        icon = Icons.Default.ExtensionOff,
        actionText = "Limpiar Filtros",
        onActionClick = onClearSearch
    )
}

@Composable
fun EmptyTerminalLogsState() {
    NanoEmptyState(
        title = "Consola Limpia",
        description = "No hay registros o comandos ejecutados recientemente en el runtime NanoAI.",
        icon = Icons.Default.Terminal
    )
}

@Preview(showBackground = true)
@Composable
fun NanoEmptyStatePreview() {
    NanoAITheme {
        Box(modifier = Modifier.fillMaxSize()) {
            EmptyChatState(onStartChat = {})
        }
    }
}
