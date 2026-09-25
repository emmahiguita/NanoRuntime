import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/browser/domain/browser_url_resolver.dart';

/// Barra de direcciones Omnibox profesional y limpia para el navegador móvil.
/// 
/// - QUÉ HACE: Presenta la URL/búsqueda con indicador de seguridad SSL, dominio limpio,
///   barra de progreso de carga y botón de recargar/detener sin saturación ni botones invasivos.
/// - CÓMO FUNCIONA: Al tocar, activa edición con selección total de la URL y teclado 'Go'.
/// - POR QUÉ: Diseño sobrio, profesional, de máxima legibilidad y sin elementos infantiles.
class BrowserWindowOmnibox extends StatefulWidget {
  final String url, title;
  final Color siteColor;
  final bool isLandscape, isLoading;
  final double progress;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onReload;
  final VoidCallback? onStop;

  const BrowserWindowOmnibox({
    super.key,
    required this.url,
    required this.title,
    required this.siteColor,
    required this.isLandscape,
    required this.onSubmitted,
    required this.onReload,
    this.isLoading = false,
    this.progress = 1.0,
    this.onStop,
  });

  @override
  State<BrowserWindowOmnibox> createState() => _BrowserWindowOmniboxState();
}

class _BrowserWindowOmniboxState extends State<BrowserWindowOmnibox> {
  bool _isEditing = false;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.url);
    _focusNode = FocusNode()..addListener(() {
      if (!_focusNode.hasFocus && _isEditing && mounted) {
        setState(() => _isEditing = false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant BrowserWindowOmnibox old) {
    super.didUpdateWidget(old);
    if (!_isEditing && widget.url != old.url) {
      _controller.text = widget.url;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    HapticFeedback.selectionClick();
    setState(() {
      _isEditing = true;
      _controller.text = widget.url;
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    });
    _focusNode.requestFocus();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSubmitted(BrowserUrlResolver.resolveUrl(text));
    }
    setState(() => _isEditing = false);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isLand = widget.isLandscape;
    final isHttps = widget.url.startsWith('https://');
    const emeraldAccent = Color(0xFF10B981);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: isLand ? 30 : 38,
      padding: EdgeInsets.symmetric(horizontal: isLand ? 8 : 12),
      decoration: BoxDecoration(
        color: _isEditing ? const Color(0xFF0F1B2C) : const Color(0xFF0B1420),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isEditing ? emeraldAccent : const Color(0xFF1E2D3D),
          width: _isEditing ? 1.2 : 1.0,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              Icon(
                _isEditing
                    ? Icons.search_rounded
                    : (isHttps ? Icons.lock_rounded : Icons.lock_open_rounded),
                color: _isEditing
                    ? emeraldAccent
                    : (isHttps ? emeraldAccent : const Color(0xFF94A3B8)),
                size: isLand ? 13 : 15,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _isEditing ? _buildInput(isLand) : _buildLabel(isLand),
              ),
              if (_isEditing) ...[
                if (_controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _controller.clear()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.cancel_rounded,
                        size: isLand ? 14 : 16,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
              ] else ...[
                GestureDetector(
                  onTap: widget.isLoading
                      ? (widget.onStop ?? widget.onReload)
                      : widget.onReload,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      widget.isLoading ? Icons.close_rounded : Icons.refresh_rounded,
                      size: isLand ? 14 : 17,
                      color: widget.isLoading ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (widget.isLoading && widget.progress < 1.0)
            Positioned(
              left: 4,
              right: 4,
              bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: widget.progress.clamp(0.05, 1.0),
                  minHeight: 2.0,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(emeraldAccent),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInput(bool isLand) => TextField(
    controller: _controller,
    focusNode: _focusNode,
    textInputAction: TextInputAction.go,
    onSubmitted: (_) => _submit(),
    style: TextStyle(
      color: Colors.white,
      fontSize: isLand ? 11.5 : 13.5,
      fontWeight: FontWeight.w500,
    ),
    decoration: InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.zero,
      border: InputBorder.none,
      hintText: 'Buscar o escribir dirección web…',
      hintStyle: TextStyle(
        color: const Color(0xFF64748B),
        fontSize: isLand ? 11.0 : 13.0,
      ),
    ),
  );

  Widget _buildLabel(bool isLand) {
    final display = widget.url.isEmpty
        ? 'Buscar o escribir URL…'
        : widget.url.replaceAll(RegExp(r'^https?://'), '');
    return InkWell(
      onTap: _startEditing,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          display,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: widget.url.isEmpty ? const Color(0xFF64748B) : const Color(0xFFF1F5F9),
            fontSize: isLand ? 11.0 : 13.0,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
