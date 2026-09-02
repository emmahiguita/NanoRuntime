import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/services/pdf_report_service.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/live_animations.dart';
import 'package:share_plus/share_plus.dart';

MarkdownStyleSheet _buildChatMarkdownStyleSheet(
  BuildContext context, {
  required bool isUser,
}) {
  final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
  return MarkdownStyleSheet(
    p: TextStyle(
      color: isUser
          ? colors.onSurface
          : colors.onSurface.withValues(alpha: 0.95),
      fontSize: 15,
      height: 1.55,
      letterSpacing: 0.15,
    ),
    h1: TextStyle(
      color: colors.accent,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      height: 1.4,
    ),
    h2: TextStyle(
      color: colors.accent,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.4,
    ),
    h3: TextStyle(
      color: colors.success,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    strong: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w700),
    em: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.9),
      fontStyle: FontStyle.italic,
    ),
    listBullet: TextStyle(color: colors.accent, fontSize: 15),
    code: TextStyle(
      backgroundColor: colors.success.withValues(alpha: 0x20 / 0xFF),
      color: colors.success,
      fontFamily: 'monospace',
      fontSize: 13.5,
    ),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: BoxDecoration(
      color: colors.codeBlockBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
    ),
    blockquote: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.8),
      fontSize: 14.5,
      fontStyle: FontStyle.italic,
    ),
    blockquoteDecoration: BoxDecoration(
      color: colors.quoteBg.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(8),
      border: Border(left: BorderSide(color: colors.accent, width: 3)),
    ),
    tableBorder: TableBorder.all(
      color: colors.onSurface.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(6),
    ),
    tableHead: TextStyle(color: colors.accent, fontWeight: FontWeight.w700),
    tableBody: TextStyle(color: colors.onSurface.withValues(alpha: 0.9)),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  );
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.text,
    required this.isUser,
    required this.model,
    required this.timestamp,
    required this.source,
    this.isError = false,
    this.attachmentNames = const [],
    this.tps,
    this.onRetry,
    this.onDelete,
  });

  final String text;
  final bool isUser;
  final String model;
  final DateTime timestamp;
  final MessageSource source;
  final bool isError;

  /// Tokens por segundo de la generación (solo respuestas AI completadas).
  final double? tps;

  /// Callback para reintentar el envío tras un error.
  final VoidCallback? onRetry;

  /// Callback para eliminar el mensaje.
  final VoidCallback? onDelete;

  /// Nombres de los adjuntos que viajaron con este mensaje (solo chips;
  /// el contenido se inyectó al prompt y no se persiste).
  final List<String> attachmentNames;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';

    // Pie del mensaje: hora + TPS (si hay)
    final footerParts = <Widget>[
      Text(
        time,
        style: TextStyle(
          color: colors.onSurface.withValues(alpha: 0.48),
          fontSize: 10,
        ),
      ),
    ];

    if (tps != null && !isUser) {
      footerParts.addAll([
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: colors.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.success.withValues(alpha: 0.30)),
          ),
          child: Text(
            '${tps!.toStringAsFixed(1)} tok/s',
            style: TextStyle(
              color: colors.success,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]);
    }

    final isDark = colors is NanoDarkColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final displayModel = source == MessageSource.device
        ? 'Nano · Dispositivo'
        : (model.isEmpty ? 'NanoAI' : model);

    final bubbleBorderRadius = isUser
        ? NanoShapes.userBubble
        : NanoShapes.aiBubble;

    final bubbleDecoration = isUser
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      colors.primary.withValues(alpha: 0.35),
                      colors.accentCyan.withValues(alpha: 0.20),
                    ]
                  : [
                      colors.primary.withValues(alpha: 0.18),
                      colors.accentSky.withValues(alpha: 0.10),
                    ],
            ),
            borderRadius: bubbleBorderRadius,
            border: Border.all(
              color: isDark
                  ? colors.accentCyan.withValues(alpha: 0.50)
                  : colors.primary.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? colors.accentCyan : colors.primary).withValues(
                  alpha: isDark ? 0.20 : 0.08,
                ),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          )
        : BoxDecoration(
            gradient: NanoGlass.substrate(
              colors,
              opacity: isDark ? 0.78 : 0.88,
            ),
            borderRadius: bubbleBorderRadius,
          );

    Widget bubbleWidget = Container(
      constraints: BoxConstraints(maxWidth: isUser ? 680 : double.infinity),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: bubbleDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachmentNames.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: attachmentNames
                  .map(
                    (name) => Chip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.attach_file_rounded,
                            size: 14,
                            color: colors.onSurface.withValues(alpha: 0.72),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: TextStyle(
                              color: colors.onSurface.withValues(alpha: 0.72),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: colors.onSurface.withValues(alpha: 0.08),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          if (!isUser) ...[
            Row(
              children: [
                Icon(
                  source == MessageSource.device
                      ? Icons.phone_android_rounded
                      : Icons.auto_awesome_rounded,
                  size: 14,
                  color: colors.accent.withValues(alpha: isDark ? 0.92 : 0.78),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    displayModel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.60),
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (isUser)
            MarkdownBody(
              data: text,
              selectable: true,
              styleSheet: _buildChatMarkdownStyleSheet(context, isUser: isUser),
            )
          else
            _buildAiBody(context, text),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: footerParts),
              if (!isUser && !isError)
                MessageActions(
                  text: text,
                  model: displayModel,
                  timestamp: timestamp,
                  onDelete: onDelete,
                ),
              if (onRetry != null)
                Semantics(
                  button: true,
                  label: 'Reintentar mensaje',
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: onRetry,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: colors.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reintentar',
                              style: TextStyle(
                                color: colors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (!isUser) {
      bubbleWidget = Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: bubbleBorderRadius,
          boxShadow: NanoShadows.ambient(colors, depth: 0.6),
        ),
        child: Container(
          padding: const EdgeInsets.all(1.0),
          decoration: BoxDecoration(
            borderRadius: bubbleBorderRadius,
            gradient: NanoBorders.specularChamfer(colors),
          ),
          child: ClipRRect(
            borderRadius: bubbleBorderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: reduceMotion ? 0.0 : 12.0,
                sigmaY: reduceMotion ? 0.0 : 12.0,
              ),
              child: bubbleWidget,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: bubbleWidget,
    );
  }
}

Widget _buildAiBody(BuildContext context, String text) {
  final parsed = parseThought(text);
  final thought = parsed.thought;
  final response = parsed.response;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (thought != null && thought.trim().isNotEmpty)
        ModelReasoningBlock(thought: thought),
      if (response.trim().isNotEmpty)
        MarkdownBody(
          data: response,
          selectable: true,
          styleSheet: _buildChatMarkdownStyleSheet(context, isUser: false),
        )
      else if (thought != null && response.isEmpty)
        const SizedBox.shrink()
      else
        MarkdownBody(
          data: text.isEmpty ? '...' : text,
          selectable: true,
          styleSheet: _buildChatMarkdownStyleSheet(context, isUser: false),
        ),
    ],
  );
}

// ================================================================
// Menú de acciones de mensaje (3 puntos)
// ================================================================

/// Menú profesional de 3 puntos para cada burbuja AI completada.
/// Organizado en 3 acciones: Copiar · Compartir · Exportar (PDF | Markdown).
class MessageActions extends StatelessWidget {
  const MessageActions({
    required this.text,
    required this.model,
    required this.timestamp,
    this.onDelete,
  });

  final String text;
  final String model;
  final DateTime timestamp;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 18,
        color: colors.onSurface.withValues(alpha: 0.48),
      ),
      tooltip: 'Acciones',
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.accent.withValues(alpha: 0.25)),
      ),
      elevation: 8,
      position: PopupMenuPosition.under,
      onSelected: (value) async {
        switch (value) {
          case 'copy':
            await Clipboard.setData(ClipboardData(text: text));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Texto copiado al portapapeles'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            break;

          case 'share':
            await SharePlus.instance.share(
              ShareParams(
                text: text,
                subject: 'Respuesta NanoAI — $model',
              ),
            );
            break;

          case 'delete':
            if (onDelete != null) onDelete!();
            break;

          case 'export_pdf':
            await PdfReportService.exportReport(
              title: 'Informe de Análisis NanoAI',
              content: text,
              modelName: model,
              timestamp: timestamp,
            );
            break;

          case 'export_md':
            await PdfReportService.exportMarkdown(
              title: 'Informe de Análisis NanoAI',
              content: text,
              modelName: model,
              timestamp: timestamp,
            );
            break;
        }
      },
      itemBuilder: (context) => [
        // Ã¢â€â‚¬Ã¢â€â‚¬ 1. Copiar Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(
                Icons.copy_rounded,
                size: 18,
                color: colors.onSurface.withValues(alpha: 0.72),
              ),
              const SizedBox(width: 12),
              Text(
                'Copiar',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        // Ã¢â€â‚¬Ã¢â€â‚¬ 2. Compartir Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        PopupMenuItem<String>(
          value: 'share',
          child: Row(
            children: [
              Icon(
                Icons.share_rounded,
                size: 18,
                color: colors.onSurface.withValues(alpha: 0.72),
              ),
              const SizedBox(width: 12),
              Text(
                'Compartir',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (onDelete != null)
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: colors.danger,
                ),
                const SizedBox(width: 12),
                Text(
                  'Eliminar',
                  style: TextStyle(color: colors.danger, fontSize: 14),
                ),
              ],
            ),
          ),
        // Ã¢â€â‚¬Ã¢â€â‚¬ Divisor Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        const PopupMenuDivider(height: 1),
        // Ã¢â€â‚¬Ã¢â€â‚¬ 3a. Exportar Ã¢â€ â€™ PDF Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        PopupMenuItem<String>(
          value: 'export_pdf',
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf_rounded,
                size: 18,
                color: colors.accent,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Exportar como PDF',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Informe técnico estructurado',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Ã¢â€â‚¬Ã¢â€â‚¬ 3b. Exportar Ã¢â€ â€™ Markdown Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        PopupMenuItem<String>(
          value: 'export_md',
          child: Row(
            children: [
              Icon(Icons.description_rounded, size: 18, color: colors.success),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Exportar como Markdown',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Archivo .md para Obsidian, Notion…',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StreamingBubble extends StatelessWidget {
  const StreamingBubble({required this.text, required this.model});

  final String text;
  final String model;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    const radius = NanoShapes.aiBubble;

    final parsed = parseThought(text);
    final thought = parsed.thought;
    final response = parsed.response;

    // Cuerpo vivo: sin texto aún Ã¢â€ â€™ pensamiento en onda; con texto Ã¢â€ â€™ contenido
    // streaming + cursor respirando al final (hiperrealista, sin simulación).
    final Widget body;
    if (text.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Center(child: ThinkingIndicator()),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (thought != null && thought.trim().isNotEmpty)
            ModelReasoningBlock(thought: thought, initiallyExpanded: true),
          if (response.trim().isNotEmpty)
            MarkdownBody(
              data: response,
              styleSheet: _buildChatMarkdownStyleSheet(context, isUser: false),
            )
          else if (thought != null && response.isEmpty)
            const SizedBox.shrink()
          else
            MarkdownBody(
              data: text.isEmpty ? '...' : text,
              styleSheet: _buildChatMarkdownStyleSheet(context, isUser: false),
            ),
          const SizedBox(height: 6),
          const StreamingCursor(),
        ],
      );
    }

    Widget content = Container(
      constraints: const BoxConstraints(maxWidth: double.infinity),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: NanoGlass.substrate(colors, opacity: isDark ? 0.78 : 0.88),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          body,
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: colors.success,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  'Generando con $model...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.48),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Ãƒâ€œptica premium idéntica al mensaje AI: bisel especular + sombra
    // ambiental + vidrio desenfocado. El fondo living se refracta detrás.
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: NanoShadows.ambient(colors, depth: 0.6),
        ),
        child: Container(
          padding: const EdgeInsets.all(1.0),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: NanoBorders.specularChamfer(colors),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: reduceMotion ? 0.0 : 12.0,
                sigmaY: reduceMotion ? 0.0 : 12.0,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyChat extends StatelessWidget {
  const EmptyChat({
    required this.engineOnline,
    required this.hasModel,
    required this.onSuggestion,
    required this.onRetry,
    required this.onGoModels,
  });

  final bool engineOnline;
  final bool hasModel;
  final void Function(String) onSuggestion;
  final VoidCallback onRetry;
  final VoidCallback onGoModels;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Chat local',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.72),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (!engineOnline)
                Column(
                  children: [
                    Text(
                      'Motor local detenido',
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.48),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('chat_retry_button'),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: colors.onSurface.withValues(
                          alpha: 0.88,
                        ),
                        side: BorderSide(
                          color: colors.onSurface.withValues(alpha: 0.24),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                )
              else if (!hasModel)
                Column(
                  children: [
                    Text(
                      'No hay modelos cargados',
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.48),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: onGoModels,
                      icon: const Icon(Icons.extension_rounded, size: 18),
                      label: const Text('Ir a Modelos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: colors.onSurface,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Text(
                      'Escribe un mensaje para comenzar',
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.48),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        SuggestionChip(
                          label: 'Prueba de estrés y rendimiento',
                          onTap: () => onSuggestion(
                            'Realiza una prueba de estrés y análisis de rendimiento de inferencia en este dispositivo. '
                            'Mide la capacidad de respuesta y organiza los resultados en una tabla comparativa con métricas de RAM, CPU y TPS estimado.',
                          ),
                        ),
                        SuggestionChip(
                          label: 'Informe técnico del sistema',
                          onTap: () => onSuggestion(
                            'Genera un informe técnico completo y estructurado sobre el estado actual del dispositivo, '
                            'con tablas detalladas de hardware, arquitectura y almacenamiento, listo para exportar a PDF.',
                          ),
                        ),
                        SuggestionChip(
                          label: 'Diagrama de arquitectura',
                          onTap: () => onSuggestion(
                            'Explica la arquitectura del runtime de NanoAI (Flutter, Binder/SAF, nanortime, llama.cpp) '
                            'e incluye un diagrama en bloque de código ```mermaid.',
                          ),
                        ),
                        SuggestionChip(
                          label: 'Resumen ejecutivo',
                          onTap: () => onSuggestion(
                            'Genera un resumen ejecutivo de tus capacidades locales, estado de soberanía de datos '
                            'y directivas de seguridad.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// Soporte de Razonamiento (DeepSeek <thought>)
// ================================================================

class ParsedThoughtText {
  final String? thought;
  final String response;
  const ParsedThoughtText({this.thought, required this.response});
}

ParsedThoughtText parseThought(String text) {
  final thoughtStart = text.indexOf('<thought>');
  if (thoughtStart == -1) {
    return ParsedThoughtText(response: text);
  }

  final thoughtEnd = text.indexOf('</thought>', thoughtStart);
  if (thoughtEnd == -1) {
    final thought = text.substring(thoughtStart + 9);
    return ParsedThoughtText(thought: thought, response: '');
  }

  final thought = text.substring(thoughtStart + 9, thoughtEnd);
  final response = text.substring(thoughtEnd + 10).trim();
  return ParsedThoughtText(thought: thought, response: response);
}

class ModelReasoningBlock extends StatefulWidget {
  const ModelReasoningBlock({
    super.key,
    required this.thought,
    this.initiallyExpanded = false,
  });

  final String thought;
  final bool initiallyExpanded;

  @override
  State<ModelReasoningBlock> createState() => _ModelReasoningBlockState();
}

class _ModelReasoningBlockState extends State<ModelReasoningBlock> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant ModelReasoningBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia el estado de inicialmente expandido (por ejemplo, en streaming)
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    if (widget.thought.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.codeBlockBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.success.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology_rounded,
                    size: 16,
                    color: colors.success.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Razonamiento del modelo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.success.withValues(alpha: 0.8),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: colors.onSurface.withValues(alpha: 0.48),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.codeBlockBg.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.thought.trim(),
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                    height: 1.5,
                    color: colors.onSurface.withValues(alpha: 0.65),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SuggestionChip extends StatelessWidget {
  const SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: colors.onSurface.withValues(alpha: 0.08),
      labelStyle: TextStyle(
        color: colors.onSurface.withValues(alpha: 0.72),
        fontSize: 13,
      ),
      side: BorderSide(color: colors.onSurface.withValues(alpha: 0.12)),
    );
  }
}

/// Cápsula líquida flotante que se muestra cuando la barra de chat está encogida/minimizada.
