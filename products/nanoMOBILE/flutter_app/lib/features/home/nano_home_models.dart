import 'package:flutter/material.dart';

enum NanoFeatureType { terminal, chat, models }

class NanoTelemetryData {
  final String ram;
  final String cpu;
  final String temperature;
  final String freeStorage;
  final String battery;

  const NanoTelemetryData({
    required this.ram,
    required this.cpu,
    required this.temperature,
    required this.freeStorage,
    required this.battery,
  });
}

class NanoFeature {
  final NanoFeatureType type;
  final String title;
  final String description;
  final String secondary;
  final String actionLabel;
  final String tag;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const NanoFeature({
    required this.type,
    required this.title,
    required this.description,
    required this.secondary,
    required this.actionLabel,
    required this.tag,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
}

enum KaliStatus { notInitialized, starting, running, stopped, error }

extension KaliStatusPresentation on KaliStatus {
  String get label {
    switch (this) {
      case KaliStatus.notInitialized:
        return 'NO INICIALIZADO';
      case KaliStatus.starting:
        return 'INICIANDO';
      case KaliStatus.running:
        return 'ACTIVO';
      case KaliStatus.stopped:
        return 'DETENIDO';
      case KaliStatus.error:
        return 'ERROR';
    }
  }

  String get description {
    switch (this) {
      case KaliStatus.notInitialized:
        return 'Abre el terminal para comenzar';
      case KaliStatus.starting:
        return 'Preparando entorno Kali';
      case KaliStatus.running:
        return 'Sesión Kali activa';
      case KaliStatus.stopped:
        return 'La sesión está detenida';
      case KaliStatus.error:
        return 'No fue posible iniciar Kali';
    }
  }
}
