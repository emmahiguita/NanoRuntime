package com.nanoai.ui.navigation

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.nanoai.ui.theme.*

enum class NanoScreen(
    val route: String,
    val title: String,
    val icon: ImageVector
) {
    DASHBOARD("dashboard", "Dashboard", Icons.Default.Dashboard),
    CHAT("chat", "Chat", Icons.AutoMirrored.Filled.Chat),
    MODELS("models", "Modelos", Icons.Default.Extension),
    SETTINGS("settings", "Ajustes", Icons.Default.Settings)
}

/**
 * NanoScaffold — base layout con top bar y bottom navigation.
 * innerPadding se consume UNA sola vez en el NavHost. Sin doble padding.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NanoScaffold(
    currentScreen: NanoScreen,
    onNavigateTo: (NanoScreen) -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable (PaddingValues) -> Unit
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = currentScreen.title,
                        style = NanoTypeTokens.title,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                },
                actions = {
                    IconButton(onClick = { onNavigateTo(NanoScreen.SETTINGS) }) {
                        Icon(
                            imageVector = Icons.Default.Settings,
                            contentDescription = "Configuración",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        bottomBar = {
            NanoBottomNav(
                currentScreen = currentScreen,
                onNavigateTo = onNavigateTo
            )
        }
    ) { innerPadding ->
        // innerPadding incluye los insets de status bar, top bar, y navigation bar.
        // Se pasa directamente al contenido SIN padding adicional.
        content(innerPadding)
    }
}

/**
 * BottomNav con soporte de WindowInsets para navigation bar (gesture nav).
 */
@Composable
fun NanoBottomNav(
    currentScreen: NanoScreen,
    onNavigateTo: (NanoScreen) -> Unit,
    modifier: Modifier = Modifier
) {
    NavigationBar(
        modifier = modifier
            .fillMaxWidth()
            .semantics { contentDescription = "Navegación principal" },
        containerColor = MaterialTheme.colorScheme.surface,
        tonalElevation = 8.dp
    ) {
        NanoScreen.entries.forEach { screen ->
            NavigationBarItem(
                selected = screen == currentScreen,
                onClick = { onNavigateTo(screen) },
                icon = {
                    Icon(
                        imageVector = screen.icon,
                        contentDescription = screen.title,
                        tint = if (screen == currentScreen) MaterialTheme.colorScheme.primary
                               else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                },
                label = {
                    Text(
                        text = screen.title,
                        style = NanoTypeTokens.caption,
                        color = if (screen == currentScreen) MaterialTheme.colorScheme.primary
                                else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                },
                colors = NavigationBarItemDefaults.colors(
                    indicatorColor = MaterialTheme.colorScheme.primaryContainer
                )
            )
        }
    }
}
