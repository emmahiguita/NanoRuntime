part of 'automation_dashboard.dart';

class _AgentHeader extends StatelessWidget {
  const _AgentHeader({
    required this.mode,
    required this.onModeTap,
    this.onDevTap,
    this.onVoiceOutputTap,
    this.isVoiceOutputEnabled = false,
    this.onConversationTap,
    this.isConversationActive = false,
    this.isRunning = false,
  });
  final AgentAutomationMode mode;
  final VoidCallback onModeTap;
  final VoidCallback? onDevTap;
  final VoidCallback? onVoiceOutputTap;
  final bool isVoiceOutputEnabled;
  final VoidCallback? onConversationTap;
  final bool isConversationActive;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    // UI-REV-02: cabecera compacta estilo Dev — título de pantalla (18px,
    // mismo patrón de NanoScreenShell) en vez de la marca gigante de 30px.
    // Mascota Nano Owl integrada en cabecera con máquina de estados orgánica.
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          NanoOwlAvatar(
            size: 34,
            state: isConversationActive
                ? NanoOwlState.listening
                : (isRunning ? NanoOwlState.thinking : NanoOwlState.idle),
            onTap: onConversationTap,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                const Flexible(
                  child: Text(
                    'Automatización',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                    side: BorderSide(
                      color: visual.accent.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: onModeTap,
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: visual.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        mode.label,
                        style: TextStyle(
                          color: visual.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onVoiceOutputTap != null)
            IconButton(
              tooltip: isVoiceOutputEnabled
                  ? 'Silenciar audio de Nano'
                  : 'Activar audio de Nano',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(5),
              constraints: const BoxConstraints(),
              onPressed: onVoiceOutputTap,
              icon: Icon(
                isVoiceOutputEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: isVoiceOutputEnabled
                    ? visual.accent
                    : (visual.isDark
                          ? Colors.white.withValues(alpha: 0.85)
                          : visual.textMuted),
                size: 20,
              ),
            ),
          if (onConversationTap != null)
            IconButton(
              tooltip: isConversationActive
                  ? 'Detener conversación'
                  : 'Conversación manos libres',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(5),
              constraints: const BoxConstraints(),
              onPressed: onConversationTap,
              icon: Icon(
                isConversationActive
                    ? Icons.record_voice_over_rounded
                    : Icons.voice_chat_outlined,
                color: isConversationActive
                    ? visual.accent
                    : (visual.isDark
                          ? Colors.white.withValues(alpha: 0.85)
                          : visual.textMuted),
                size: 20,
              ),
            ),
          if (onDevTap != null)
            IconButton(
              tooltip: 'Herramientas del agente',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(5),
              constraints: const BoxConstraints(),
              onPressed: onDevTap,
              icon: Icon(
                Icons.smart_toy_outlined,
                color: visual.accent,
                size: 21,
              ),
            ),
        ],
      ),
    );
  }
}

String _describeSituation(CurrentSituation situation) {
  final surface = switch (situation.surfaceKind) {
    CurrentSurfaceKind.dialog => 'diálogo',
    CurrentSurfaceKind.search => 'búsqueda',
    CurrentSurfaceKind.editable => 'campo editable',
    CurrentSurfaceKind.picker => 'selección',
    CurrentSurfaceKind.collection => 'lista',
    CurrentSurfaceKind.mediaViewer => 'visor multimedia',
    CurrentSurfaceKind.content => 'contenido',
    CurrentSurfaceKind.unknown => 'superficie sin clasificar',
  };
  final completeness = situation.isComplete ? '' : ' · lectura parcial';
  return 'Ojos activos · $surface · ${situation.packageName}$completeness';
}

