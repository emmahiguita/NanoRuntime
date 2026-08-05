package com.nanoai.ui.theme

import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/* ================================================================
   NanoAI — Complete Light + Dark Design Token System
   Material3 compliant. Semantic tokens for both themes via
   the NanoColors interface.
   ================================================================ */

interface NanoColors {
    val Primary: Color; val PrimaryVariant: Color; val PrimaryContainer: Color
    val OnPrimary: Color; val OnPrimaryContainer: Color
    val Secondary: Color; val SecondaryContainer: Color; val OnSecondaryContainer: Color
    val StatusSuccess: Color; val StatusWarning: Color; val StatusError: Color; val StatusInfo: Color
    val TerminalBackground: Color; val TerminalGreen: Color; val Divider: Color
}

// ── Dark ──
object NanoDarkColors : NanoColors {
    override val Primary = Color(0xFF00E676)
    override val PrimaryVariant = Color(0xFF00C853)
    override val PrimaryContainer = Color(0xFF0A3D1F)
    override val OnPrimary = Color(0xFF07090E)
    override val OnPrimaryContainer = Color(0xFFB9F6CA)
    override val Secondary = Color(0xFF38BDF8)
    override val SecondaryContainer = Color(0xFF0C2D48)
    override val OnSecondaryContainer = Color(0xFFBAE6FD)
    val Tertiary = Color(0xFFC084FC); val TertiaryContainer = Color(0xFF2D1060); val OnTertiaryContainer = Color(0xFFE9D5FF)
    val Error = Color(0xFFEF4444); val ErrorContainer = Color(0xFF4C0519); val OnErrorContainer = Color(0xFFFECACA)
    val Background = Color(0xFF07090E); val Surface = Color(0xFF0F172A); val SurfaceVariant = Color(0xFF1E293B)
    val SurfaceContainerLowest = Color(0xFF040611); val SurfaceContainerLow = Color(0xFF0A0F1A)
    val SurfaceContainerHigh = Color(0xFF1A2236); val SurfaceContainerHighest = Color(0xFF2A3246)
    val OnSurface = Color(0xFFF8FAFC); val OnSurfaceVariant = Color(0xFF94A3B8)
    val Outline = Color(0xFF475569); val OutlineVariant = Color(0xFF1E293B)
    val InverseSurface = Color(0xFFF8FAFC); val InverseOnSurface = Color(0xFF07090E); val InversePrimary = Color(0xFF00C853)
    val Scrim = Color(0x9907090E)
    override val StatusSuccess = Color(0xFF00E676)
    override val StatusWarning = Color(0xFFF59E0B)
    override val StatusError = Color(0xFFEF4444)
    override val StatusInfo = Color(0xFF38BDF8)
    override val TerminalBackground = Color(0xFF050810)
    override val TerminalGreen = Color(0xFF00E676)
    override val Divider = SurfaceVariant
}

// ── Light ──
object NanoLightColors : NanoColors {
    override val Primary = Color(0xFF008F39)
    override val PrimaryVariant = Color(0xFF00C853)
    override val PrimaryContainer = Color(0xFFB9F6CA)
    override val OnPrimary = Color(0xFFFFFFFF)
    override val OnPrimaryContainer = Color(0xFF002106)
    override val Secondary = Color(0xFF0284C7)
    override val SecondaryContainer = Color(0xFFBAE6FD)
    override val OnSecondaryContainer = Color(0xFF001E2E)
    val Tertiary = Color(0xFF7C3AED); val TertiaryContainer = Color(0xFFE9D5FF); val OnTertiaryContainer = Color(0xFF2D1060)
    val Error = Color(0xFFDC2626); val ErrorContainer = Color(0xFFFECACA); val OnErrorContainer = Color(0xFF4C0519)
    val Background = Color(0xFFF8FAFC); val Surface = Color(0xFFFFFFFF); val SurfaceVariant = Color(0xFFF1F5F9)
    val SurfaceContainerLowest = Color(0xFFF1F5F9); val SurfaceContainerLow = Color(0xFFE2E8F0)
    val SurfaceContainerHigh = Color(0xFFCBD5E1); val SurfaceContainerHighest = Color(0xFF94A3B8)
    val OnSurface = Color(0xFF0F172A); val OnSurfaceVariant = Color(0xFF475569)
    val Outline = Color(0xFF94A3B8); val OutlineVariant = Color(0xFFCBD5E1)
    val InverseSurface = Color(0xFF0F172A); val InverseOnSurface = Color(0xFFF8FAFC); val InversePrimary = Color(0xFF00E676)
    val Scrim = Color(0x99000000)
    override val StatusSuccess = Color(0xFF16A34A)
    override val StatusWarning = Color(0xFFD97706)
    override val StatusError = Color(0xFFDC2626)
    override val StatusInfo = Color(0xFF0284C7)
    override val TerminalBackground = Color(0xFFF1F5F9)
    override val TerminalGreen = Color(0xFF008F39)
    override val Divider = Color(0xFFE2E8F0)
}

