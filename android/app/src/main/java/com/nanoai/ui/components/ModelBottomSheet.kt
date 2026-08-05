package com.nanoai.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.nanoai.ui.presentation.models.GgufModelItem
import com.nanoai.ui.theme.*

/**
 * ModelBottomSheet Component (Sección 3 Specification Compliant)
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ModelBottomSheet(
    model: GgufModelItem,
    onDismiss: () -> Unit,
    onSelect: () -> Unit,
    onDelete: () -> Unit
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(NanoSpacingTokens.xl)
        ) {
            Text(
                text = model.name,
                style = NanoTypeTokens.title,
                color = MaterialTheme.colorScheme.onSurface
            )

            Spacer(modifier = Modifier.height(NanoSpacingTokens.md))

            Text(
                text = model.description,
                style = NanoTypeTokens.body,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Spacer(modifier = Modifier.height(NanoSpacingTokens.lg))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text("Parámetros", style = NanoTypeTokens.caption, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(model.parameterCount, style = NanoTypeTokens.subtitle, color = MaterialTheme.colorScheme.onSurface)
                }
                Column {
                    Text("Cuantiación", style = NanoTypeTokens.caption, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(model.quantType.name, style = NanoTypeTokens.subtitle, color = MaterialTheme.colorScheme.onSurface)
                }
                Column {
                    Text("Tamaño", style = NanoTypeTokens.caption, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("${model.fileSizeGb} GB", style = NanoTypeTokens.subtitle, color = MaterialTheme.colorScheme.onSurface)
                }
            }

            Spacer(modifier = Modifier.height(NanoSpacingTokens.xxl))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.md)
            ) {
                if (model.isDownloaded) {
                    OutlinedButton(
                        onClick = onDelete,
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error)
                    ) {
                        Icon(imageVector = Icons.Default.Delete, contentDescription = null)
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Eliminar")
                    }

                    Button(
                        onClick = {
                            onSelect()
                            onDismiss()
                        },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                    ) {
                        Icon(imageVector = Icons.Default.PlayArrow, contentDescription = null)
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Cargar")
                    }
                }
            }
        }
    }
}
