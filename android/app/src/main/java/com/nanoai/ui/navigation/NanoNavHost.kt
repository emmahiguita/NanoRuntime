package com.nanoai.ui.navigation

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.nanoai.ui.presentation.chat.ChatScreen
import com.nanoai.ui.presentation.chat.ChatViewModel
import com.nanoai.ui.presentation.dashboard.DashboardScreen
import com.nanoai.ui.presentation.dashboard.DashboardViewModel
import com.nanoai.ui.presentation.models.ModelsScreen
import com.nanoai.ui.presentation.models.ModelsViewModel
import com.nanoai.ui.presentation.settings.SettingsScreen
import com.nanoai.ui.presentation.settings.SettingsViewModel
import com.nanoai.ui.theme.NanoAnimationTokens

/**
 * Main Navigation Router.
 * innerPadding del Scaffold se aplica UNA SOLA VEZ aquí, envuelve todo el Crossfade.
 * Las screens individuales NO agregan padding top/bottom propio.
 */
@Composable
fun NanoNavHost(
    modifier: Modifier = Modifier,
    initialScreen: NanoScreen = NanoScreen.DASHBOARD
) {
    var currentScreen by remember { mutableStateOf(initialScreen) }

    val dashboardViewModel: DashboardViewModel = viewModel()
    val chatViewModel: ChatViewModel = viewModel()
    val modelsViewModel: ModelsViewModel = viewModel()
    val settingsViewModel: SettingsViewModel = viewModel()

    NanoScaffold(
        currentScreen = currentScreen,
        onNavigateTo = { screen -> currentScreen = screen },
        modifier = modifier
    ) { innerPadding ->
        // innerPadding se aplica aquí UNA vez. Las screens reciben Modifier sin padding extra.
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            Crossfade(
                targetState = currentScreen,
                animationSpec = tween(durationMillis = NanoAnimationTokens.DurationFastMs),
                label = "ScreenTransitionCrossfade"
            ) { screen ->
                when (screen) {
                    NanoScreen.DASHBOARD -> DashboardScreen(viewModel = dashboardViewModel)
                    NanoScreen.CHAT -> ChatScreen(viewModel = chatViewModel)
                    NanoScreen.MODELS -> ModelsScreen(viewModel = modelsViewModel)
                    NanoScreen.SETTINGS -> SettingsScreen(viewModel = settingsViewModel)
                }
            }
        }
    }
}
