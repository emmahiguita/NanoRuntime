import 'package:flutter/material.dart';

/// Plataformas de mensajería soportadas por el Centro de Mensajería.
enum MessagingPlatform {
  whatsapp(
    id: 'whatsapp',
    label: 'WPP Personal',
    packageName: 'com.whatsapp',
    primaryColor: Color(0xFF25D366),
    gradientColors: [Color(0xFF25D366), Color(0xFF128C7E)],
  ),
  whatsappBusiness(
    id: 'whatsapp_business',
    label: 'WPP Negocio',
    packageName: 'com.whatsapp.w4b',
    primaryColor: Color(0xFF00A884),
    gradientColors: [Color(0xFF00A884), Color(0xFF128C7E)],
  ),
  telegram(
    id: 'telegram',
    label: 'Telegram',
    packageName: 'org.telegram.messenger',
    primaryColor: Color(0xFF24A1DE),
    gradientColors: [Color(0xFF2AABEE), Color(0xFF229ED9)],
  ),
  gmail(
    id: 'gmail',
    label: 'Gmail',
    packageName: 'com.google.android.gm',
    primaryColor: Color(0xFFEA4335),
    gradientColors: [Color(0xFFEA4335), Color(0xFFC5221F)],
  ),
  slack(
    id: 'slack',
    label: 'Slack',
    packageName: 'com.Slack',
    primaryColor: Color(0xFF4A154B),
    gradientColors: [Color(0xFF611f69), Color(0xFF4A154B)],
  ),
  instagram(
    id: 'instagram',
    label: 'Instagram',
    packageName: 'com.instagram.android',
    primaryColor: Color(0xFFE1306C),
    gradientColors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
  ),
  facebook(
    id: 'facebook',
    label: 'Facebook',
    packageName: 'com.facebook.katana',
    primaryColor: Color(0xFF1877F2),
    gradientColors: [Color(0xFF1877F2), Color(0xFF0D65D9)],
  ),
  x(
    id: 'x',
    label: 'X / Twitter',
    packageName: 'com.twitter.android',
    primaryColor: Color(0xFF000000),
    gradientColors: [Color(0xFF1F1F1F), Color(0xFF000000)],
  ),
  linkedin(
    id: 'linkedin',
    label: 'LinkedIn',
    packageName: 'com.linkedin.android',
    primaryColor: Color(0xFF0A66C2),
    gradientColors: [Color(0xFF0A66C2), Color(0xFF004182)],
  ),
  other(
    id: 'other',
    label: 'Otras',
    packageName: '',
    primaryColor: Color(0xFF64748B),
    gradientColors: [Color(0xFF64748B), Color(0xFF475569)],
  );

  const MessagingPlatform({
    required this.id,
    required this.label,
    required this.packageName,
    required this.primaryColor,
    required this.gradientColors,
  });

  final String id;
  final String label;
  final String packageName;
  final Color primaryColor;
  final List<Color> gradientColors;

  static MessagingPlatform fromPackageName(String pkg) {
    final lower = pkg.toLowerCase();
    if (lower.contains('w4b') || lower.contains('whatsapp.b') || lower.contains('business')) {
      return MessagingPlatform.whatsappBusiness;
    }
    if (lower.contains('whatsapp')) return MessagingPlatform.whatsapp;
    if (lower.contains('telegram')) return MessagingPlatform.telegram;
    if (lower.contains('gmail') || lower.contains('android.gm')) return MessagingPlatform.gmail;
    if (lower.contains('slack')) return MessagingPlatform.slack;
    if (lower.contains('instagram')) return MessagingPlatform.instagram;
    if (lower.contains('facebook') || lower.contains('katana') || lower.contains('orca')) {
      return MessagingPlatform.facebook;
    }
    if (lower.contains('twitter') || lower.contains('.x.') || lower.endsWith('.x')) {
      return MessagingPlatform.x;
    }
    if (lower.contains('linkedin')) return MessagingPlatform.linkedin;
    return MessagingPlatform.other;
  }

  static MessagingPlatform fromPackageAndAgent(String pkg, dynamic agentId) {
    final lower = pkg.toLowerCase();
    if (agentId != null && agentId.toString().contains('business') && lower.contains('whatsapp')) {
      return MessagingPlatform.whatsappBusiness;
    }
    return fromPackageName(pkg);
  }
}

/// Filtros de categorías para el Centro de Mensajería.
enum MessagingCategoryFilter {
  all(id: 'all', label: 'Todos'),
  contacts(id: 'contacts', label: 'Contactos'),
  unread(id: 'unread', label: 'No leídos'),
  personal(id: 'personal', label: 'Personales'),
  business(id: 'business', label: 'Negocios'),
  bots(id: 'bots', label: 'Bots/Agentes'),
  archived(id: 'archived', label: 'Archivados');

  const MessagingCategoryFilter({required this.id, required this.label});

  final String id;
  final String label;
}
