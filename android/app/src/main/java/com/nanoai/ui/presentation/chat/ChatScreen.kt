package com.nanoai.ui.presentation.chat

import androidx.compose.animation.*
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp
import com.nanoai.ui.components.*
import com.nanoai.ui.theme.*
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

@Composable
fun ChatScreen(
    viewModel: ChatViewModel,
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsState()
    ChatContent(state = state, onAction = viewModel::onAction, modifier = modifier)
}

@Composable
fun ChatContent(
    state: ChatUiState,
    onAction: (ChatUiAction) -> Unit,
    modifier: Modifier = Modifier
) {
    val listState = rememberLazyListState()
    val coroutineScope = rememberCoroutineScope()
    val clipboardManager = LocalClipboardManager.current
    val showScrollFab by remember {
        derivedStateOf { listState.firstVisibleItemIndex > 2 }
    }

    // Auto-scroll on new messages
    LaunchedEffect(state.messages.size) {
        if (state.messages.isNotEmpty()) {
            coroutineScope.launch { listState.animateScrollToItem(state.messages.size - 1) }
        }
    }

    Box(modifier = modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            // ── Model Selector Header ──
            ModelSelectorHeader(
                modelName = state.activeModelName,
                connectionState = state.connectionState,
                isExpanded = state.showModelSelector,
                availableModels = state.availableModels,
                onToggle = { onAction(ChatUiAction.ToggleModelSelector) },
                onModelSelected = { onAction(ChatUiAction.SelectModel(it)) }
            )

            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)

            // ── Messages Area ──
            if (state.messages.size <= 1 && !state.isGenerating) {
                // Empty state with quick suggestions
                EmptyChatWithSuggestions(
                    connectionState = state.connectionState,
                    suggestions = state.quickSuggestions,
                    onSuggestionClick = { onAction(ChatUiAction.QuickSuggestion(it)) },
                    modifier = Modifier.weight(1f)
                )
            } else {
                // Build flat list with date separators
                val displayItems = remember(state.messages) {
                    buildList<Any> {
                        state.messages.forEachIndexed { index, message ->
                            if (index == 0 || formatDate(state.messages[index - 1].timestamp) != formatDate(message.timestamp)) {
                                add("date_${formatDate(message.timestamp)}" to formatDate(message.timestamp))
                            }
                            add(message)
                        }
                    }
                }

                LazyColumn(
                    state = listState,
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    contentPadding = PaddingValues(horizontal = NanoSpacingTokens.lg, vertical = NanoSpacingTokens.sm),
                    verticalArrangement = Arrangement.spacedBy(NanoSpacingTokens.xs)
                ) {
                    items(displayItems.size, key = { index ->
                        val item = displayItems[index]
                        when (item) {
                            is ChatMessage -> item.id
                            is Pair<*, *> -> "date_${item.second}"
                            else -> index.toString()
                        }
                    }) { index ->
                        when (val item = displayItems[index]) {
                            is Pair<*, *> -> {
                                @Suppress("UNCHECKED_CAST")
                                val label = (item as Pair<String, String>).second
                                ChatDateSeparator(label = label)
                            }
                            is ChatMessage -> {
                                MessageBubble(
                                    message = item,
                                    onCopy = { clipboardManager.setText(AnnotatedString(item.displayText)) },
                                    onDelete = { onAction(ChatUiAction.DeleteMessage(item.id)) },
                                    onRetry = if (item.status == MessageStatus.ERROR) {
                                        { onAction(ChatUiAction.RetryMessage(item.id)) }
                                    } else null
                                )
                            }
                        }
                    }

                    // Typing indicator
                    if (state.isGenerating) {
                        item(key = "typing") {
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(vertical = NanoSpacingTokens.sm),
                                horizontalArrangement = Arrangement.Start
                            ) {
                                TypingIndicator()
                            }
                        }
                    }
                }
            }

            // ── Input Bar ──
            ChatInputBar(
                value = state.currentInput,
                onValueChange = { onAction(ChatUiAction.OnInputChanged(it)) },
                onSend = { onAction(ChatUiAction.SendMessage) },
                onStop = { onAction(ChatUiAction.StopGeneration) },
                isGenerating = state.isGenerating,
                characterLimit = state.characterLimit,
                suggestions = state.quickSuggestions,
                onSuggestionClick = { onAction(ChatUiAction.QuickSuggestion(it)) }
            )
        }

        // ── Scroll to Bottom FAB ──
        AnimatedVisibility(
            visible = showScrollFab,
            enter = scaleIn() + fadeIn(tween(NanoAnimationTokens.DurationFastMs)),
            exit = scaleOut() + fadeOut(tween(NanoAnimationTokens.DurationFastMs)),
            modifier = Modifier.align(Alignment.BottomEnd).padding(end = 16.dp, bottom = 140.dp)
        ) {
            FloatingActionButton(
                onClick = {
                    coroutineScope.launch {
                        listState.animateScrollToItem(state.messages.size - 1)
                    }
                },
                containerColor = MaterialTheme.colorScheme.primaryContainer,
                modifier = Modifier.size(40.dp)
            ) {
                Icon(Icons.Default.KeyboardArrowDown, "Ir al final", modifier = Modifier.size(20.dp))
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// Model Selector Header
// ─────────────────────────────────────────────────────────
@Composable
private fun ModelSelectorHeader(
    modelName: String,
    connectionState: ConnectionState,
    isExpanded: Boolean,
    availableModels: List<String>,
    onToggle: () -> Unit,
    onModelSelected: (String) -> Unit
) {
    Column {
        Surface(
            onClick = onToggle,
            color = MaterialTheme.colorScheme.surface,
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = NanoSpacingTokens.lg, vertical = NanoSpacingTokens.sm),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.sm)
                ) {
                    // Connection indicator dot
                    val dotColor = when (connectionState) {
                        ConnectionState.READY -> nanoColors().StatusSuccess
                        ConnectionState.LOADING_MODEL -> MaterialTheme.colorScheme.secondary
                        ConnectionState.NO_MODEL -> MaterialTheme.colorScheme.onSurfaceVariant
                        ConnectionState.ERROR -> MaterialTheme.colorScheme.error
                    }
                    Surface(
                        shape = NanoShapeTokens.full,
                        color = dotColor,
                        modifier = Modifier.size(8.dp)
                    ) {}

                    Column {
                        Text(
                            text = when (connectionState) {
                                ConnectionState.READY -> "Conectado"
                                ConnectionState.LOADING_MODEL -> "Cargando modelo..."
                                ConnectionState.NO_MODEL -> "Sin modelo"
                                ConnectionState.ERROR -> "Error de conexión"
                            },
                            style = NanoTypeTokens.label,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = modelName,
                            style = NanoTypeTokens.subtitle,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }

                Icon(
                    if (isExpanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                    "Modelos",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        // Dropdown model list
        AnimatedVisibility(
            visible = isExpanded && availableModels.isNotEmpty(),
            enter = expandVertically() + fadeIn(tween(NanoAnimationTokens.DurationFastMs)),
            exit = shrinkVertically() + fadeOut(tween(NanoAnimationTokens.DurationFastMs))
        ) {
            Column(modifier = Modifier.fillMaxWidth()) {
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                availableModels.forEach { name ->
                    Surface(
                        onClick = { onModelSelected(name) },
                        color = if (name == modelName) MaterialTheme.colorScheme.primaryContainer
                                else MaterialTheme.colorScheme.surface,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = NanoSpacingTokens.lg, vertical = NanoSpacingTokens.md),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(name, style = NanoTypeTokens.body, color = MaterialTheme.colorScheme.onSurface)
                            if (name == modelName) {
                                Icon(Icons.Default.Check, "Activo", tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// Empty Chat with Quick Suggestions
// ─────────────────────────────────────────────────────────
@Composable
private fun EmptyChatWithSuggestions(
    connectionState: ConnectionState,
    suggestions: List<String>,
    onSuggestionClick: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth().padding(NanoSpacingTokens.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        when (connectionState) {
            ConnectionState.NO_MODEL -> {
                Icon(Icons.Default.Psychology, null, Modifier.size(64.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f))
                Spacer(Modifier.height(NanoSpacingTokens.lg))
                Text("Selecciona un modelo para empezar", style = NanoTypeTokens.title, color = MaterialTheme.colorScheme.onSurface)
                Spacer(Modifier.height(NanoSpacingTokens.sm))
                Text("Ve a Modelos para descargar y activar un LLM", style = NanoTypeTokens.body, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            ConnectionState.LOADING_MODEL -> {
                CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.height(NanoSpacingTokens.lg))
                Text("Cargando modelo en memoria...", style = NanoTypeTokens.body, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            ConnectionState.ERROR -> {
                Icon(Icons.Default.ErrorOutline, null, Modifier.size(64.dp), tint = MaterialTheme.colorScheme.error)
                Spacer(Modifier.height(NanoSpacingTokens.lg))
                Text("Error al conectar con el modelo", style = NanoTypeTokens.title, color = MaterialTheme.colorScheme.onSurface)
            }
            ConnectionState.READY -> {
                Spacer(Modifier.height(NanoSpacingTokens.xxl))
                Text("NanoAI Chat", style = NanoTypeTokens.headlineLarge, color = MaterialTheme.colorScheme.onSurface)
                Spacer(Modifier.height(NanoSpacingTokens.sm))
                Text("100% local • sin internet", style = NanoTypeTokens.caption, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(NanoSpacingTokens.xl))

                // Quick suggestion chips
                Column(verticalArrangement = Arrangement.spacedBy(NanoSpacingTokens.sm)) {
                    suggestions.forEach { suggestion ->
                        QuickSuggestionChip(
                            text = suggestion,
                            onClick = { onSuggestionClick(suggestion) },
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }
            }
        }
    }
}

// ── Helpers ──
private fun formatDate(timestamp: Long): String {
    val cal = Calendar.getInstance().apply { timeInMillis = timestamp }
    val today = Calendar.getInstance()
    return when {
        cal.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR) &&
        cal.get(Calendar.YEAR) == today.get(Calendar.YEAR) -> "Hoy"
        else -> SimpleDateFormat("d MMM", Locale.getDefault()).format(Date(timestamp))
    }
}
