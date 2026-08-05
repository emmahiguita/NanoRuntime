package com.nanoai.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.nanoai.ui.theme.*

/**
 * NanoGraph Component (Sección 6 Specification Compliant)
 * Custom smooth real-time bezier curve graph with gradient area fill.
 *
 * SOLID Principles:
 * - Single Responsibility: Exclusively renders numeric series onto Canvas.
 * - Open/Closed: Accepts custom line colors, height, and unit labels.
 */
@Composable
fun NanoGraph(
    title: String,
    dataPoints: List<Float>,
    modifier: Modifier = Modifier,
    lineColor: Color = MaterialTheme.colorScheme.primary,
    unitLabel: String = "",
    maxValue: Float = (dataPoints.maxOrNull() ?: 100f) * 1.2f
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .semantics { contentDescription = "Gráfico en tiempo real de $title" },
        shape = NanoShapeTokens.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(NanoSpacingTokens.lg)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = title,
                    style = NanoTypeTokens.subtitle,
                    color = MaterialTheme.colorScheme.onSurface
                )
                if (dataPoints.isNotEmpty()) {
                    Text(
                        text = "${dataPoints.last()} $unitLabel",
                        style = NanoTypeTokens.title,
                        color = lineColor
                    )
                }
            }

            Spacer(modifier = Modifier.height(NanoSpacingTokens.md))

            if (dataPoints.size < 2) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(140.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "Recopilando métricas...",
                        style = NanoTypeTokens.body,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                Canvas(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(140.dp)
                ) {
                    val width = size.width
                    val height = size.height
                    val spacing = width / (dataPoints.size - 1)

                    val strokePath = Path()
                    val fillPath = Path()

                    val points = dataPoints.mapIndexed { index, value ->
                        val x = index * spacing
                        val y = height - (value / maxValue.coerceAtLeast(1f)) * height
                        Offset(x, y)
                    }

                    if (points.isNotEmpty()) {
                        strokePath.moveTo(points.first().x, points.first().y)
                        fillPath.moveTo(points.first().x, height)
                        fillPath.lineTo(points.first().x, points.first().y)

                        for (i in 0 until points.size - 1) {
                            val p1 = points[i]
                            val p2 = points[i + 1]
                            val controlPoint1 = Offset(p1.x + spacing / 2, p1.y)
                            val controlPoint2 = Offset(p1.x + spacing / 2, p2.y)

                            strokePath.cubicTo(
                                controlPoint1.x, controlPoint1.y,
                                controlPoint2.x, controlPoint2.y,
                                p2.x, p2.y
                            )
                            fillPath.cubicTo(
                                controlPoint1.x, controlPoint1.y,
                                controlPoint2.x, controlPoint2.y,
                                p2.x, p2.y
                            )
                        }

                        fillPath.lineTo(points.last().x, height)
                        fillPath.close()

                        // Draw Gradient Fill
                        drawPath(
                            path = fillPath,
                            brush = Brush.verticalGradient(
                                colors = listOf(
                                    lineColor.copy(alpha = 0.35f),
                                    lineColor.copy(alpha = 0.0f)
                                )
                            )
                        )

                        // Draw Line Path
                        drawPath(
                            path = strokePath,
                            color = lineColor,
                            style = Stroke(width = 3.dp.toPx())
                        )

                        // Draw latest point glow
                        val lastPoint = points.last()
                        drawCircle(
                            color = lineColor,
                            radius = 5.dp.toPx(),
                            center = lastPoint
                        )
                        drawCircle(
                            color = Color.White,
                            radius = 2.dp.toPx(),
                            center = lastPoint
                        )
                    }
                }
            }
        }
    }
}

@Preview
@Composable
fun NanoGraphPreview() {
    NanoAITheme {
        NanoGraph(
            title = "RSS Memory Variance (MB)",
            dataPoints = listOf(1120f, 1122f, 1121f, 1120.5f, 1121.2f, 1120.8f, 1121.0f),
            unitLabel = "MB"
        )
    }
}
