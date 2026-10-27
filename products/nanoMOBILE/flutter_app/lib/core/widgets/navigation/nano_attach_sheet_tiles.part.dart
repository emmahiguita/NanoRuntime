part of 'nano_attach_sheet.dart';

class _AiInjectSection extends StatelessWidget {
  const _AiInjectSection();

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      _AiInjectTile(
        label: 'ChatGPT',
        command: '@chatgpt ',
        icon: Icons.smart_toy_rounded,
        accentColor: Color(0xFF10A37F),
      ),
      _AiInjectTile(
        label: 'Gemini',
        command: '@gemini ',
        icon: Icons.auto_awesome_rounded,
        accentColor: Color(0xFF38BDF8),
      ),
      _AiInjectTile(
        label: 'DeepSeek',
        command: '@deepseek ',
        icon: Icons.explore_rounded,
        accentColor: Color(0xFF2563EB),
      ),
      _AiInjectTile(
        label: 'Claude',
        command: '@claude ',
        icon: Icons.lightbulb_rounded,
        accentColor: Color(0xFFD97706),
      ),
    ],
  );
}

class _CommandInjectSection extends StatelessWidget {
  const _CommandInjectSection();

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      _CommandTile(
        title: 'Diagnóstico MCP',
        subtitle: '@mcp call device.diagnostics',
        command: '@mcp call device.diagnostics',
        icon: Icons.phonelink_setup_rounded,
      ),
      _CommandTile(
        title: 'Git Status',
        subtitle: '@git status',
        command: '@git status',
        icon: Icons.account_tree_rounded,
      ),
      _CommandTile(
        title: 'Búsqueda Web',
        subtitle: '@buscar <consulta>',
        command: '@buscar ',
        icon: Icons.travel_explore_rounded,
      ),
      _CommandTile(
        title: 'Resumen Apps',
        subtitle: '@mcp call device.app_summary',
        command: '@mcp call device.app_summary',
        icon: Icons.apps_rounded,
      ),
    ],
  );
}

class _FileAttachSection extends StatelessWidget {
  const _FileAttachSection();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _FileTile(
          icon: Icons.photo_camera_outlined,
          title: 'Cámara',
          color: const Color(0xFF38BDF8),
          onTap: () => Navigator.of(context).pop(NanoAttachKind.photo),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: _FileTile(
          icon: Icons.audiotrack_outlined,
          title: 'Audio',
          color: const Color(0xFF818CF8),
          onTap: () => Navigator.of(context).pop(NanoAttachKind.audio),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: _FileTile(
          icon: Icons.videocam_outlined,
          title: 'Video',
          color: const Color(0xFFEC4899),
          onTap: () => Navigator.of(context).pop(NanoAttachKind.video),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: _FileTile(
          icon: Icons.description_outlined,
          title: 'Documento',
          color: const Color(0xFF10B981),
          onTap: () => Navigator.of(context).pop(NanoAttachKind.document),
        ),
      ),
    ],
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Row(
      children: [
        Icon(icon, size: 12, color: colors.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            color: colors.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _AiInjectTile extends StatelessWidget {
  const _AiInjectTile({
    required this.label,
    required this.command,
    required this.icon,
    required this.accentColor,
  });
  final String label, command;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is! NanoLightColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pop(command);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: isDark ? 0.14 : 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.30 : 0.24),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accentColor, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: colors.onSurface,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