// ── Typography ──
object NanoTypeTokens {
    val displayLarge = TextStyle(fontWeight = FontWeight.Bold, fontSize = 32.sp, lineHeight = 40.sp)
    val headlineLarge = TextStyle(fontWeight = FontWeight.Bold, fontSize = 28.sp, lineHeight = 36.sp)
    val headlineMedium = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 24.sp, lineHeight = 32.sp)
    val titleLarge = TextStyle(fontWeight = FontWeight.Bold, fontSize = 20.sp, lineHeight = 28.sp)
    val title = TextStyle(fontWeight = FontWeight.Bold, fontSize = 18.sp, lineHeight = 26.sp, letterSpacing = 0.15.sp)
    val subtitle = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 15.sp, lineHeight = 22.sp, letterSpacing = 0.1.sp)
    val body = TextStyle(fontWeight = FontWeight.Normal, fontSize = 14.sp, lineHeight = 20.sp, letterSpacing = 0.25.sp)
    val caption = TextStyle(fontWeight = FontWeight.Medium, fontSize = 11.sp, lineHeight = 15.sp, letterSpacing = 0.4.sp)
    val label = TextStyle(fontWeight = FontWeight.Medium, fontSize = 10.sp, lineHeight = 14.sp, letterSpacing = 0.5.sp)
    val monospace = TextStyle(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Normal, fontSize = 12.sp, lineHeight = 17.sp)
}

// ── Shapes ──
object NanoShapeTokens {
    val extraSmall = RoundedCornerShape(4.dp); val small = RoundedCornerShape(6.dp)
    val medium = RoundedCornerShape(10.dp); val large = RoundedCornerShape(14.dp)
    val extraLarge = RoundedCornerShape(20.dp); val full = RoundedCornerShape(50)
    val userBubble = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp, bottomStart = 16.dp, bottomEnd = 4.dp)
    val aiBubble = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp, bottomStart = 4.dp, bottomEnd = 16.dp)
}

// ── Spacing (8dp grid) ──
object NanoSpacingTokens {
    val xs: Dp = 4.dp; val sm: Dp = 8.dp; val md: Dp = 12.dp
    val lg: Dp = 16.dp; val xl: Dp = 24.dp; val xxl: Dp = 32.dp; val xxxl: Dp = 48.dp
    val statCardHeight: Dp = 100.dp; val minTouchTarget: Dp = 44.dp
    val iconSize: Dp = 24.dp; val iconSmall: Dp = 18.dp
}

// ── Animation ──
object NanoAnimationTokens {
    const val DurationFastMs = 150; const val DurationNormalMs = 250; const val DurationSlowMs = 400
    const val StaggerDelayMs = 50; const val CardStaggerDelayMs = 80; const val ShimmerDurationMs = 900
    val DefaultEasing: Easing = FastOutSlowInEasing
    val DefaultSpring = spring<Float>(dampingRatio = Spring.DampingRatioLowBouncy, stiffness = Spring.StiffnessLow)
}
