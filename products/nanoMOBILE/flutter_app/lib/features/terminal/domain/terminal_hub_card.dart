import 'package:flutter/material.dart';

/// Entidad inmutable que representa un destino del Terminal Hub (SRP - Single Responsibility).
class TerminalHubCard {
  const TerminalHubCard({
    required this.id,
    required this.title,
    required this.eyebrow,
    required this.description,
    required this.icon,
    required this.accent,
    required this.route,
    required this.highlights,
    required this.actionLabel,
    this.imageAsset,
  });

  final String id;
  final String title;
  final String eyebrow;
  final String description;
  final IconData icon;
  final Color accent;
  final String route;
  final List<String> highlights;
  final String actionLabel;
  final String? imageAsset;
}
