package com.nanoai.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.nanoai.ui.theme.*
import com.nanoai.ui.theme.nanoColors

/**
 * NanoBadge & QuantBadge Components (Secciones 3 & 10 Specification Compliant)
 *
 * Enforces SOLID Principles:
 * - Single Responsibility: Displays compact status indicators, quant labels, and metadata pills.
 */

enum class BadgeStatus {
    SUCCESS,
    WARNING,
    ERROR,
    INFO,
    NEUTRAL,
    PRIMARY
}

@Composable
fun NanoBadge(
    text: String,
    modifier: Modifier = Modifier,
    status: BadgeStatus = BadgeStatus.PRIMARY,
    showDot: Boolean = false,
    contentDescriptionText: String? = null
) {
    val (backgroundColor, textColor, borderColor) = when (status) {
        BadgeStatus.SUCCESS -> Triple(
            nanoColors().StatusSuccess.copy(alpha = 0.15f),
            nanoColors().StatusSuccess,
            nanoColors().StatusSuccess.copy(alpha = 0.4f)
        )
        BadgeStatus.WARNING -> Triple(
            nanoColors().StatusWarning.copy(alpha = 0.15f),
            nanoColors().StatusWarning,
            nanoColors().StatusWarning.copy(alpha = 0.4f)
        )
        BadgeStatus.ERROR -> Triple(
            MaterialTheme.colorScheme.error.copy(alpha = 0.15f),
            MaterialTheme.colorScheme.error,
            MaterialTheme.colorScheme.error.copy(alpha = 0.4f)
        )
        BadgeStatus.INFO -> Triple(
            nanoColors().StatusInfo.copy(alpha = 0.15f),
            nanoColors().StatusInfo,
            nanoColors().StatusInfo.copy(alpha = 0.4f)
        )
        BadgeStatus.PRIMARY -> Triple(
            MaterialTheme.colorScheme.primaryContainer,
            MaterialTheme.colorScheme.primary,
            MaterialTheme.colorScheme.primary.copy(alpha = 0.4f)
        )
        BadgeStatus.NEUTRAL -> Triple(
            MaterialTheme.colorScheme.outlineVariant,
            MaterialTheme.colorScheme.onSurfaceVariant,
            MaterialTheme.colorScheme.outlineVariant
        )
    }

    Row(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .background(backgroundColor)
            .border(1.dp, borderColor, RoundedCornerShape(8.dp))
            .padding(horizontal = NanoSpacingTokens.xs, vertical = 2.dp)
            .semantics { contentDescription = contentDescriptionText ?: text },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        if (showDot) {
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .clip(CircleShape)
                    .background(textColor)
            )
            Spacer(modifier = Modifier.width(NanoSpacingTokens.xs))
        }

        Text(
            text = text,
            style = NanoTypeTokens.caption,
            color = textColor
        )
    }
}

/**
 * QuantBadge specifically tailored for LLM quantization representations (e.g., Q4_K_M, FP16)
 */
@Composable
fun QuantBadge(
    quant: String,
    modifier: Modifier = Modifier
) {
    val status = when {
        quant.contains("FP16", ignoreCase = true) || quant.contains("Q8", ignoreCase = true) -> BadgeStatus.INFO
        quant.contains("Q4", ignoreCase = true) -> BadgeStatus.SUCCESS
        quant.contains("IQ", ignoreCase = true) || quant.contains("Q2", ignoreCase = true) -> BadgeStatus.WARNING
        else -> BadgeStatus.PRIMARY
    }

    NanoBadge(
        text = quant,
        modifier = modifier,
        status = status,
        showDot = false,
        contentDescriptionText = "Cuantización $quant"
    )
}

@Preview(showBackground = true)
@Composable
fun NanoBadgePreview() {
    NanoAITheme {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(NanoSpacingTokens.md),
            horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.xs)
        ) {
            NanoBadge(text = "Cargado", status = BadgeStatus.SUCCESS, showDot = true)
            QuantBadge(quant = "Q4_K_M")
            QuantBadge(quant = "FP16")
            NanoBadge(text = "Error RAM", status = BadgeStatus.ERROR)
        }
    }
}
