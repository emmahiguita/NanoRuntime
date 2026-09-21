import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/services/pdf_report_service.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/live_animations.dart';
import 'package:nanoai/core/widgets/nano_owl_avatar.dart';
import 'package:share_plus/share_plus.dart';

MarkdownStyleSheet _buildChatMarkdownStyleSheet(
  BuildContext context, {
  required bool isUser,
}) {
  final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
  final isDark = colors is NanoDarkColors;
  return MarkdownStyleSheet(
    p: TextStyle(
      color: isUser
          ? Colors.white
          : colors.onSurface.withValues(alpha: 0.96),
      fontSize: 15.5,
      height: 1.48,
      letterSpacing: -0.15,
      fontFamily: 'Inter',
    ),
    h1: TextStyle(
      color: colors.accentCyan,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      height: 1.35,
      letterSpacing: -0.3,
    ),
    h2: TextStyle(
      color: colors.accentCyan,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.35,
      letterSpacing: -0.2,
    ),
    h3: TextStyle(
      color: colors.success,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    strong: TextStyle(
      color: isUser ? Colors.white : colors.onSurface,
      fontWeight: FontWeight.w700,
    ),
    em: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.9),
      fontStyle: FontStyle.italic,
    ),
    listBullet: TextStyle(color: colors.accentCyan, fontSize: 15),
    code: TextStyle(
      backgroundColor: colors.accentCyan.withValues(alpha: isDark ? 0.18 : 0.12),
      color: isDark ? const Color(0xFF67E8F9) : const Color(0xFF0284C7),
      fontFamily: 'JetBrainsMono',
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    ),
    codeblockPadding: const EdgeInsets.all(14),
    codeblockDecoration: BoxDecoration(
      color: isDark ? const Color(0xFF070D18) : colors.codeBlockBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: colors.accentCyan.withValues(alpha: isDark ? 0.30 : 0.18),
        width: 0.9,
      ),
    ),
    blockquote: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.88),
      fontSize: 14.5,
      fontStyle: FontStyle.italic,
    ),
    blockquoteDecoration: BoxDecoration(
      color: colors.accentCyan.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border(
        left: BorderSide(color: colors.accentCyan, width: 3.5),
      ),
    ),
    tableBorder: TableBorder.all(
      color: colors.onSurface.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
    ),
    tableHead: TextStyle(
      color: colors.accentCyan,
      fontWeight: FontWeight.w700,
      fontSize: 13.5,
    ),
    tableBody: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.9),
      fontSize: 13,
    ),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.model,
    required this.timestamp,
    required this.source,
    this.isError = false,
    this.attachmentNames = const [],
    this.suggestions = const [],
    this.tps,
    this.onRetry,
    this.onDelete,
    this.onSuggestionSelected,
  });

  final String text;
  final bool isUser;
  final String model;
  final DateTime timestamp;
  final MessageSource source;
  final bool isError;
  final double? tps;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;
  final List<String> attachmentNames;
  final List<String> suggestions;
  final ValueChanged<String>? onSuggestionSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;

    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';

    final displayModel = source == MessageSource.device
        ? 'Nano · Memento'
        : (model.isEmpty ? 'Nano AI' : model);

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          margin: const EdgeInsets.only(bottom: 14, left: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF064E3B),
                      const Color(0xFF047857),
                    ]
                  : [
                      colors.primary,
                      colors.primary.withValues(alpha: 0.88),
                    ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.35),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? const Color(0xFF10B981) : colors.primary).withValues(
                  alpha: isDark ? 0.22 : 0.15,
                ),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (attachmentNames.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: attachmentNames
                      .map(
                        (name) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.attach_file_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],
              MarkdownBody(
                data: text,
                selectable: true,
                styleSheet: _buildChatMarkdownStyleSheet(context, isUser: true),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all_rounded,
                    size: 13,
                    color: isDark ? const Color(0xFF34D399) : Colors.white70,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // AI Message: Free-flowing unboxed layout (ChatGPT / Claude style)
    return Container(
      margin: const EdgeInsets.only(bottom: 22, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header minimalista con avatar del Búho y badge de modelo
          Row(
            children: [
              NanoOwlAvatar(
                size: 26,
                state: isError ? NanoOwlState.error : NanoOwlState.idle,
                enableBreathing: true,
                enableRandomBlink: true,
                enableGlow: false,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  displayModel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (source == MessageSource.device
                          ? colors.accentCyan
                          : colors.primary)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (source == MessageSource.device
                            ? colors.accentCyan
                            : colors.primary)
                        .withValues(alpha: 0.30),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  source == MessageSource.device ? '⚡ MEMENTO CBR' : 'LOCAL IA',
                  style: TextStyle(
                    color: source == MessageSource.device
                        ? (isDark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490))
                        : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (tps != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${tps!.toStringAsFixed(1)} t/s',
                    style: TextStyle(
                      color: colors.success,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Cuerpo de la respuesta AI (suelta / sin caja)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _buildAiBody(context, text),
          ),

          // Opciones interactivas de respuesta rápida estilo iOS glass
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions.map((sug) {
                final pillColor = isDark ? const Color(0xFF10B981) : colors.accent;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSuggestionSelected?.call(sug),
                    borderRadius: BorderRadius.circular(14),
                    splashColor: pillColor.withValues(alpha: 0.20),
                    highlightColor: pillColor.withValues(alpha: 0.10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: pillColor.withValues(alpha: isDark ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: pillColor.withValues(alpha: isDark ? 0.28 : 0.22),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: pillColor.withValues(alpha: isDark ? 0.08 : 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              sug,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: pillColor.withValues(alpha: 0.85),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 10),

          // Barra de acciones limpia al pie (Copy, Share, Menu PDF/MD, Time)
          Row(
            children: [
              Text(
                time,
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.45),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: 12),
              if (!isError) ...[
                _QuickActionButton(
                  icon: Icons.copy_rounded,
                  tooltip: 'Copiar respuesta',
                  onTap: () async {
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
                  },
                ),
                const SizedBox(width: 4),
                _QuickActionButton(
                  icon: Icons.share_rounded,
                  tooltip: 'Compartir',
                  onTap: () => SharePlus.instance.share(
                    ShareParams(text: text, subject: 'Respuesta Nano AI'),
                  ),
                ),
                const SizedBox(width: 4),
                MessageActions(
                  text: text,
                  model: displayModel,
                  timestamp: timestamp,
                  onDelete: onDelete,
                ),
              ],
              if (onRetry != null) ...[
                const Spacer(),
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
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: colors.accentCyan,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reintentar',
                              style: TextStyle(
                                color: colors.accentCyan,
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
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    // Semantics en lugar de Tooltip: Tooltip dispara Overlay.of() que falla
    // dentro de árboles sin Overlay (WebView cards, custom stacks).
    return Semantics(
      label: tooltip,
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              icon,
              size: 16,
              color: colors.onSurface.withValues(alpha: 0.50),
            ),
          ),
        ),
      ),
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

class MessageActions extends StatelessWidget {
  const MessageActions({
    super.key,
    required this.text,
    required this.model,
    required this.timestamp,
    this.onDelete,
  });

  final String text;
  final String model;
  final DateTime timestamp;
  final VoidCallback? onDelete;

  void _showActionsSheet(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.paddingOf(sheetContext).bottom + 20;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xF20B131E) : colors.surface.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: (isDark ? const Color(0xFF10B981) : colors.accent).withValues(alpha: 0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: bottomPadding,
              ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.copy_rounded,
                iconColor: colors.onSurface.withValues(alpha: 0.72),
                label: 'Copiar',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
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
                },
              ),
              _ActionTile(
                icon: Icons.share_rounded,
                iconColor: colors.onSurface.withValues(alpha: 0.72),
                label: 'Compartir',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  SharePlus.instance.share(
                    ShareParams(
                      text: text,
                      subject: 'Respuesta NanoAI — $model',
                    ),
                  );
                },
              ),
              if (onDelete != null)
                _ActionTile(
                  icon: Icons.delete_outline_rounded,
                  iconColor: colors.danger,
                  label: 'Eliminar',
                  textColor: colors.danger,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onDelete?.call();
                  },
                ),
              Divider(
                color: colors.onSurface.withValues(alpha: 0.12),
                height: 24,
              ),
              _ActionTile(
                icon: Icons.picture_as_pdf_rounded,
                iconColor: colors.accent,
                label: 'Exportar como PDF',
                subtitle: 'Informe técnico estructurado',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await PdfReportService.exportReport(
                    title: 'Informe de Análisis NanoAI',
                    content: text,
                    modelName: model,
                    timestamp: timestamp,
                  );
                },
              ),
              _ActionTile(
                icon: Icons.description_rounded,
                iconColor: colors.success,
                label: 'Exportar como Markdown',
                subtitle: 'Archivo .md estructurado',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await PdfReportService.exportMarkdown(
                    title: 'Informe de Análisis NanoAI',
                    content: text,
                    modelName: model,
                    timestamp: timestamp,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Semantics(
      label: 'Acciones',
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _showActionsSheet(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: colors.onSurface.withValues(alpha: 0.50),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.textColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final Color? textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor ?? colors.onSurface.withValues(alpha: 0.90),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StreamingBubble extends StatelessWidget {
  const StreamingBubble({
    super.key,
    required this.text,
    required this.model,
  });

  final String text;
  final String model;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;

    final parsed = parseThought(text);
    final thought = parsed.thought;
    final response = parsed.response;

    final Widget body;
    if (text.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ThinkingIndicator(),
        ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 20, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header minimalista con Búho en modo thinking y badge seguro contra overflow
          Row(
            children: [
              NanoOwlAvatar(
                size: 26,
                state: response.isNotEmpty
                    ? NanoOwlState.responding
                    : NanoOwlState.thinking,
                enableBreathing: true,
                enableGlow: true,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          model.isEmpty ? 'Nano AI' : model,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: colors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Generando...',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: colors.onSurface.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: body,
          ),
        ],
      ),
    );
  }
}

class EmptyChat extends StatelessWidget {
  const EmptyChat({
    super.key,
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
    final mediaSize = MediaQuery.sizeOf(context);
    final isCompact = mediaSize.height < 600;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: isCompact ? 12 : 28,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Nano Owl Hero Avatar
                NanoOwlAvatar(
                  size: isCompact ? 72 : 96,
                  state: NanoOwlState.idle,
                  enableBreathing: true,
                  enableRandomBlink: true,
                  enableGlow: true,
                ),
                SizedBox(height: isCompact ? 12 : 18),
                Text(
                  'Nano AI Assistant',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: colors.onSurface,
                    fontSize: isCompact ? 20 : 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Inteligencia On-Device Soberana · Privada · Conectada al Hardware',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: colors.onSurface.withValues(alpha: 0.55),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                if (!engineOnline)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.power_settings_new_rounded,
                                size: 18, color: colors.warning),
                            const SizedBox(width: 8),
                            Text(
                              'Motor local no iniciado',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: colors.warning,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          key: const ValueKey('chat_retry_button'),
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Iniciar Motor Local'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.onSurface,
                            side: BorderSide(
                              color: colors.onSurface.withValues(alpha: 0.25),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!hasModel)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 18, color: colors.accent),
                            const SizedBox(width: 8),
                            Text(
                              'No hay modelo cargado en memoria',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: colors.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: onGoModels,
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Seleccionar o Descargar Modelo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.accent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Motor listo · Ejecución local y Memento CBR activos',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: colors.onSurface.withValues(alpha: 0.45),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Grid de Accesos Rápidos
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 460;
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: isNarrow ? 1 : 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: isNarrow ? 3.4 : 2.2,
                            children: [
                              _QuickCard(
                                icon: Icons.battery_charging_full_rounded,
                                iconColor: const Color(0xFF00E676),
                                title: 'Estado del Hardware',
                                subtitle: 'Batería, RAM y CPU con Memento Fast-Path',
                                onTap: () => onSuggestion('¿Cómo está la batería y el hardware del teléfono?'),
                              ),
                              _QuickCard(
                                icon: Icons.speed_rounded,
                                iconColor: const Color(0xFF00B0FF),
                                title: 'Benchmark & TPS',
                                subtitle: 'Evalúa rendimiento local y tokens/segundo',
                                onTap: () => onSuggestion(
                                  'Realiza una prueba de estrés y análisis de rendimiento de inferencia. '
                                  'Organiza los resultados en una tabla comparativa con métricas de RAM, CPU y TPS.',
                                ),
                              ),
                              _QuickCard(
                                icon: Icons.description_rounded,
                                iconColor: const Color(0xFFFF9100),
                                title: 'Informe Técnico en PDF',
                                subtitle: 'Genera un reporte estructurado y compártelo',
                                onTap: () => onSuggestion(
                                  'Genera un informe técnico completo y estructurado sobre el estado actual del dispositivo, '
                                  'con tablas detalladas de arquitectura y almacenamiento, listo para exportar a PDF.',
                                ),
                              ),
                              _QuickCard(
                                icon: Icons.account_tree_rounded,
                                iconColor: const Color(0xFFE040FB),
                                title: 'Diagrama de Arquitectura',
                                subtitle: 'Visualiza el stack local con código Mermaid',
                                onTap: () => onSuggestion(
                                  'Explica la arquitectura del runtime de NanoAI (Flutter, Binder/SAF, nanortime, llama.cpp) '
                                  'e incluye un diagrama en bloque de código ```mermaid.',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surface.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.onSurface.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: colors.onSurface.withValues(alpha: 0.48),
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
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
  const SuggestionChip({
    super.key,
    required this.label,
    required this.onTap,
  });

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
        fontFamily: 'Inter',
        color: colors.onSurface.withValues(alpha: 0.72),
        fontSize: 13,
      ),
      side: BorderSide(color: colors.onSurface.withValues(alpha: 0.12)),
    );
  }
}
