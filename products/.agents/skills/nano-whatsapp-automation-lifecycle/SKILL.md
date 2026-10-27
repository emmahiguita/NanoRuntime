---
name: nano-whatsapp-automation-lifecycle
description: Maintain Nano Mobile's WhatsApp notification replies and scheduled text-send lifecycle, including recipient verification, accessibility results, durable alarms, and honest delivery status.
metadata:
  short-description: Maintain real WhatsApp automation safely
---

# Nano WhatsApp automation lifecycle

Use this skill when changing Nano Mobile's WhatsApp notification, scheduled-send, contact-targeting, or Accessibility automation.

## Required workflow

1. Trace the complete path from Android notification or AlarmManager receiver through Flutter rules, native channel, WhatsApp intent, Accessibility click, persistence, and user-visible outcome. Distinguish notification `RemoteInput` replies from scheduled sends; they are separate mechanisms.
2. Treat `startActivity()` as “WhatsApp opened,” not “message sent.” Treat an Accessibility click as “send action dispatched,” not recipient delivery or read confirmation. Name persisted states and UI copy accordingly.
3. Keep scheduled recipient state durable. A failed precondition must never enter the success set. Retry only failures that prove the send action did not run, with a small bounded attempt count. If the outcome is unknown, stop automatic retry to avoid duplicate messages and surface the uncertainty.
4. Verify the requested WhatsApp package and recipient in the active WhatsApp window immediately before the send action. Fail closed when identity is ambiguous; do not use arbitrary body-text matches as proof of the header recipient.
5. Label phonebook numbers separately from contacts confirmed by WhatsApp account metadata. Never manufacture a WhatsApp-verified identity from a phone number alone.
6. Check permission and flavor gates: notification access for inbound replies, Contacts permission for the phonebook, Accessibility for UI automation, exact-alarm access for precise timing, and Play Store policy switches. Explain partial support instead of presenting it as universally available.
7. Inspect service teardown, Handler callbacks, and persisted in-flight sends so activity recreation, service disconnect, process death, and device reboot cannot create zombie loops or duplicate sends.
8. Keep changes scoped and commented at the responsible functions. Honor the user's request to avoid automated tests; use static analysis/build only when available and state which manual device checks remain.

## Compositor de Automatización

- El + usa `onAdd`: Cámara, Fotos, Archivos y Complementos. Solo WhatsApp aparece en Complementos; elegirlo cambia el contexto, sin ejecutar una app ni enviar.
- El logo activo usa `onOptions` para sus funciones. No sustituir el + por el logo ni repetir proveedores de adjuntos dentro de las funciones del componente.
- Los adjuntos pertenecen al editor. Retirar o reemplazar uno revoca el borrador generado que contiene su ruta, usando el mismo `trim` de Ejecutar.
- Los formularios delimitan destinatarios con JSON antes del parser libre para conservar nombres con dos puntos o paréntesis. No ignorar un adjunto preparado al interpretar un envío de texto, incluidas invocaciones con mayúsculas.
- Diseño y revisión estática: `nanoMOBILE/flutter_app/docs/audits/automation-whatsapp-popover/COMPOSER_HIERARCHY.md`; esa revisión no acredita QA universal ni una ejecución posterior en dispositivo.

## Invariants

- A notification reply is possible only when Android exposes an active text `RemoteInput` action.
- An AlarmManager timestamp can be inexact when Android does not grant exact-alarm access.
- WhatsApp's public intent/deep-link flow opens WhatsApp; Nano does not gain an official send API from it.
- Never report delivery, recipient receipt, or read status unless the source platform provides that evidence.

## Device observation without breaking the executor

- Do not run plain `uiautomator dump` during a Nano Accessibility action. UiAutomation suppresses existing accessibility services by default; an immediate dump after Execute can disconnect Nano between preflight and native arming, producing a false failure even when Android settings remain enabled.
- Prefer the ARTEMIS accessibility helper when reachable. During an action, use screenshots and filtered logs that do not attach UiAutomation. Read the hierarchy after the bounded action finishes. Instrumented tests that need UiAutomation must use `FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES`.
- Allow Nano to reconnect after a hierarchy reader disconnects, before Execute. Distinguish observation interference from app defects. Check operation ID, click and return before deciding whether another authorized attempt is safe; never repeat uncertain external effects.
- Android reference: https://developer.android.com/reference/android/app/UiAutomation#FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES . Device evidence: `nanoMOBILE/flutter_app/docs/audits/automation-module-composer/isolated-send.log`.
