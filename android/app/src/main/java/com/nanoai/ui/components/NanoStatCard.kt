package com.nanoai.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.nanoai.ui.theme.*
import com.nanoai.ui.theme.nanoColors
import kotlinx.coroutines.delay

/**
 * NanoStatCard Component (Sección 2 - Specification Compliant)
 *
 * Enforces SOLID Principles:
 * - Single Responsibility: Displays stat value, progress, and trend metric strictly.
 * - Open/Closed: Accepts custom icons, status tint, and onClick callbacks via slots.
 * - Interface Segregation: Takes strongly typed primitives & models instead of complex monolithic objects.
 */

enum class StatType {
    INFO, WARNING, PRIMARY, SECONDARY, ERROR
}

enum class TrendDirection {
    UP, DOWN, NEUTRAL
}

data class TrendInfo(
    val percentage: String,
    val direction: TrendDirection,
    val isPositive: Boolean = direction == TrendDirection.DOWN // Down is good for RAM/Thermal
)

@Composable
fun NanoStatCard(
    title: String,
    value: String,
    unit: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    statType: StatType = StatType.PRIMARY,
    progress: Float? = null,
    trend: TrendInfo? = null,
    animationDelayMs: Int = 0,
    onClick: (() -> Unit)? = null
) {
    var isVisible by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        if (animationDelayMs > 0) {
            delay(animationDelayMs.toLong())
        }
        isVisible = true
    }

    val animatedProgress by animateFloatAsState(
        targetValue = progress ?: 0f,
        animationSpec = tween(durationMillis = NanoAnimationTokens.DurationNormalMs),
        label = "StatCardProgress"
    )

    val iconColor = when (statType) {
        StatType.PRIMARY -> MaterialTheme.colorScheme.primary
        StatType.SECONDARY -> MaterialTheme.colorScheme.secondary
        StatType.WARNING -> nanoColors().StatusWarning
        StatType.ERROR -> MaterialTheme.colorScheme.error
        StatType.INFO -> nanoColors().StatusInfo
    }

    AnimatedVisibility(
        visible = isVisible,
        enter = scaleIn(
            initialScale = 0.9f,
            animationSpec = tween(
                durationMillis = NanoAnimationTokens.DurationFastMs,
                easing = NanoAnimationTokens.DefaultEasing
            )
        ) + fadeIn(
            animationSpec = tween(durationMillis = NanoAnimationTokens.DurationFastMs)
        )
    ) {
        Card(
            modifier = modifier
                .heightIn(min = NanoSpacingTokens.statCardHeight)
                .fillMaxWidth()
                .semantics {
                    contentDescription = "$title: $value $unit"
                }
                .then(
                    if (onClick != null) Modifier.clickable { onClick() } else Modifier
                ),
            shape = NanoShapeTokens.medium,
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surface
            ),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(NanoSpacingTokens.md),
                verticalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.sm)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(32.dp)
                                .clip(CircleShape)
                                .background(iconColor.copy(alpha = 0.15f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = icon,
                                contentDescription = null,
                                tint = iconColor,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                        Text(
                            text = title,
                            style = NanoTypeTokens.caption,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }

                    if (trend != null) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(2.dp)
                        ) {
                            val trendColor = if (trend.isPositive) nanoColors().StatusSuccess else MaterialTheme.colorScheme.error
                            val trendIcon = if (trend.direction == TrendDirection.UP) Icons.Default.ArrowUpward else Icons.Default.ArrowDownward
                            
                            Icon(
                                imageVector = trendIcon,
                                contentDescription = null,
                                tint = trendColor,
                                modifier = Modifier.size(12.dp)
                            )
                            Text(
                                text = trend.percentage,
                                style = NanoTypeTokens.caption,
                                color = trendColor
                            )
                        }
                    }
                }

                Row(
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.xs)
                ) {
                    Text(
                        text = value,
                        style = NanoTypeTokens.title,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = unit,
                        style = NanoTypeTokens.body,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(bottom = 2.dp)
                    )
                }

                if (progress != null) {
                    LinearProgressIndicator(
                        progress = { animatedProgress },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(4.dp)
                            .clip(NanoShapeTokens.small),
                        color = iconColor,
                        trackColor = MaterialTheme.colorScheme.surfaceVariant
                    )
                }
            }
        }
    }
}

@Preview
@Composable
fun NanoStatCardPreview() {
    NanoAITheme {
        NanoStatCard(
            title = "Uso de RAM",
            value = "2.8",
            unit = "GB / 3.7 GB",
            icon = androidx.compose.material.icons.Icons.Default.ArrowUpward,
            statType = StatType.WARNING,
            progress = 0.75f,
            trend = TrendInfo(percentage = "-4%", direction = TrendDirection.DOWN, isPositive = true)
        )
    }
}