/// Presentación HONESTA de un estado de ejecución: la etiqueta es la fuente
/// de verdad. `completed` = Verificado (verde). `completedUnverified` jamás
/// se pinta como éxito: es "Completado sin verificar" (ámbar).
({IconData icon, Color color, String label}) _statusPresentation(
  AutomationResultStatus s,
  NanoColors colors,
) {
  switch (s) {
    case AutomationResultStatus.completed:
      return (
        icon: Icons.check_circle_rounded,
        color: colors.success,
        label: 'Verificado',
      );
    case AutomationResultStatus.completedUnverified:
      return (
        icon: Icons.report_problem_rounded,
        color: colors.warning,
        label: 'Completado sin verificar',
      );
    case AutomationResultStatus.paused:
      return (
        icon: Icons.pause_circle_outline_rounded,
        color: colors.warning,
        label: 'Esperando confirmación',
      );
    case AutomationResultStatus.denied:
      return (
        icon: Icons.block_rounded,
        color: colors.warning,
        label: 'Denegado por política',
      );
    case AutomationResultStatus.noPlan:
      return (
        icon: Icons.error_outline_rounded,
        color: colors.warning,
        label: 'Sin plan',
      );
    case AutomationResultStatus.failed:
      return (
        icon: Icons.cancel_rounded,
        color: colors.error,
        label: 'No completado',
      );
    case AutomationResultStatus.outcomeUnknown:
      return (
        icon: Icons.help_outline_rounded,
        color: colors.warning,
        label: 'Resultado desconocido',
      );
    case AutomationResultStatus.cancelled:
      return (
        icon: Icons.not_interested_rounded,
        color: colors.onSurfaceVariant,
        label: 'Cancelado',
      );
  }
}

class _ActiveExecutionCard extends StatefulWidget {
  const _ActiveExecutionCard({
    required this.goal,
    required this.running,
    required this.status,
    required this.reason,
    this.onConfirm,
  });
  final String goal;
  final bool running;
  final AutomationResultStatus? status;
  final String reason;
  final VoidCallback? onConfirm;

  @override
  State<_ActiveExecutionCard> createState() => _ActiveExecutionCardState();
}

