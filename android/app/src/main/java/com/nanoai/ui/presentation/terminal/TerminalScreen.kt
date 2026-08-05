package com.nanoai.ui.presentation.terminal

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Terminal
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.nanoai.ui.theme.*
import com.nanoai.ui.theme.nanoColors
import kotlinx.coroutines.launch

/**
 * TerminalScreen (SecciÃ³n 5 Specification Compliant)
 * Enforces SOLID Principles:
 * - Single Responsibility: Renders CLI stdout/stderr output and prompt controls.
 * - Interface Segregation: Consumes clean TerminalUiState and emits TerminalUiAction.
 */
@Composable
fun TerminalScreen(
    viewModel: TerminalViewModel,
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsState()

    TerminalContent(
        state = state,
        onAction = viewModel::onAction,
        modifier = modifier
    )
}

@Composable
fun TerminalContent(
    state: TerminalUiState,
    onAction: (TerminalUiAction) -> Unit,
    modifier: Modifier = Modifier
) {
    val listState = rememberLazyListState()
    val coroutineScope = rememberCoroutineScope()

    // Auto scroll on new line arrival
    LaunchedEffect(state.lines.size) {
        if (state.lines.isNotEmpty()) {
            coroutineScope.launch {
                listState.animateScrollToItem(state.lines.size - 1)
            }
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(nanoColors().TerminalBackground)
            .padding(NanoSpacingTokens.md)
    ) {
        // Top Header Bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = NanoSpacingTokens.sm),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.sm)
            ) {
                Icon(
                    imageVector = Icons.Default.Terminal,
                    contentDescription = null,
                    tint = nanoColors().TerminalGreen,
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    text = state.currentDirectory,
                    style = NanoTypeTokens.monospace,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            IconButton(
                onClick = { onAction(TerminalUiAction.ClearTerminal) },
                modifier = Modifier.size(32.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Clear,
                    contentDescription = "Limpiar consola",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(18.dp)
                )
            }
        }

        Divider(color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f))

        // Terminal Output Window
        LazyColumn(
            state = listState,
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(vertical = NanoSpacingTokens.sm),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            items(state.lines, key = { it.id }) { line ->
                TerminalOutputRow(line = line)
            }

            if (state.isExecuting) {
                item {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.sm),
                        modifier = Modifier.padding(top = 4.dp)
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(14.dp),
                            color = nanoColors().TerminalGreen,
                            strokeWidth = 2.dp
                        )
                        Text(
                            text = "Ejecutando comando nativo...",
                            style = NanoTypeTokens.monospace,
                            color = nanoColors().TerminalGreen.copy(alpha = 0.8f)
                        )
                    }
                }
            }
        }

        // Autocomplete Suggestion Chips Bar
        AnimatedVisibility(visible = state.autoSuggestions.isNotEmpty()) {
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.sm),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = NanoSpacingTokens.xs)
            ) {
                items(state.autoSuggestions) { suggestion ->
                    SuggestionChip(
                        onClick = { onAction(TerminalUiAction.SelectSuggestion(suggestion)) },
                        label = {
                            Text(
                                text = suggestion,
                                style = NanoTypeTokens.caption,
                                color = nanoColors().TerminalGreen
                            )
                        },
                        colors = SuggestionChipDefaults.suggestionChipColors(
                            containerColor = MaterialTheme.colorScheme.surface
                        ),
                        border = BorderStroke(1.dp, nanoColors().TerminalGreen.copy(alpha = 0.3f))
                    )
                }
            }
        }

        // Command Prompt Input Bar
        Surface(
            shape = NanoShapeTokens.medium,
            color = MaterialTheme.colorScheme.surface,
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = NanoSpacingTokens.md, vertical = NanoSpacingTokens.xs)
            ) {
                Text(
                    text = "$",
                    style = NanoTypeTokens.monospace,
                    color = nanoColors().TerminalGreen,
                    modifier = Modifier.padding(end = NanoSpacingTokens.sm)
                )

                TextField(
                    value = state.currentInput,
                    onValueChange = { onAction(TerminalUiAction.OnInputChanged(it)) },
                    placeholder = {
                        Text(
                            text = "Ingresa comando nanortime...",
                            style = NanoTypeTokens.monospace,
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                        )
                    },
                    textStyle = NanoTypeTokens.monospace.copy(color = MaterialTheme.colorScheme.onSurface),
                    singleLine = true,
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent
                    ),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Go),
                    keyboardActions = KeyboardActions(onGo = { onAction(TerminalUiAction.ExecuteCommand) }),
                    modifier = Modifier
                        .weight(1f)
                        .semantics { contentDescription = "Entrada de comando de terminal" }
                )

                IconButton(
                    onClick = { onAction(TerminalUiAction.ExecuteCommand) },
                    enabled = state.currentInput.isNotBlank()
                ) {
                    Icon(
                        imageVector = Icons.Default.PlayArrow,
                        contentDescription = "Ejecutar comando",
                        tint = if (state.currentInput.isNotBlank()) nanoColors().TerminalGreen else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
fun TerminalOutputRow(line: TerminalLine) {
    val textColor = when (line.type) {
        TerminalLineType.INPUT_PROMPT -> MaterialTheme.colorScheme.onSurface
        TerminalLineType.OUTPUT -> MaterialTheme.colorScheme.onSurfaceVariant
        TerminalLineType.SYSTEM_INFO -> nanoColors().StatusInfo
        TerminalLineType.ERROR -> MaterialTheme.colorScheme.error
        TerminalLineType.SUCCESS -> nanoColors().TerminalGreen
    }

    Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        modifier = Modifier.fillMaxWidth()
    ) {
        Text(
            text = line.text,
            style = NanoTypeTokens.monospace,
            color = textColor,
            modifier = Modifier.weight(1f)
        )
        if (line.timestamp.isNotEmpty()) {
            Text(
                text = line.timestamp,
                style = NanoTypeTokens.caption,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
                modifier = Modifier.padding(start = NanoSpacingTokens.sm)
            )
        }
    }
}

@Preview
@Composable
fun TerminalScreenPreview() {
    NanoAITheme {
        TerminalContent(
            state = TerminalUiState(
                lines = listOf(
                    TerminalLine("1", "NanoRuntime Engine Ready", TerminalLineType.SYSTEM_INFO, "12:00:01"),
                    TerminalLine("2", "$ nanortime --tune-system", TerminalLineType.INPUT_PROMPT, "12:00:05"),
                    TerminalLine("3", "[OK] Hardware initialized: Snapdragon 778G", TerminalLineType.SUCCESS, "12:00:06")
                ),
                autoSuggestions = listOf("nanortime --memory-status", "help")
            ),
            onAction = {}
        )
    }
}

