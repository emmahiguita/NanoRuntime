import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/browser/domain/browser_url_resolver.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_site_theme.dart';

/// Editor y visualizador en línea de URL para la cabecera de ventana de navegador.
/// 
/// - QUÉ HACE: Visualiza el título/URL y al tocarlo se transforma en campo editable directo.
/// - CÓMO FUNCIONA: Usa [TextEditingController] y [FocusNode] locales; al enviar, sanitiza
///   la URL con [BrowserUrlResolver] y emite [onSubmitted].
/// - POR QUÉ: Permite navegación directa en tarjeta sin diálogos modales (<200 líneas).
class BrowserWindowUrlEditor extends StatefulWidget {
  final String title, url;
  final Color siteColor;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onToggleEdit;

  const BrowserWindowUrlEditor({
    super.key, required this.title, required this.url, required this.siteColor,
    required this.onSubmitted, this.onToggleEdit,
  });

  @override
  State<BrowserWindowUrlEditor> createState() => _BrowserWindowUrlEditorState();
}

class _BrowserWindowUrlEditorState extends State<BrowserWindowUrlEditor> {
  bool _isEditing = false;
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.url);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant BrowserWindowUrlEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.url != oldWidget.url) _textController.text = widget.url;
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    HapticFeedback.lightImpact();
    setState(() {
      _isEditing = true;
      _textController.text = widget.url;
      _textController.selection = TextSelection(baseOffset: 0, extentOffset: _textController.text.length);
    });
    _focusNode.requestFocus();
    widget.onToggleEdit?.call();
  }

  void _cancelEditing() {
    setState(() { _isEditing = false; _textController.text = widget.url; });
    _focusNode.unfocus();
    widget.onToggleEdit?.call();
  }

  void _submitUrl() {
    final rawText = _textController.text.trim();
    if (rawText.isNotEmpty) widget.onSubmitted(BrowserUrlResolver.resolveUrl(rawText));
    setState(() => _isEditing = false);
    _focusNode.unfocus();
    widget.onToggleEdit?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;

    if (_isEditing) {
      return Container(
        height: isLand ? 24 : 32,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.siteColor.withValues(alpha: 0.8), width: 1.2),
        ),
        child: Row(children: [
          const SizedBox(width: 6),
          Icon(Icons.link_rounded, size: isLand ? 12 : 14, color: widget.siteColor),
          const SizedBox(width: 4),
          Expanded(child: TextField(
            controller: _textController, focusNode: _focusNode, textInputAction: TextInputAction.go, onSubmitted: (_) => _submitUrl(),
            style: TextStyle(fontSize: isLand ? 10.5 : 11.5, color: Colors.white, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4), border: InputBorder.none,
              hintText: 'Escribir URL o buscar...', hintStyle: TextStyle(fontSize: isLand ? 9.5 : 11.0, color: const Color(0xFF64748B)),
            ),
          )),
          if (_textController.text.isNotEmpty)
            _IconBtn(label: 'Borrar texto', icon: Icons.clear_rounded, size: isLand ? 12 : 14, color: const Color(0xFF94A3B8), onTap: () => setState(() => _textController.clear())),
          _IconBtn(label: 'Navegar', icon: Icons.arrow_forward_rounded, size: isLand ? 11 : 13, color: Colors.white, bg: widget.siteColor, onTap: _submitUrl),
          _IconBtn(label: 'Cancelar', icon: Icons.close_rounded, size: isLand ? 12 : 14, color: const Color(0xFF64748B), onTap: _cancelEditing),
        ]),
      );
    }

    return InkWell(
      onTap: _startEditing, borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: Row(children: [
          BrowserSiteTheme.buildFavicon(widget.url, siteColor: widget.siteColor, size: isLand ? 15 : 18),
          SizedBox(width: isLand ? 5 : 8),
          Expanded(child: Column(
            mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title.isNotEmpty ? widget.title : 'Navegador',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: isLand ? 10.0 : 11.5, height: 1.15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 1),
              Row(children: [
                Container(width: 3.5, height: 3.5, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.siteColor)),
                const SizedBox(width: 4),
                Expanded(child: Text(
                  widget.url.isNotEmpty ? widget.url : 'Toca para escribir URL',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: isLand ? 8.5 : 9.5, height: 1.15, color: const Color(0xFF94A3B8)),
                )),
                Icon(Icons.edit_rounded, size: isLand ? 9 : 11, color: const Color(0xFF64748B)),
              ]),
            ],
          )),
        ]),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final double size;
  final Color color;
  final Color? bg;
  final VoidCallback onTap;

  const _IconBtn({required this.label, required this.icon, required this.size, required this.color, this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    label: label, button: true,
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: bg != null ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3) : const EdgeInsets.all(4),
        decoration: bg != null ? BoxDecoration(color: bg!.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(6), border: Border.all(color: bg!, width: 0.8)) : null,
        child: Icon(icon, size: size, color: color),
      ),
    ),
  );
}