class _ActiveExecutionCardState extends State<_ActiveExecutionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.running) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ActiveExecutionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.running && !oldWidget.running) {
      _pulse.repeat(reverse: true);
    } else if (!widget.running && oldWidget.running) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final done = !widget.running && widget.status != null;
    final present = done ? _statusPresentation(widget.status!, colors) : null;
    final activeColor = present?.color ?? AutomationVisual.of(context).accent;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: widget.running
              ? [
                  BoxShadow(
                    color: activeColor.withValues(
                      alpha: 0.10 + _pulse.value * 0.18,
                    ),
                    blurRadius: 14 + _pulse.value * 14,
                    spreadRadius: _pulse.value * 1.5,
                  ),
                ]
              : const [],
        ),
        child: child,
      ),
      child: AutomationSurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: activeColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.20),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    present?.icon ?? Icons.auto_awesome_rounded,
                    color: activeColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: NanoSpacing.sm),
                Expanded(
                  child: Text(
                    widget.goal,
                    maxLines: 4,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NanoSpacing.sm),
            AnimatedSwitcher(
              duration: NanoMotionDurations.quick,
              child: Text(
                widget.running
                    ? 'Ejecutando en el dispositivo…'
                    : (present?.label ?? ''),
                key: ValueKey('${widget.running}-${widget.status}'),
                style: NanoType.label(
                  present?.color ?? colors.onSurfaceVariant,
                ),
              ),
            ),
            if (!widget.running && widget.reason.trim().isNotEmpty) ...[
              const SizedBox(height: NanoSpacing.xs),
              Text(
                widget.reason.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: NanoType.caption(colors.onSurfaceVariant),
              ),
            ],
            if (widget.onConfirm != null) ...[
              const SizedBox(height: NanoSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: widget.onConfirm,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Confirmar y continuar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Atajos de tareas comunes → runGoal(preset).
class QuickAutomationActions extends StatelessWidget {
  const QuickAutomationActions({
    super.key,
    required this.onRun,
    this.onMessagesTap,
    this.onSettingsTap,
    this.onRulesTap,
    this.onBusinessTap,
    this.onPersonalAgentTap,
    this.onSkillsMcpTap,
    this.onTimeRuleTap,
    this.suppressSuggestions = false,
    this.pendingDraftsCount = 0,
    this.activeRulesCount = 0,
    this.businessProductsCount = 0,
  });
  final ValueChanged<String> onRun;
  final bool suppressSuggestions;
  final int pendingDraftsCount;
  final int activeRulesCount;
  final int businessProductsCount;

  /// Abre la pantalla de Mensajes (función de usuario, destacada).
  final VoidCallback? onMessagesTap;

  /// Abre la configuración del agente. Vive aquí como tile con TEXTO visible
  /// (UI-REV-05) — el icono suelto de la cabecera estorbaba y era poco claro.
  final VoidCallback? onSettingsTap;

  /// RULES-CREATE-02 — abre la pantalla de Reglas (antes solo desde Ajustes).
  final VoidCallback? onRulesTap;

  /// Acceso directo a WhatsApp Negocio y catálogo comercial.
  final VoidCallback? onBusinessTap;

  /// Acceso directo a la pantalla dedicada del Agente Personal de WhatsApp.
  final VoidCallback? onPersonalAgentTap;

  /// Acceso directo al Hub visual de MCP & Skills.
  final VoidCallback? onSkillsMcpTap;

  /// RULES-CREATE-02 — crea regla por hora con reloj del sistema + mensaje.
  final VoidCallback? onTimeRuleTap;

  static const _actions = [
    ('Abrir Bluetooth', 'abrir Bluetooth', NanoGlyphType.bluetooth),
    ('Abrir Chrome', 'abrir Chrome', NanoGlyphType.browser),
    ('Abrir Linux', 'abrir la terminal Linux', NanoGlyphType.linux),
    (
      'Leer notificaciones',
      'leer las notificaciones',
      NanoGlyphType.notification,
    ),
    ('Analizar archivos', 'analizar los archivos', NanoGlyphType.files),
  ];

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onSettingsTap != null ||
            onMessagesTap != null ||
            onRulesTap != null ||
            onBusinessTap != null ||
            onPersonalAgentTap != null ||
            onSkillsMcpTap != null ||
            onTimeRuleTap != null) ...[
          const AutomationSectionLabel('Accesos'),
          if (onBusinessTap != null)
            _DashboardEntryTile(
              featherType: FeatherCoreType.whatsappBusiness,
              title: 'WhatsApp Negocio',
              subtitle: businessProductsCount > 0
                  ? '$businessProductsCount producto${businessProductsCount == 1 ? '' : 's'} · Catálogo activo'
                  : 'Catálogo comercial, ventas y pagos',
              badge: businessProductsCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: visual.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$businessProductsCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
              onTap: onBusinessTap!,
            ),
          if (onPersonalAgentTap != null)
            _DashboardEntryTile(
              featherType: FeatherCoreType.personalAgent,
              title: 'Agente Personal WPP',
              subtitle: 'Respuestas personales, tono y calidez',
              onTap: onPersonalAgentTap!,
            ),
          if (onRulesTap != null)
            _DashboardEntryTile(
              featherType: FeatherCoreType.rules,
              title: 'Reglas',
              subtitle: activeRulesCount > 0
                  ? '$activeRulesCount activa${activeRulesCount == 1 ? '' : 's'} · Automatizaciones'
                  : 'Todas tus automatizaciones',
              onTap: onRulesTap!,
            ),
          if (onSkillsMcpTap != null)
            _DashboardEntryTile(
              featherType: FeatherCoreType.models,
              title: 'Hub de MCP & Skills',
              subtitle: 'Grafo vivo, telemetría y tienda de plugins',
              onTap: onSkillsMcpTap!,
            ),
          if (onTimeRuleTap != null)
            _DashboardEntryTile(
              featherType: FeatherCoreType.calendar,
              title: 'Aviso por hora',
              subtitle: 'Crear un recordatorio con reloj',
              onTap: onTimeRuleTap!,
            ),
          if (onSettingsTap != null)
            _DashboardEntryTile(
              featherType: FeatherCoreType.settings,
              title: 'Configuración',
              subtitle: 'Modo, razonamiento, audio y permisos',
              onTap: onSettingsTap!,
            ),
          if (onMessagesTap != null)
            _DashboardEntryTile(
              featherType: FeatherCoreType.notifications,
              title: 'Centro de Mensajería',
              subtitle: pendingDraftsCount > 0
                  ? '$pendingDraftsCount borrador${pendingDraftsCount == 1 ? '' : 'es'} pendiente${pendingDraftsCount == 1 ? '' : 's'}'
                  : 'WhatsApp, Telegram, Gmail, Slack y más',
              badge: pendingDraftsCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: visual.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingDraftsCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
              onTap: onMessagesTap!,
            ),
          const SizedBox(height: 16),
        ],
        AutomationSuggestionCarousel(
          suppressed: suppressSuggestions,
          suggestions: [
            for (final (label, goal, glyph) in _actions)
              AutomationSuggestion(
                label: label,
                leading: NanoIcon(
                  type: glyph,
                  size: 20,
                  color: AutomationVisual.of(context).accent,
                ),
                onSelected: () => onRun(goal),
              ),
          ],
        ),
      ],
    );
  }
}

