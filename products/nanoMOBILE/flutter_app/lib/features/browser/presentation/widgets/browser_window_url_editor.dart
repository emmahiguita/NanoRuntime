import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/browser/domain/browser_url_resolver.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_site_theme.dart';

/// Editor y visualizador en línea de URL para la cabecera de ventana de navegador.
/// 
/// - QUÉ HACE: Visualiza el título/URL y al tocarlo se transforma en campo editable directo.
/// - CÓMO FUNCIONA: Ocupa el 100% del espacio disponible sin botones apiñados ni píldoras que recorten el texto.
/// - POR QUÉ: Diseño profesional, limpio y legible (<120 líneas).
class BrowserWindowUrlEditor extends StatefulWidget {
  final String title, url;
  final Color siteColor;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onToggleEdit;

  const BrowserWindowUrlEditor({
    super.key,
    required this.title,
    required this.url,
    required this.siteColor,
    required this.onSubmitted,
    this.onToggleEdit,
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
    _focusNode = FocusNode()..addListener(() {
      if (!_focusNode.hasFocus && _isEditing && mounted) {
        setState(() => _isEditing = false);
        widget.onToggleEdit?.call();
      }
    });
  }

  @override
  void didUpdateWidget(covariant BrowserWindowUrlEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.url != oldWidget.url) {
      _textController.text = widget.url;
    }
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
    setState(() {
      _isEditing = false;
      _textController.text = widget.url;
    });
    _focusNode.unfocus();
    widget.onToggleEdit?.call();
  }

  void _submitUrl() {
    final rawText = _textController.text.trim();
    if (rawText.isNotEmpty) {
      widget.onSubmitted(BrowserUrlResolver.resolveUrl(rawText));
    }
    setState(() => _isEditing = false);
    _focusNode.unfocus();
    widget.onToggleEdit?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;

    if (_isEditing) {
      return Container(
        height: isLand ? 26 : 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1B2C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF10B981), width: 1.0),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 14, color: Color(0xFF10B981)),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _submitUrl(),
                style: TextStyle(
                  fontSize: isLand ? 11.0 : 12.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: 'Escribir URL o buscar...',
                  hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ),
            ),
            if (_textController.text.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _textController.clear()),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.cancel_rounded, size: 14, color: Color(0xFF64748B)),
                ),
              ),
            GestureDetector(
              onTap: _submitUrl,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.arrow_forward_rounded, size: 15, color: Color(0xFF10B981)),
              ),
            ),
            GestureDetector(
              onTap: _cancelEditing,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.close_rounded, size: 14, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      );
    }

    final displayHost = Uri.tryParse(widget.url)?.host;
    final displaySub = (displayHost != null && displayHost.isNotEmpty) ? displayHost : widget.url;

    return InkWell(
      onTap: _startEditing,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            BrowserSiteTheme.buildFavicon(widget.url, siteColor: widget.siteColor, size: isLand ? 15 : 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title.isNotEmpty ? widget.title : 'Navegador',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isLand ? 10.5 : 12.0,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    displaySub.isNotEmpty ? displaySub : 'Toca para escribir URL',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isLand ? 9.0 : 10.5,
                      height: 1.15,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.edit_rounded, size: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
