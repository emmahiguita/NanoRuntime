import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/browser/application/browser_context_extractor.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser_ai/application/browser_ai_gateway.dart';
import 'package:nanoai/features/browser_ai/domain/browser_ai_query.dart';

/// QUÉ HACE:
/// Hub universal flotante de Búho AI con estética iOS Glass 3D.
/// Permite consultas Web AI en vivo (ChatGPT/DeepSeek/Gemini), automatización
/// de tareas del dispositivo y extracción/resumen de la página web activa.
///
/// CÓMO FUNCIONA:
/// Unifica la experiencia del botón flotante global y del botón de Búho en
/// el navegador. Detecta si hay un WebView activo para extraer su contexto
/// automáticamente con [BrowserContextExtractor].
///
/// POR QUÉ:
/// Elimina las pantallas negras y vacías anteriores al garantizar restricciones
/// de altura acotadas (85% max screen height) y un renderizado a prueba de fallos.
class NanoFloatingOwlHubSheet extends ConsumerStatefulWidget {
  final BrowserTabModel? activeTab;
  final InAppWebViewController? webViewController;

  const NanoFloatingOwlHubSheet({
    super.key,
    this.activeTab,
    this.webViewController,
  });

  /// Muestra el panel flotante de Búho AI desde cualquier contexto de la app.
  static Future<void> show(
    BuildContext context, {
    BrowserTabModel? tab,
    InAppWebViewController? controller,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true, // Garantiza que el sheet flote por encima del dock
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => NanoFloatingOwlHubSheet(
        activeTab: tab,
        webViewController: controller,
      ),
    );
  }

  @override
  ConsumerState<NanoFloatingOwlHubSheet> createState() =>
      _NanoFloatingOwlHubSheetState();
}

enum _OwlHubMode { webAi, automate, summarize, copy }

