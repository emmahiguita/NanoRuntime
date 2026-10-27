part of 'engine_status_card.dart';

void _showDetails(
  BuildContext context,
  EngineStatus? engine,
  bool linux,
  WidgetRef ref,
) {
  showNanoGlassWindow<void>(
    context: context,
    builder: (ctx) {
      final colors = NanoThemeExtension.of(ctx).colors;
      final live = engine?.isLive ?? false;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            NanoSpacing.lg,
            0,
            NanoSpacing.lg,
            NanoSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                'Detalles del runtime',
                Icons.terminal_rounded,
                colors: colors,
              ),
              const SizedBox(height: NanoSpacing.sm),
              _detailRow(ctx, 'Fase', engine?.phase.name ?? '—'),
              _detailRow(
                ctx,
                'Modelo',
                engine?.modelPath?.split('/').last ?? '—',
              ),
              _detailRow(ctx, 'Puerto', '${engine?.port ?? 0}'),
              _detailRow(ctx, 'Linux', linux ? 'Instalado' : 'Sin preparar'),
              const SizedBox(height: NanoSpacing.md),
              Wrap(
                spacing: NanoSpacing.sm,
                runSpacing: NanoSpacing.sm,
                children: [
                  if (live)
                    FilledButton.icon(
                      onPressed: () =>
                          ref.read(runtimeEngineProvider.notifier).stop(),
                      icon: const Icon(Icons.power_settings_new_rounded),
                      label: const Text('Apagar'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () =>
                          ref.read(runtimeEngineProvider.notifier).start(),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Encender'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _restart(ref),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reiniciar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _restart(WidgetRef ref) async {
  final notifier = ref.read(runtimeEngineProvider.notifier);
  await notifier.stop();
  await notifier.start();
}

Widget _detailRow(BuildContext context, String label, String value) {
  final colors = NanoThemeExtension.of(context).colors;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: NanoType.label(colors.onSurfaceVariant)),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: NanoType.body(colors.onSurface),
          ),
        ),
      ],
    ),
  );
}
