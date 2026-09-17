import 'package:flutter/material.dart';

/// Modo del componente Picture-in-Picture (PiP)
enum BrowserPipMode { none, floating, compactPill }

/// Estado inmutable del componente Picture-in-Picture
class BrowserPipState {
  final bool isActive;
  final bool isCompact;
  final Offset position;
  final Size size;
  final String? activeTabId;
  final String? url;
  final String? title;
  final bool isPlaying;
  final bool isSystemPip;
  final bool isMaximized;
  final double resumePositionSeconds;
  final bool transferPending;

  const BrowserPipState({
    this.isActive = false,
    this.isCompact = false,
    this.position = const Offset(16, 120),
    this.size = const Size(320, 250),
    this.activeTabId,
    this.url,
    this.title,
    this.isPlaying = true,
    this.isSystemPip = false,
    this.isMaximized = false,
    this.resumePositionSeconds = 0,
    this.transferPending = false,
  });

  BrowserPipState copyWith({
    bool? isActive,
    bool? isCompact,
    Offset? position,
    Size? size,
    String? activeTabId,
    String? url,
    String? title,
    bool? isPlaying,
    bool? isSystemPip,
    bool? isMaximized,
    double? resumePositionSeconds,
    bool? transferPending,
  }) {
    return BrowserPipState(
      isActive: isActive ?? this.isActive,
      isCompact: isCompact ?? this.isCompact,
      position: position ?? this.position,
      size: size ?? this.size,
      activeTabId: activeTabId ?? this.activeTabId,
      url: url ?? this.url,
      title: title ?? this.title,
      isPlaying: isPlaying ?? this.isPlaying,
      isSystemPip: isSystemPip ?? this.isSystemPip,
      isMaximized: isMaximized ?? this.isMaximized,
      resumePositionSeconds:
          resumePositionSeconds ?? this.resumePositionSeconds,
      transferPending: transferPending ?? this.transferPending,
    );
  }
}
