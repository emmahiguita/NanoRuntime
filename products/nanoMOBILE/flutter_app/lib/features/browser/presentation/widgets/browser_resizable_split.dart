// QUÉ: distribuye dos WebViews en horizontal con un separador ajustable.
// CÓMO: cambia solo sus anchos; ninguna superficie nativa se desmonta.
// POR QUÉ: el modo horizontal aprovecha el ancho y conserva audio/sesión.

import 'package:flutter/material.dart';

class BrowserResizableSplit extends StatefulWidget {
  final Widget left, right;
  const BrowserResizableSplit({
    super.key,
    required this.left,
    required this.right,
  });

  @override
  State<BrowserResizableSplit> createState() => _BrowserResizableSplitState();
}

class _BrowserResizableSplitState extends State<BrowserResizableSplit> {
  static const _dividerWidth = 18.0;
  double _leftFraction = 0.5;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final available = (constraints.maxWidth - _dividerWidth).clamp(
        1.0,
        double.infinity,
      );
      return Row(
        children: [
          SizedBox(width: available * _leftFraction, child: widget.left),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () => setState(() => _leftFraction = 0.5),
            onHorizontalDragUpdate: (details) => setState(() {
              _leftFraction = (_leftFraction + details.delta.dx / available)
                  .clamp(0.22, 0.78);
            }),
            child: SizedBox(
              width: _dividerWidth,
              child: Center(
                child: Container(
                  width: 3,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: widget.right),
        ],
      );
    },
  );
}
