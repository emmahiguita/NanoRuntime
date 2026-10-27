part of 'messaging_channel_sheet.dart';

class _MessagingChannelsCard extends StatelessWidget {
  final dynamic registry;
  final void Function(String packageName, bool enabled) setChannel;
  final bool isDark;

  const _MessagingChannelsCard({
    required this.registry,
    required this.setChannel,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          _ChannelSwitch(
            title: 'WhatsApp',
            subtitle: 'Mensajes personales y contactos',
            value: registry.isChannelRuleActive(MessagingPackage.whatsapp),
            onChanged: (val) => setChannel(MessagingPackage.whatsapp, val),
            isDark: isDark,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.06),
          ),
          _ChannelSwitch(
            title: 'WhatsApp Business',
            subtitle: 'Mensajes de clientes y comercio',
            value: registry.isChannelRuleActive(
              MessagingPackage.whatsappBusiness,
            ),
            onChanged: (val) =>
                setChannel(MessagingPackage.whatsappBusiness, val),
            isDark: isDark,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.06),
          ),
          _ChannelSwitch(
            title: 'Telegram',
            subtitle: 'Mensajes directos y grupos',
            value:
                registry.isChannelRuleActive(MessagingPackage.telegramOrg) ||
                registry.isChannelRuleActive(MessagingPackage.telegram),
            onChanged: (val) {
              setChannel(MessagingPackage.telegramOrg, val);
              setChannel(MessagingPackage.telegram, val);
            },
            isDark: isDark,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.06),
          ),
          _ChannelSwitch(
            title: 'Instagram',
            subtitle: 'Mensajes directos (DMs)',
            value: registry.isChannelRuleActive(MessagingPackage.instagram),
            onChanged: (val) => setChannel(MessagingPackage.instagram, val),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _ChannelSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  const _ChannelSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      dense: true,
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? Colors.white54 : const Color(0xFF64748B),
          fontSize: 11.5,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