/// Entrada destacada a una pantalla hermana del dashboard (Mensajes, Dev).
/// Un solo widget para todos los accesos: icono + título + subtítulo + badge opcional.
class _DashboardEntryTile extends StatelessWidget {
  const _DashboardEntryTile({
    this.icon,
    this.glyph,
    this.imageAsset,
    this.featherType,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  }) : assert(
         icon != null ||
             glyph != null ||
             imageAsset != null ||
             featherType != null,
       );

  final IconData? icon;
  final NanoGlyphType? glyph;
  final String? imageAsset;
  final FeatherCoreType? featherType;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? badge;

  Widget _buildLeading(BuildContext context) {
    if (featherType != null) {
      return FeatherCoreIcon(
        type: featherType!,
        size: 36,
        accentColor: AutomationVisual.of(context).accent,
      );
    }
    if (imageAsset != null && imageAsset!.contains('whatsapp_business')) {
      return FeatherCoreIcon(
        type: FeatherCoreType.whatsappBusiness,
        size: 36,
        accentColor: AutomationVisual.of(context).accent,
      );
    }
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AutomationVisual.of(context).accent.withValues(
          alpha: AutomationVisual.of(context).isDark ? 0.16 : 0.10,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AutomationVisual.of(context).accent.withValues(
            alpha: AutomationVisual.of(context).isDark ? 0.30 : 0.22,
          ),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AutomationVisual.of(context).accent.withValues(alpha: 0.10),
            blurRadius: 6,
          ),
        ],
      ),
      child: imageAsset != null
          ? Padding(
              padding: const EdgeInsets.all(3),
              child: Image.asset(
                imageAsset!,
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
            )
          : glyph != null
          ? NanoIcon(
              type: glyph!,
              size: 18,
              color: AutomationVisual.of(context).accent,
            )
          : Icon(icon!, color: AutomationVisual.of(context).accent, size: 18),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AutomationSurfaceCard(
      padding: EdgeInsets.zero,
      radius: 16,
      onTap: onTap,
      // UI-REV-02: tile compacto estilo iOS (min 52px) — altura fluida.
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            _buildLeading(context),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AutomationVisual.of(context).text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AutomationVisual.of(context).textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null) ...[badge!, const SizedBox(width: 8)],
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AutomationVisual.of(context).textMuted,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Banner de aviso cuando hay borradores pendientes de revisión o aprobación.
/// Solo se renderiza si count > 0, eliminando ruido visual y redundancia cuando no hay pendientes.
class _PendingDraftsBanner extends StatelessWidget {
  const _PendingDraftsBanner({required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: visual.accentSoft.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: visual.accent.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: visual.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mark_chat_unread_rounded,
              size: 17,
              color: visual.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count borrador${count == 1 ? '' : 'es'} pendiente${count == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: visual.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Esperando tu revisión o aprobación',
                  style: TextStyle(
                    color: visual.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                backgroundColor: visual.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Revisar',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
