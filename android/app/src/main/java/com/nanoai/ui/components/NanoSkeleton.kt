package com.nanoai.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.nanoai.ui.theme.*

/**
 * NanoSkeleton — shimmer placeholders for loading states.
 * Used during data fetch transitions.
 */
fun Modifier.nanoShimmer(shape: Shape = NanoShapeTokens.medium): Modifier = composed {
    val transition = rememberInfiniteTransition(label = "shimmer")
    val translateAnim = transition.animateFloat(
        initialValue = 0f,
        targetValue = 1000f,
        animationSpec = infiniteRepeatable(
            animation = tween(NanoAnimationTokens.ShimmerDurationMs, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "shimmerTranslate"
    )
    val shimmerColors = listOf(
        MaterialTheme.colorScheme.surface,
        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
        MaterialTheme.colorScheme.surface
    )
    val brush = Brush.linearGradient(
        colors = shimmerColors,
        start = Offset(translateAnim.value - 200f, translateAnim.value - 200f),
        end = Offset(translateAnim.value, translateAnim.value)
    )
    this.clip(shape).background(brush)
}

@Composable
fun StatCardSkeleton(modifier: Modifier = Modifier, height: Dp = 110.dp) {
    NanoCard(modifier = modifier.fillMaxWidth().height(height), borderColor = null) {
        Column(verticalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxSize()) {
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Box(Modifier.size(80.dp, 14.dp).nanoShimmer())
                Box(Modifier.size(24.dp).nanoShimmer(CircleShape))
            }
            Box(Modifier.size(100.dp, 24.dp).nanoShimmer())
            Box(Modifier.fillMaxWidth().height(4.dp).nanoShimmer())
        }
    }
}

@Composable
fun ModelCardSkeleton(modifier: Modifier = Modifier) {
    NanoCard(modifier = modifier.fillMaxWidth().height(140.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(NanoSpacingTokens.sm)) {
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Box(Modifier.size(120.dp, 18.dp).nanoShimmer())
                Box(Modifier.size(50.dp, 18.dp).nanoShimmer())
            }
            Box(Modifier.size(180.dp, 12.dp).nanoShimmer())
            Spacer(Modifier.weight(1f))
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Box(Modifier.size(70.dp, 32.dp).nanoShimmer())
                Box(Modifier.size(90.dp, 32.dp).nanoShimmer())
            }
        }
    }
}

@Composable
fun ChatBubbleSkeleton(isUser: Boolean = false, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start
    ) {
        Box(Modifier.fillMaxWidth(0.7f).height(56.dp).nanoShimmer(RoundedCornerShape(14.dp)))
    }
}

@Preview(showBackground = true)
@Composable
fun NanoSkeletonPreview() {
    NanoAITheme {
        Column(
            modifier = Modifier.fillMaxWidth().padding(NanoSpacingTokens.md),
            verticalArrangement = Arrangement.spacedBy(NanoSpacingTokens.md)
        ) {
            StatCardSkeleton()
            ModelCardSkeleton()
            ChatBubbleSkeleton(isUser = false)
            ChatBubbleSkeleton(isUser = true)
        }
    }
}
