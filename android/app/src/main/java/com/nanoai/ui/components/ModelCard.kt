package com.nanoai.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.nanoai.ui.presentation.models.GgufModelItem
import com.nanoai.ui.theme.*

/**
 * ModelCard Component (Sección 3 Specification Compliant)
 * Enforces SOLID Principles:
 * - Single Responsibility: Renders GGUF model card with status badge, RAM requirement, size, and actions.
 */
@Composable
fun ModelCard(
    model: GgufModelItem,
    onSelect: () -> Unit,
    onOpenDetails: () -> Unit,
    onDownload: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clickable { onOpenDetails() }
            .semantics { contentDescription = "Modelo GGUF: ${model.name}" },
        shape = NanoShapeTokens.large,
        colors = CardDefaults.cardColors(
            containerColor = if (model.isActive) MaterialTheme.colorScheme.surfaceVariant else MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = if (model.isActive) 4.dp else 1.dp)
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
                Surface(
                    shape = NanoShapeTokens.small,
                    color = MaterialTheme.colorScheme.primaryContainer
                ) {
                    Text(
                        text = "${model.parameterCount} • ${model.quantType.name}",
                        style = NanoTypeTokens.caption,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }

                if (model.isActive) {
                    Surface(
                        shape = NanoShapeTokens.small,
                        color = MaterialTheme.colorScheme.secondaryContainer
                    ) {
                        Text(
                            text = "ACTIVO",
                            style = NanoTypeTokens.caption,
                            color = MaterialTheme.colorScheme.onSecondaryContainer,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(NanoSpacingTokens.sm))

            Text(
                text = model.name,
                style = NanoTypeTokens.subtitle,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )

            Spacer(modifier = Modifier.height(NanoSpacingTokens.xs))

            Row(
                horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.lg),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = "Tamaño: ${model.fileSizeGb} GB",
                    style = NanoTypeTokens.caption,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = "RAM Requerida: ${model.ramRequiredGb} GB",
                    style = NanoTypeTokens.caption,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(modifier = Modifier.height(NanoSpacingTokens.md))

            if (model.downloadProgress != null && model.downloadProgress < 1f) {
                LinearProgressIndicator(
                    progress = { model.downloadProgress },
                    modifier = Modifier.fillMaxWidth(),
                    color = MaterialTheme.colorScheme.primary
                )
            } else {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (model.isDownloaded) {
                        if (!model.isActive) {
                            Button(
                                onClick = onSelect,
                                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary),
                                shape = NanoShapeTokens.medium
                            ) {
                                Text("Cargar Modelo")
                            }
                        } else {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = Icons.Default.CheckCircle,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.secondary,
                                    modifier = Modifier.size(18.dp)
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Cargado en Memoria", style = NanoTypeTokens.caption, color = MaterialTheme.colorScheme.secondary)
                            }
                        }
                    } else {
                        OutlinedButton(
                            onClick = onDownload,
                            shape = NanoShapeTokens.medium
                        ) {
                            Icon(
                                imageVector = Icons.Default.Download,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Descargar")
                        }
                    }
                }
            }
        }
    }
}
