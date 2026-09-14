import 'package:flutter/material.dart';
import '../../terminal_types.dart';

class TerminalOutputView extends StatelessWidget {
  final List<TL> lines;
  final ScrollController scrollController;
  final Color Function(Ln type) colorMapper;
  final TextStyle baseStyle;

  const TerminalOutputView({
    super.key,
    required this.lines,
    required this.scrollController,
    required this.colorMapper,
    required this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: lines.length,
      itemBuilder: (context, i) {
        final line = lines[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            line.text,
            style: baseStyle.copyWith(color: colorMapper(line.type)),
          ),
        );
      },
    );
  }
}
