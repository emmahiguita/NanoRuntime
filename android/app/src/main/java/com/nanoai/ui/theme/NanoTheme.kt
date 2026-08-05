package com.nanoai.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.graphics.Color

/* ================================================================
   NanoAI Material3 Design System — Dual Theme (Light + Dark)
   Complete darkColorScheme & lightColorScheme with all M3 roles.
   Theme mode: SYSTEM (auto), DARK, LIGHT.
   ================================================================ */

enum class NanoThemeMode { SYSTEM, DARK, LIGHT }

private val DarkScheme = darkColorScheme(
    primary = NanoDarkColors.Primary,
    onPrimary = NanoDarkColors.OnPrimary,
    primaryContainer = NanoDarkColors.PrimaryContainer,
    onPrimaryContainer = NanoDarkColors.OnPrimaryContainer,
    secondary = NanoDarkColors.Secondary,
    onSecondary = NanoDarkColors.OnPrimary,
    secondaryContainer = NanoDarkColors.SecondaryContainer,
    onSecondaryContainer = NanoDarkColors.OnSecondaryContainer,
    tertiary = NanoDarkColors.Tertiary,
    onTertiary = NanoDarkColors.OnPrimary,
    tertiaryContainer = NanoDarkColors.TertiaryContainer,
    onTertiaryContainer = NanoDarkColors.OnTertiaryContainer,
    error = NanoDarkColors.Error,
    onError = NanoDarkColors.OnPrimary,
    errorContainer = NanoDarkColors.ErrorContainer,
    onErrorContainer = NanoDarkColors.OnErrorContainer,
    background = NanoDarkColors.Background,
    onBackground = NanoDarkColors.OnSurface,
    surface = NanoDarkColors.Surface,
    onSurface = NanoDarkColors.OnSurface,
    surfaceVariant = NanoDarkColors.SurfaceVariant,
    onSurfaceVariant = NanoDarkColors.OnSurfaceVariant,
    surfaceDim = NanoDarkColors.SurfaceContainerLowest,
    surfaceBright = NanoDarkColors.SurfaceContainerHighest,
    surfaceContainerLowest = NanoDarkColors.SurfaceContainerLowest,
    surfaceContainerLow = NanoDarkColors.SurfaceContainerLow,
    surfaceContainer = NanoDarkColors.Surface,
    surfaceContainerHigh = NanoDarkColors.SurfaceContainerHigh,
    surfaceContainerHighest = NanoDarkColors.SurfaceContainerHighest,
    outline = NanoDarkColors.Outline,
    outlineVariant = NanoDarkColors.OutlineVariant,
    inverseSurface = NanoDarkColors.InverseSurface,
    inverseOnSurface = NanoDarkColors.InverseOnSurface,
    inversePrimary = NanoDarkColors.InversePrimary,
    scrim = NanoDarkColors.Scrim,
)

private val LightScheme = lightColorScheme(
    primary = NanoLightColors.Primary,
    onPrimary = NanoLightColors.OnPrimary,
    primaryContainer = NanoLightColors.PrimaryContainer,
    onPrimaryContainer = NanoLightColors.OnPrimaryContainer,
    secondary = NanoLightColors.Secondary,
    onSecondary = NanoLightColors.OnPrimary,
    secondaryContainer = NanoLightColors.SecondaryContainer,
    onSecondaryContainer = NanoLightColors.OnSecondaryContainer,
    tertiary = NanoLightColors.Tertiary,
    onTertiary = NanoLightColors.OnPrimary,
    tertiaryContainer = NanoLightColors.TertiaryContainer,
    onTertiaryContainer = NanoLightColors.OnTertiaryContainer,
    error = NanoLightColors.Error,
    onError = NanoLightColors.OnPrimary,
    errorContainer = NanoLightColors.ErrorContainer,
    onErrorContainer = NanoLightColors.OnErrorContainer,
    background = NanoLightColors.Background,
    onBackground = NanoLightColors.OnSurface,
    surface = NanoLightColors.Surface,
    onSurface = NanoLightColors.OnSurface,
    surfaceVariant = NanoLightColors.SurfaceVariant,
    onSurfaceVariant = NanoLightColors.OnSurfaceVariant,
    surfaceDim = NanoLightColors.SurfaceContainerLowest,
    surfaceBright = NanoLightColors.SurfaceContainerHighest,
    surfaceContainerLowest = NanoLightColors.SurfaceContainerLowest,
    surfaceContainerLow = NanoLightColors.SurfaceContainerLow,
    surfaceContainer = NanoLightColors.Surface,
    surfaceContainerHigh = NanoLightColors.SurfaceContainerHigh,
    surfaceContainerHighest = NanoLightColors.SurfaceContainerHighest,
    outline = NanoLightColors.Outline,
    outlineVariant = NanoLightColors.OutlineVariant,
    inverseSurface = NanoLightColors.InverseSurface,
    inverseOnSurface = NanoLightColors.InverseOnSurface,
    inversePrimary = NanoLightColors.InversePrimary,
    scrim = NanoLightColors.Scrim,
)

private val NanoTypography = Typography(
    displayLarge = NanoTypeTokens.displayLarge,
    headlineLarge = NanoTypeTokens.headlineLarge,
    headlineMedium = NanoTypeTokens.headlineMedium,
    titleLarge = NanoTypeTokens.titleLarge,
    titleMedium = NanoTypeTokens.title,
    titleSmall = NanoTypeTokens.subtitle,
    bodyLarge = NanoTypeTokens.body.copy(fontSize = NanoTypeTokens.body.fontSize),
    bodyMedium = NanoTypeTokens.body,
    bodySmall = NanoTypeTokens.caption,
    labelLarge = NanoTypeTokens.subtitle,
    labelMedium = NanoTypeTokens.caption,
    labelSmall = NanoTypeTokens.label,
)

private val NanoShapes = Shapes(
    extraSmall = NanoShapeTokens.extraSmall,
    small = NanoShapeTokens.small,
    medium = NanoShapeTokens.medium,
    large = NanoShapeTokens.large,
    extraLarge = NanoShapeTokens.extraLarge,
)

/* ── Theme state — persisted via SettingsViewModel ── */
val LocalThemeMode = compositionLocalOf { NanoThemeMode.SYSTEM }
val LocalNanoColors = compositionLocalOf<NanoColors> { NanoDarkColors }

@Composable
fun NanoAITheme(
    themeMode: NanoThemeMode = NanoThemeMode.SYSTEM,
    content: @Composable () -> Unit,
) {
    val systemDark = isSystemInDarkTheme()
    val isDark = when (themeMode) {
        NanoThemeMode.SYSTEM -> systemDark
        NanoThemeMode.DARK   -> true
        NanoThemeMode.LIGHT  -> false
    }

    val scheme = if (isDark) DarkScheme else LightScheme
    val semanticColors = if (isDark) NanoDarkColors else NanoLightColors

    CompositionLocalProvider(
        LocalThemeMode provides themeMode,
        LocalNanoColors provides semanticColors,
    ) {
        MaterialTheme(
            colorScheme = scheme,
            typography = NanoTypography,
            shapes = NanoShapes,
            content = content,
        )
    }
}

/* ── Helper: access current semantic colors from any composable ── */
@Composable
fun nanoColors() = LocalNanoColors.current
