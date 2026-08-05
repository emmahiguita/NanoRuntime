package com.nanoai.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.nanoai.ui.theme.*

/**
 * NanoButton Component (Sección 10 Specification Compliant)
 *
 * Enforces SOLID Principles:
 * - Single Responsibility: Standardized interactive button handling 5 design variants & state indications.
 * - Open/Closed: Extensible via leading/trailing icon slots, custom colors, and sizes.
 */

enum class NanoButtonVariant {
    PRIMARY,
    SECONDARY,
    TEXT,
    OUTLINED,
    DANGER
}

enum class NanoButtonSize(
    val height: Dp,
    val horizontalPadding: Dp,
    val iconSize: Dp
) {
    SMALL(36.dp, NanoSpacingTokens.md, 16.dp),
    MEDIUM(48.dp, NanoSpacingTokens.lg, 20.dp),
    LARGE(56.dp, NanoSpacingTokens.xl, 24.dp)
}

@Composable
fun NanoButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    variant: NanoButtonVariant = NanoButtonVariant.PRIMARY,
    size: NanoButtonSize = NanoButtonSize.MEDIUM,
    enabled: Boolean = true,
    isLoading: Boolean = false,
    leadingIcon: ImageVector? = null,
    trailingIcon: ImageVector? = null,
    enableHaptics: Boolean = true,
    contentDescriptionText: String? = null
) {
    val haptic = LocalHapticFeedback.current
    val interactionSource = remember { MutableInteractionSource() }

    val handleOnClick: () -> Unit = {
        if (enabled && !isLoading) {
            if (enableHaptics) {
                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
            }
            onClick()
        }
    }

    val containerColor = when (variant) {
        NanoButtonVariant.PRIMARY -> MaterialTheme.colorScheme.primary
        NanoButtonVariant.SECONDARY -> MaterialTheme.colorScheme.secondary
        NanoButtonVariant.DANGER -> MaterialTheme.colorScheme.error
        NanoButtonVariant.OUTLINED -> Color.Transparent
        NanoButtonVariant.TEXT -> Color.Transparent
    }

    val contentColor = when (variant) {
        NanoButtonVariant.PRIMARY -> MaterialTheme.colorScheme.background
        NanoButtonVariant.SECONDARY -> MaterialTheme.colorScheme.onSurface
        NanoButtonVariant.DANGER -> Color.White
        NanoButtonVariant.OUTLINED -> MaterialTheme.colorScheme.primary
        NanoButtonVariant.TEXT -> MaterialTheme.colorScheme.primary
    }

    val border = if (variant == NanoButtonVariant.OUTLINED) {
        BorderStroke(1.5.dp, if (enabled) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.38f))
    } else null

    Button(
        onClick = handleOnClick,
        enabled = enabled && !isLoading,
        modifier = modifier
            .height(size.height)
            .defaultMinSize(minWidth = 48.dp, minHeight = 48.dp)
            .semantics {
                contentDescription = contentDescriptionText ?: text
            },
        shape = NanoShapeTokens.medium,
        colors = ButtonDefaults.buttonColors(
            containerColor = containerColor,
            contentColor = contentColor,
            disabledContainerColor = containerColor.copy(alpha = 0.38f),
            disabledContentColor = contentColor.copy(alpha = 0.38f)
        ),
        border = border,
        contentPadding = PaddingValues(horizontal = size.horizontalPadding, vertical = 0.dp),
        interactionSource = interactionSource
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            if (isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(size.iconSize),
                    color = contentColor,
                    strokeWidth = 2.dp
                )
                Spacer(modifier = Modifier.width(NanoSpacingTokens.sm))
            } else {
                if (leadingIcon != null) {
                    Icon(
                        imageVector = leadingIcon,
                        contentDescription = null,
                        modifier = Modifier.size(size.iconSize),
                        tint = contentColor
                    )
                    Spacer(modifier = Modifier.width(NanoSpacingTokens.xs))
                }
            }

            Text(
                text = text,
                style = when (size) {
                    NanoButtonSize.SMALL -> NanoTypeTokens.caption
                    NanoButtonSize.MEDIUM -> NanoTypeTokens.body
                    NanoButtonSize.LARGE -> NanoTypeTokens.title
                },
                color = contentColor
            )

            if (!isLoading && trailingIcon != null) {
                Spacer(modifier = Modifier.width(NanoSpacingTokens.xs))
                Icon(
                    imageVector = trailingIcon,
                    contentDescription = null,
                    modifier = Modifier.size(size.iconSize),
                    tint = contentColor
                )
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
fun NanoButtonPreview() {
    NanoAITheme {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(NanoSpacingTokens.md),
            verticalArrangement = Arrangement.spacedBy(NanoSpacingTokens.sm)
        ) {
            NanoButton(text = "Primary Button", onClick = {})
            NanoButton(text = "Secondary Button", onClick = {}, variant = NanoButtonVariant.SECONDARY)
            NanoButton(text = "Danger Action", onClick = {}, variant = NanoButtonVariant.DANGER)
            NanoButton(text = "Outlined Button", onClick = {}, variant = NanoButtonVariant.OUTLINED)
            NanoButton(text = "Cargando...", onClick = {}, isLoading = true)
        }
    }
}
