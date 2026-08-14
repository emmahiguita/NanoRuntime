# Diseño: Módulo Chat — acciones reales + arreglo de arranque del motor

**Fecha:** 2026-08-13
**Alcance:** Enfoque B (aprobado por el usuario)
**Producto:** nanoMOBILE/flutter_app

## Contexto

Auditoría del módulo chat a petición del usuario: "inyectar lógica real funcional
que permita escribir, enviar, borrar, copiar, que sí responda el modelo".

Análisis del código confirmó:

- La cadena de inferencia es real de punta a punta: `ChatNotifier.send()` →
  `RuntimeEngineNotifier.ensureReady()` → canal `com.nanoai/engine` →
  `EngineSupervisor` (Kotlin) → worker `:nanoshell` → PIE `nanortime` →
  HTTP SSE `/completion` en `127.0.0.1:8080`.
- El provider ya expone `delete(id)`, `clear()`, `retry(id)` — pero la UI
  nunca los llama (lógica huérfana).
- **Deadlock de arranque en frío:** el composer se habilita solo con
  `engineOnline == true`; el motor solo arranca dentro de `send()`; por lo
  tanto, con motor idle (app recién abierta) el composer queda bloqueado y
  el botón "Reintentar" (`refreshEngine()`) solo sondea sin arrancar nada.
  El usuario nunca puede enviar el primer mensaje.

## Objetivo

1. Romper el deadlock: el usuario puede enviar con modelo instalado aunque
   el motor esté apagado; el primer envío arranca el motor.
2. Exponer en la UI las acciones reales: copiar, borrar, editar, reintentar,
   limpiar conversación.
3. Mantener la filosofía de honestidad: nada simulado, estados reales,
   errores con mensajes claros.

## S1. Arreglo del deadlock de arranque

Archivos: `lib/core/providers/chat_provider.dart`,
`lib/features/chat/presentation/screens/chat_screen.dart`.

- Regla de habilitación del composer:

  ```dart
  final canSend = state.engineOnline || state.activeModelPath != null;
  ```

  - GGUF instalado (`activeModelPath != null`) → composer activo siempre.
    `send()` ya ejecuta `ensureReady()`: el primer envío arranca el motor
    (carga de modelo ~10-30 s, visible como ThinkingIndicator).
  - Sin modelo y sin motor → composer bloqueado con hint
    `'Descarga un modelo GGUF en Modelos'`.

- Empty state (`_EmptyChat`):
  - Sin modelo instalado: botón principal `'Ir a Modelos'` (navegación a
    `/models`), texto honesto.
  - Con modelo pero motor caído: `'Reintentar'` — ahora funcional.

- `ChatNotifier.refreshEngine()` pasa de solo sondear a arrancar:

  ```dart
  Future<void> refreshEngine() async {
    final engine = _ref.read(runtimeEngineProvider.notifier);
    await engine.ensureReady(modelPath: state.activeModelPath);
    // ... actualizar engineOnline con el estado real resultante
  }
  ```

- Comandos `@` sin cambios: siguen disponibles con motor degraded
  (`engineOnline == true` porque `isLive` cubre degraded).

## S2. Acciones de mensaje

### Long-press en burbuja → bottom sheet de acciones

Nuevo widget privado en `chat_screen.dart` (`_MessageActionsSheet`), estilo
glass acorde a la pantalla. Acciones según contexto:

| Acción | Disponible en | Implementación |
|---|---|---|
| Copiar | todos | `Clipboard.setData` + snackbar `'Copiado'` |
| Editar | mensajes user | nuevo `ChatNotifier.edit(id)` |
| Reintentar | mensajes AI con `status == error` | `retry(id)` existente |
| Borrar | todos | `delete(id)` existente + snackbar |

`Clipboard.setData` se envuelve en try/catch: si falla, snackbar honesto,
nunca excepción suelta.

### `ChatNotifier.edit(String id)` (nuevo)

- Busca el índice del mensaje por `id`; si no es `MessageSender.user`, no-op.
- Elimina el mensaje y todas las respuestas AI posteriores hasta el
  siguiente mensaje user (una edición no deja respuestas huérfanas).
- Carga el texto original en `state.input` para que el usuario lo corrija
  y reenvíe con el flujo normal de `send()`.
- Persiste con `_persistMessages()`.

### Limpiar conversación

Botón `delete_sweep` en el header (visible solo con mensajes) → diálogo de
confirmación (acción irreversible) → `clear()` existente.

## S3. Limpieza de código muerto

- Retirar `showModelSelector` de `ChatState` (y `copyWith`) y
  `toggleSelector()` de `ChatNotifier` — sin callers en todo el repo.
- Hints del composer por estado real: motor apagado + modelo instalado →
  `'Escribe un mensaje'` (arranca solo); sin modelo → mensaje que dirige a
  Modelos.

## S4. Pruebas

Nuevo `test/chat_actions_test.dart` (widget tests con
`ChatNotifier.fixed` + `_FakeEngineNotifier`, patrón existente de
`chat_models_screens_test.dart`):

1. Long-press muestra el menú con Copiar/Borrar.
2. Copiar escribe el texto en el Clipboard (mock del canal
   `SystemChannels.platform`).
3. Borrar elimina la burbuja.
4. Editar: texto cargado al input, mensaje y respuestas posteriores podadas.
5. Reintentar (mensaje error) reenvía al motor fake.
6. Deadlock: modelo instalado + motor idle → composer habilitado → send
   llama `ensureReady` (fake) y muestra estado generando.
7. Limpiar: confirmación → conversación vacía.
8. Sin modelo ni motor: composer bloqueado, botón `'Ir a Modelos'` presente.

Verificación: `flutter analyze` limpio y suite completa de tests en verde.

## Archivos afectados

- `lib/core/models/chat_models.dart` — quitar `showModelSelector`.
- `lib/core/providers/chat_provider.dart` — `edit(id)`, `refreshEngine()`
  con `ensureReady`, quitar `toggleSelector()`.
- `lib/features/chat/presentation/screens/chat_screen.dart` — regla de
  habilitación, menú long-press, botón limpiar, empty state navegable.
- `test/chat_actions_test.dart` — nuevo.

Sin cambios en Kotlin, C, ni el motor: la cadena nativa ya es real y quedó
verificada en la auditoría.

## Fuera de alcance (YAGNI)

- Selector de modelo dentro del chat (ya existe en la pantalla Modelos).
- Autostart del motor al entrar a la pantalla (RAM sin uso real, contra la
  filosofía de puerta RAM).
- Editor inline de mensajes (editar = recargar al input, más simple y
  honesto).
- Undo de borrado (snackbar informativo basta).
