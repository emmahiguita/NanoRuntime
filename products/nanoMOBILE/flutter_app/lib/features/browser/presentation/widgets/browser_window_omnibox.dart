import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/browser/domain/browser_url_resolver.dart';

/// Barra de direcciones Omnibox Material Expressive 3 para el navegador móvil.
/// 
/// - QUÉ HACE: Presenta la URL estilizada como píldora ergonómica interactiva.
///   Al tocarla, pasa a modo edición en vivo con selección total y botón 'Go'.
/// - CÓMO FUNCIONA: Gestiona [TextEditingController] y [FocusNode] locales;
///   despacha [onSubmitted] con la URL sanitizada y resuelve esquemas faltantes.
/// - POR QUÉ: Sustituye modales obstructivos por una barra moderna integrada (<200 líneas).
class BrowserWindowOmnibox extends StatefulWidget {
  final String url, title;
  final Color siteColor;
  final bool isLandscape;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onReload;
  final VoidCallback? onZoom;

  const BrowserWindowOmnibox({
    super.key, required this.url, required this.title, required this.siteColor,
    required this.isLandscape, required this.onSubmitted, required this.onReload, this.onZoom,
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
      if (!_focusNode.hasFocus && _isEditing && mounted) setState(() => _isEditing = false);
    });
  }

  @override
  void didUpdateWidget(covariant BrowserWindowOmnibox old) {
    super.didUpdateWidget(old);
    if (!_isEditing && widget.url != old.url) _controller.text = widget.url;
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
    if (text.isNotEmpty) widget.onSubmitted(BrowserUrlResolver.resolveUrl(text));
    setState(() => _isEditing = false);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isLand = widget.isLandscape;
    final isHttps = widget.url.startsWith('https://');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: isLand ? 28 : 36,
      padding: EdgeInsets.symmetric(horizontal: isLand ? 6 : 10),
      decoration: BoxDecoration(
        color: _isEditing ? const Color(0xFF0F1E2E) : const Color(0xFF0A1520),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isEditing ? widget.siteColor : const Color(0xFF1E3A4A).withValues(alpha: 0.6),
          width: _isEditing ? 1.4 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isEditing ? Icons.search_rounded : (isHttps ? Icons.lock_rounded : Icons.lock_open_rounded),
            color: _isEditing ? widget.siteColor : (isHttps ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
            size: isLand ? 12 : 14,
          ),
          const SizedBox(width: 6),
          Expanded(child: _isEditing ? _buildInput(isLand) : _buildLabel(isLand)),
          if (_isEditing) ...[
            if (_controller.text.isNotEmpty)
              _Btn(label: 'Borrar', icon: Icons.cancel_rounded, size: isLand ? 12 : 15, color: const Color(0xFF94A3B8), onTap: () => setState(() => _controller.clear())),
            const SizedBox(width: 4),
            _Btn(label: 'Ir', icon: Icons.arrow_forward_rounded, size: isLand ? 11 : 13, color: Colors.white, bg: widget.siteColor, onTap: _submit),
          ] else ...[
            if (widget.onZoom != null)
              _ZoomBtn(isLandscape: isLand, onTap: widget.onZoom!),
            _Btn(label: 'Recargar', icon: Icons.refresh_rounded, size: isLand ? 13 : 16, color: const Color(0xFF94A3B8), onTap: widget.onReload),
          ],
        ],
      ),
    );
  }

  Widget _buildInput(bool isLand) => TextField(
    controller: _controller, focusNode: _focusNode,
    textInputAction: TextInputAction.go, onSubmitted: (_) => _submit(),
    style: TextStyle(color: Colors.white, fontSize: isLand ? 11.0 : 13.0, fontWeight: FontWeight.w500),
    decoration: InputDecoration(
      isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none,
      hintText: 'Buscar o escribir dirección web…',
      hintStyle: TextStyle(color: const Color(0xFF64748B), fontSize: isLand ? 10.5 : 12.5),
    ),
  );

  Widget _buildLabel(bool isLand) {
    final display = widget.url.isEmpty ? 'Buscar o escribir URL…' : widget.url.replaceAll(RegExp(r'^https?://'), '');
    return InkWell(
      onTap: _startEditing, borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          display, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: widget.url.isEmpty ? const Color(0xFF64748B) : Colors.white, fontSize: isLand ? 10.5 : 12.5, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final double size;
  final Color color;
  final Color? bg;
  final VoidCallback onTap;

  const _Btn({required this.label, required this.icon, required this.size, required this.color, this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    label: label, button: true,
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: bg != null ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2) : const EdgeInsets.all(3),
        decoration: bg != null ? BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)) : null,
        child: Icon(icon, size: size, color: color),
      ),
    ),
  );
}

class _ZoomBtn extends StatelessWidget {
  final bool isLandscape;
  final VoidCallback onTap;
  const _ZoomBtn({required this.isLandscape, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Ajustar zoom', button: true,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(6)),
        child: Text('aA', style: TextStyle(color: const Color(0xFFCBD5E1), fontSize: isLandscape ? 8.5 : 10.5, fontWeight: FontWeight.bold)),
      ),
    ),
  );
}
