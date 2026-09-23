// browser_owl_assistant_sheet.dart — Invocador unificado de Nano Everywhere desde el navegador.
// QUÉ: Abre el asistente interactivo Búho Nano contextualizado con la URL activa.
// CÓMO: Invoca directamente [NanoFloatingWrapper.expand] sin crear hojas duplicadas.
// POR QUÉ: Unifica el punto de entrada (Single Source of Truth) y elimina redundancia.
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../chat/nano_everywhere/nano_ai_models.dart';
import '../../../chat/nano_everywhere/nano_floating_wrapper.dart';
import '../../domain/browser_tab_model.dart';

class BrowserOwlAssistantSheet {
  const BrowserOwlAssistantSheet._();

  static void show(
    BuildContext context, {
    BrowserTabModel? tab,
    InAppWebViewController? controller,
  }) {
    final prompt = tab != null && tab.url.isNotEmpty ? tab.url : null;
    NanoFloatingWrapper.expand(prompt: prompt, mode: NanoMode.quick);
  }
}