class _NanoFloatingOwlHubSheetState
    extends ConsumerState<NanoFloatingOwlHubSheet> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  _OwlHubMode _mode = _OwlHubMode.webAi;
  String _provider = 'chatgpt';
  bool _isLoading = false;
  String? _outputResult;
  bool _isError = false;

  static const _aiProviders = [
    ('chatgpt', 'ChatGPT'),
    ('deepseek', 'DeepSeek'),
    ('gemini', 'Gemini'),
    ('claude', 'Claude'),
  ];

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Ejecuta la acción seleccionada según el modo activo.
  Future<void> _handleExecution() async {
    final input = _textController.text.trim();
    if (input.isEmpty && _mode != _OwlHubMode.summarize) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _outputResult = null;
      _isError = false;
    });

    try {
      switch (_mode) {
        case _OwlHubMode.webAi:
          await _executeWebAi(input);
        case _OwlHubMode.automate:
          await _executeAutomation(input);
        case _OwlHubMode.summarize:
          await _executeSummarize(input);
        case _OwlHubMode.copy:
          await Clipboard.setData(ClipboardData(text: input));
          if (mounted) setState(() => _outputResult = 'Copiado al portapapeles');
      }
    } catch (e) {
      if (mounted) setState(() { _outputResult = 'Error: $e'; _isError = true; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executeWebAi(String prompt) async {
    final response = await ref.read(browserAiGatewayProvider).query(
      BrowserAiQuery(prompt: prompt, providerId: _provider),
    );
    if (!mounted) return;
    if (response.isCompleted) {
      setState(() { _outputResult = response.content; _isError = false; });
    } else {
      setState(() {
        _outputResult = response.needsUserAction
            ? '🔐 Inicia sesión en ${response.providerId} en el navegador para continuar.'
            : (response.error ?? 'Sin respuesta del proveedor');
        _isError = true;
      });
    }
  }

  Future<void> _executeAutomation(String goal) async {
    final res = await ref.read(automationCoordinatorProvider).execute(
      AutomationGoal(text: goal),
    );
    if (!mounted) return;
    final ok = res.status == AutomationResultStatus.completed ||
        res.status == AutomationResultStatus.completedUnverified;
    setState(() {
      _outputResult = ok ? '✅ ${res.reason}' : '⚠️ ${res.reason}';
      _isError = !ok;
    });
  }

  Future<void> _executeSummarize(String userPrompt) async {
    String contentToSummarize = userPrompt;
    if (contentToSummarize.isEmpty && widget.webViewController != null) {
      final webText = await BrowserContextExtractor.extractFullPageText(
        widget.webViewController!,
      );
      if (webText != null && webText.trim().isNotEmpty) {
        contentToSummarize = webText.trim();
      }
    }
    if (contentToSummarize.isEmpty) {
      setState(() {
        _outputResult = 'Escribe o abre una página web para poder resumir.';
        _isError = true;
      });
      return;
    }
    final prompt = 'Resume de forma clara y ejecutiva el siguiente contenido:\n\n$contentToSummarize';
    await _executeWebAi(prompt);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final maxHeight = media.size.height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: BoxDecoration(
              color: const Color(0xF0081322),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.18), width: 1.2),
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 28, offset: Offset(0, -6)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopHandle(),
                    _buildHeaderBar(),
                    if (widget.activeTab != null) _buildActivePageBadge(),
                    const SizedBox(height: 12),
                    _buildInputArea(),
                    const SizedBox(height: 10),
                    _buildModeSelector(),
                    if (_mode == _OwlHubMode.webAi || _mode == _OwlHubMode.summarize) ...[
                      const SizedBox(height: 8),
                      _buildProviderSelector(),
                    ],
                    const SizedBox(height: 12),
                    _buildSubmitButton(),
                    if (_outputResult != null) ...[
                      const SizedBox(height: 12),
                      _buildResultContainer(),
                    ],
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHandle() => Center(
    child: Container(
      width: 36, height: 4,
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildHeaderBar() => Row(
    children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
        ),
        child: const Center(child: Text('🦉', style: TextStyle(fontSize: 18))),
      ),
      const SizedBox(width: 10),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Búho AI — Asistente Inteligente',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              'Consultas Web AI y automatización activa',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
      IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );

  Widget _buildActivePageBadge() => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Row(
      children: [
        const Icon(Icons.language_rounded, size: 14, color: Color(0xFF38BDF8)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Pestaña: ${widget.activeTab!.title.isNotEmpty ? widget.activeTab!.title : widget.activeTab!.url}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11),
          ),
        ),
        if (widget.webViewController != null)
          GestureDetector(
            onTap: _isLoading ? null : () => _executeSummarize(''),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Resumir', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    ),
  );

  Widget _buildInputArea() => TextField(
    controller: _textController,
    focusNode: _focusNode,
    maxLines: 4, minLines: 2,
    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
    decoration: InputDecoration(
      hintText: _inputHint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.all(12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.4)),
    ),
  );

  String get _inputHint => switch (_mode) {
    _OwlHubMode.webAi => 'Escribe tu consulta para $_provider...',
    _OwlHubMode.automate => 'Ej: Abrir WhatsApp y enviar mensaje a Juan...',
    _OwlHubMode.summarize => 'Pega texto o escribe qué resumir...',
    _OwlHubMode.copy => 'Texto a copiar...',
  };

  Widget _buildModeSelector() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _ModeButton(icon: Icons.language_rounded, label: 'Web AI', color: const Color(0xFF10B981), selected: _mode == _OwlHubMode.webAi, onTap: () => setState(() => _mode = _OwlHubMode.webAi)),
        const SizedBox(width: 6),
        _ModeButton(icon: Icons.bolt_rounded, label: 'Automatizar', color: const Color(0xFFF59E0B), selected: _mode == _OwlHubMode.automate, onTap: () => setState(() => _mode = _OwlHubMode.automate)),
        const SizedBox(width: 6),
        _ModeButton(icon: Icons.summarize_rounded, label: 'Resumir', color: const Color(0xFF38BDF8), selected: _mode == _OwlHubMode.summarize, onTap: () => setState(() => _mode = _OwlHubMode.summarize)),
        const SizedBox(width: 6),
        _ModeButton(icon: Icons.copy_rounded, label: 'Copiar', color: const Color(0xFFA855F7), selected: _mode == _OwlHubMode.copy, onTap: () => setState(() => _mode = _OwlHubMode.copy)),
      ],
    ),
  );

  Widget _buildProviderSelector() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final p in _aiProviders)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(p.$2, style: TextStyle(fontSize: 11, color: _provider == p.$1 ? Colors.white : Colors.white70)),
              selected: _provider == p.$1,
              selectedColor: const Color(0xFF10B981),
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              side: BorderSide(color: _provider == p.$1 ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.1)),
              onSelected: (val) => val ? setState(() => _provider = p.$1) : null,
            ),
          ),
      ],
    ),
  );

  Widget _buildSubmitButton() => SizedBox(
    height: 44,
    child: FilledButton.icon(
      icon: _isLoading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.send_rounded, size: 16),
      label: Text(_isLoading ? 'Procesando...' : 'Ejecutar con Búho AI', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      onPressed: _isLoading ? null : _handleExecution,
    ),
  );

  Widget _buildResultContainer() => Container(
    padding: const EdgeInsets.all(12),
    constraints: const BoxConstraints(maxHeight: 220),
    decoration: BoxDecoration(
      color: _isError ? Colors.amber.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _isError ? Colors.amber.withValues(alpha: 0.35) : const Color(0xFF10B981).withValues(alpha: 0.35)),
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(_outputResult!, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 14),
              label: const Text('Copiar'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF38BDF8), padding: EdgeInsets.zero),
              onPressed: () => Clipboard.setData(ClipboardData(text: _outputResult!)),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({required this.icon, required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? color : Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: selected ? color : Colors.white60),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? color : Colors.white70)),
        ],
      ),
    ),
  );
}
