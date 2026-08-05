package com.nanoai.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.nanoai.ui.theme.*

/**
 * NanoCard Component (Sección 10 Specification Compliant)
 *
 * Enforces SOLID Principles:
 * - Single Responsibility: Base card container providing surface styling, elevation, and optional glow/border.
 * - Open/Closed: Accepts custom content via Composable slot.
 */

enum class NanoElevation {
    NONE,
    LOW,
    MEDIUM,
    HIGH;

    val dp: Dp
        get() = when (this) {
            NONE -> 0.dp
            LOW -> 2.dp
            MEDIUM -> 4.dp
            HIGH -> 8.dp
        }
}

@Composable
fun NanoCard(
    modifier: Modifier = Modifier,
    elevation: NanoElevation = NanoElevation.LOW,
    containerColor: Color = MaterialTheme.colorScheme.surface,
    borderColor: Color? = MaterialTheme.colorScheme.outlineVariant,
    onClick: (() -> Unit)? = null,
    contentDescriptionText: String? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    val cardModifier = modifier.then(
        if (onClick != null) {
            Modifier.clickable(onClick = onClick)
        } else Modifier
    ).then(
        if (contentDescriptionText != null) {
            Modifier.semantics { contentDescription = contentDescriptionText }
        } else Modifier
    )

    Card(
        modifier = cardModifier,
        shape = NanoShapeTokens.medium,
        colors = CardDefaults.cardColors(
            containerColor = containerColor
        ),
        elevation = CardDefaults.cardElevation(
            defaultElevation = elevation.dp
        ),
        border = borderColor?.let { BorderStroke(1.dp, it) }
    ) {
        Column(
            modifier = Modifier.padding(NanoSpacingTokens.md),
            content = content
        )
    }
}

@Preview(showBackground = true)
@Composable
fun NanoCardPreview() {
    NanoAITheme {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(NanoSpacingTokens.md)
        ) {
            NanoCard(elevation = NanoElevation.MEDIUM) {
                Text(
                    text = "NanoCard Title",
                    style = NanoTypeTokens.title,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Spacer(modifier = Modifier.height(NanoSpacingTokens.xs))
                Text(
                    text = "Este es un contenedor modular estilizado según los design tokens de NanoAI.",
                    style = NanoTypeTokens.body,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}
