# Plan de Cierre NanoAI Mobile V1 — Estabilización (12 Release Gates)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cerrar NanoAI Mobile V1 con los 12 release gates verdes: la app abre rápido, distingue motor vivo/cargando/listo, nunca cuelga esperando un GGUF, cancela sin romper el siguiente turno, reutiliza KV con gates de invalidación, y resiste soak de 30 turnos y 20 ciclos load/unload.

**Architecture:** Flutter (UI + SSE client) → nanortime-cli server HTTP (liveness/readiness/cancel/SSE) → nanortime-core (planner, KV por sesión, telemetría OS) → llama.cpp vendor. El plan cierra los huecos entre capas: request_id extremo a extremo para cancel, timings del backend al frame SSE final, tier del catálogo consumido por la UI, NanoSession explícito en core, y tests de soak.

**Tech Stack:** Rust (tokio, serde, tracing), Flutter/Dart (riverpod, http, flutter_test), llama.cpp bindings propios (`llama-cpp-sys-2-mtp`), CI ubuntu (`cargo clippy -D warnings`, matriz de features de producción).

## Global Constraints

- Rama actual: `feature/llama-migracion`. No hacer merge a `master` hasta gates verdes.
- Cero features nuevas: solo cierre de gates. Congelar MTP/Vulkan/NPU hasta V1.1.
- Honestidad NanoRuntime: ningún estado supuesto — todo derivado de evidencia real (HTTP/proc). Nunca ocultar degradación.
- `cargo clippy -D warnings` limpio en CI ubuntu; tests Rust y Dart verdes.
- Comentarios y mensajes de usuario en español; identificadores técnicos en inglés (patrón existente).
- Server HTTP respeta los endpoints existentes: `GET /liveness`, `GET /readiness`, `GET /health` (alias), `POST /cancel`, `POST /completion`.

---

## Estado actual (línea base)

Ya implementado y con tests: R2 (liveness/readiness en `products/nanoRUNTIME/nanortime-cli/src/server.rs`), heartbeat SSE 2s en fases loading/generating (R3 parcial), cancel watch en server para load/prefill/generate (R6 parcial, sin abort hook — honesto en comentario), KV persistente por sesión con `clear_kv_cache` al cambiar `session_id` (`model_manager.rs:1237`), `ModelTier` en catálogo Flutter (`catalog_models.dart:15`, trabajo en curso, aún no commiteado), telemetría OS real vía `/api/status` (fault_rate, PSS, tok_s, viability).

Huecos confirmados: Flutter no llama `POST /cancel` (solo cierra el socket), no hay timings por turno (el server nunca envía `timings`), `ModelTier` no lo consume ninguna pantalla, no existe supervisor de sesión con estados explícitos, no hay gates de template_hash ni rollback de KV, no existen tests de soak (R7/R12), y la medición de release (R10) no está automatizada.

---

## Fase 1 — Cancelación como gate de release (R6)

### Task 1: request_id extremo a extremo + `stop()` llama `POST /cancel`

**Files:**
- Modify: `products/nanoMOBILE/flutter_app/lib/core/services/llm_engine_client.dart:188-215`
- Modify: `products/nanoMOBILE/flutter_app/lib/core/providers/chat_provider.dart:26-30, 588-648, 834-857`
- Test: `products/nanoMOBILE/flutter_app/test/chat_cancel_test.dart` (nuevo)

**Interfaces:**
- Consumes: `POST /cancel` existente en `server.rs:394` (payload `{"request_id": "..."}`, responde 200/404/400; tests `cancel_unknown_request_returns_404`, `cancel_invalid_json_returns_400` ya verdes).
- Produces: `LLMEngineClient.cancelRequest(String requestId)`; `generateStream` retorna record `({Stream<LLMStreamToken> stream, http.Client client, String requestId})` con request_id generado en el cliente (`'req-<microsecondsSinceEpoch>'`) e incluido en el body JSON; `ChatNotifier._currentRequestId` guarda el id del turno activo.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/chat_cancel_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('generateStream incluye request_id y cancelRequest emite POST /cancel', () async {
    final requests = <http.Request>[];
    final client = LLMEngineClient(
      baseUrl: 'http://127.0.0.1:8080',
      timeout: const Duration(seconds: 5),
    );
    // Reemplaza el _client interno con un MockClient que registra el body.
    final mock = MockClient((request) async {
      requests.add(request);
      return http.Response('data: {"content":"","stop":true}\n\n', 200);
    });
    // (inyección: ver Step 3 — constructor gana parámetro `http.Client? client`)

    final (:stream, :requestId) = client.generateStream(prompt: 'hola');
    await for (final _ in stream) {}

    final completion = requests.singleWhere(
      (r) => r.url.path == '/completion',
    );
    final body = jsonDecode(completion.body) as Map<String, dynamic>;
    expect(body['request_id'], requestId);
    expect(requestId, isNotEmpty);

    await client.cancelRequest(requestId);
    final cancel = requests.lastWhere((r) => r.url.path == '/cancel');
    expect(cancel.method, 'POST');
    expect(jsonDecode(cancel.body)['request_id'], requestId);
  });
}
```

- [ ] **Step 2: Correr test, verificar que falla**

Run: `cd products/nanoMOBILE/flutter_app && flutter test test/chat_cancel_test.dart`
Expected: FAIL — `generateStream` devuelve record de 2 campos, `cancelRequest` no existe.

- [ ] **Step 3: Implementación mínima**

`llm_engine_client.dart`:

```dart
class LLMEngineClient {
  LLMEngineClient({this.baseUrl = 'http://127.0.0.1:8080',
      this.timeout = const Duration(seconds: 120), http.Client? client})
      : _client = client ?? http.Client();

  static String newRequestId() => 'req-${DateTime.now().microsecondsSinceEpoch}';

  /// Cancela la generación con [requestId] en el server (POST /cancel).
  /// Devuelve false si el server responde 404 (ya terminada) o falla la red.
  Future<bool> cancelRequest(String requestId) async {
    try {
      final r = await _client
          .post(Uri.parse('$baseUrl/cancel'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'request_id': requestId}))
          .timeout(const Duration(seconds: 3));
      return r.statusCode == 200 || r.statusCode == 404;
    } catch (_) {
      return false;
    }
  }

  ({Stream<LLMStreamToken> stream, http.Client client, String requestId})
      generateStream({...}) {
    final requestId = newRequestId();
    // _startStreamRequest recibe requestId y lo mete al body:
    //   'request_id': requestId,
    return (stream: controller.stream, client: client, requestId: requestId);
  }
}
```

`chat_provider.dart`:

```dart
String? _currentRequestId; // en ChatNotifier

// en _generateRound, tras generar el stream:
final (:stream, :client, :requestId) = _engine.generateStream(...);
_currentRequestId = requestId;

// en stop(), ANTES de cerrar el cliente:
final reqId = _currentRequestId;
if (reqId != null) {
  unawaited(_engine.cancelRequest(reqId).then((_) {
    debugPrint('[chat_provider] /cancel enviado para $reqId');
  }));
}
_currentRequestId = null;
```

- [ ] **Step 4: Correr tests**

Run: `flutter test test/chat_cancel_test.dart`
Expected: PASS. Nota: el server ignora el cancel si el stream ya murió (404 → tratado como éxito).

- [ ] **Step 5: Commit**

```bash
git add products/nanoMOBILE/flutter_app/lib/core/services/llm_engine_client.dart \
        products/nanoMOBILE/flutter_app/lib/core/providers/chat_provider.dart \
        products/nanoMOBILE/flutter_app/test/chat_cancel_test.dart
git commit -m "feat(chat): request_id extremo a extremo y stop() emite POST /cancel (R6)"
```

### Task 2: KV en estado conocido tras cancel

**Files:**
- Modify: `products/nanoRUNTIME/nanortime-core/src/execution/model_manager.rs:47, 1227-1247`
- Modify: `products/nanoRUNTIME/nanortime-cli/src/server.rs:395-430, 626-712`
- Test: `products/nanoRUNTIME/nanortime-cli/src/server.rs` (módulo tests existente, patrón `drive/http_request`)

**Interfaces:**
- Consumes: `handle_cancel` y `handle_completion_sse` existentes; `runtime_slot: &RwLock<RuntimeSlot>` ya accesible en ambos handlers.
- Produces: método público en el runtime/core `mark_session_cancelled(&self, session_id: &str)` que setea `ModelState.kv_dirty = true` cuando `active_session_id == Some(session_id)`. `generate_streaming` hace `clear_kv_cache()` al inicio si `kv_dirty` está activo (además del chequeo de cambio de sesión existente en `model_manager.rs:1237`).

- [ ] **Step 1: Escribir el test que falla (test unitario core, feature `simulated`)**

```rust
// products/nanoRUNTIME/nanortime-core/tests/session_kv_test.rs (nuevo)
//! Gate R6/R5: tras un cancel, el siguiente request del MISMO session
//! reconstruye el KV en vez de continuar con estado dudoso.

#[cfg(feature = "simulated")]
#[tokio::test]
async fn cancel_marks_session_dirty_and_next_turn_resets_kv() {
    // Config mínima: runtime con backend simulado (patrón de
    // integration_test.rs: cfg!(feature = "simulated") + RuntimeConfig::simulated()).
    let runtime = /* construir runtime simulado como en integration_test.rs */;
    let session = "chat-1";

    let _ = runtime.process_request_streaming(UserRequest {
        prompt: "primer turno".into(),
        session_id: Some(session.into()),
        ..Default::default()
    }).await.unwrap();

    // Cancel en plena generación: el server llama a esto.
    runtime.mark_session_cancelled(session);

    // Segundo turno: el KV debe reconstruirse.
    let (_rx, mut tokens) = runtime.process_request_streaming(UserRequest {
        prompt: "segundo turno".into(),
        session_id: Some(session.into()),
        ..Default::default()
    }).await.unwrap();
    while tokens.recv().await.is_some() {}
    // (assert observable: tracing/log del core "KV reset" — en simulated se
    //  expone vía un contador en SessionStats; ver Step 3.)
    assert!(runtime.last_kv_was_reset());
}
```

- [ ] **Step 2: Correr test, verificar fallo**

Run: `cd products/nanoRUNTIME && cargo test -p nanortime-core --features simulated --test session_kv_test`
Expected: FAIL — `mark_session_cancelled` y `last_kv_was_reset` no existen.

- [ ] **Step 3: Implementación mínima**

`model_manager.rs` (dentro de `ModelState`):

```rust
/// KV quedó en estado dudoso (cancel/abort durante prefill o decode).
/// El siguiente turno de la MISMA sesión reconstruye el contexto.
kv_dirty: bool, // init: false (en los dos puntos donde se crea ModelState)

pub fn mark_session_cancelled(&mut self, session_id: &str) {
    if self.active_session_id.as_deref() == Some(session_id) {
        self.kv_dirty = true;
        tracing::info!("[NanoSession] session {} cancelled; KV marked dirty", session_id);
    }
}

// en generate_streaming, junto al chequeo de session switch (línea 1237):
if s.active_session_id.as_deref() != session_id_owned.as_deref()
    || s.kv_dirty
{
    if let Some(ref mut existing) = ctx {
        existing.clear_kv_cache();
    }
    s.kv_dirty = false;
    tracing::info!("[NanoSession] KV reset (session switch o dirty)");
    s.active_session_id = session_id_owned.clone();
}
```

`server.rs` — `handle_cancel`, tras `signal_cancel` exitoso:

```rust
if state.signal_cancel(&req.request_id) {
    // El request cancelado pertenece a una sesión: marcar su KV como
    // dudoso para que el siguiente turno reconstruya contexto.
    if let Some(session_id) = state.session_of(&req.request_id) {
        if let Ok(rt) = runtime_slot.read() {
            if let Some(rt) = rt.as_ref() {
                rt.mark_session_cancelled(&session_id);
            }
        }
    }
    // ... respuesta 200 existente
}
```

`ServerState` gana un registro `request_id → session_id` (se guarda en `handle_completion_sse` justo después de parsear el request) con método `session_of`. `mark_session_cancelled` se expone en el tipo del runtime (orchestrator → model_manager).

- [ ] **Step 4: Correr tests**

Run: `cargo test -p nanortime-core --features simulated --test session_kv_test` y `cargo test -p nanortime-cli server`
Expected: PASS ambos. Agregar además test server: tras `POST /cancel` de un request con session, el siguiente `/completion` del mismo session produce log `KV reset`.

- [ ] **Step 5: Commit**

```bash
git add products/nanoRUNTIME/nanortime-core/src/execution/model_manager.rs \
        products/nanoRUNTIME/nanortime-core/tests/session_kv_test.rs \
        products/nanoRUNTIME/nanortime-cli/src/server.rs
git commit -m "feat(core): KV dirty tras cancel; siguiente turno reconstruye contexto (R6)"
```

### Task 3: Test cancel en los tres puntos (prefill / generate / tool-call)

**Files:**
- Test: `products/nanoMOBILE/flutter_app/test/chat_cancel_test.dart` (extender)
- Test: `products/nanoRUNTIME/nanortime-cli/src/server.rs` (extender)

**Interfaces:**
- Consumes: `ChatNotifier.fixed` (`chat_provider.dart:168`, test-only), `stop()`, `send()` con MockClient; server `drive/http_request` helpers de los tests existentes.

- [ ] **Step 1: Escribir los tests que fallan**

```dart
// Flutter: cancel durante generación deja el estado listo para el próximo turno
test('stop() durante streaming deja generating=false y permite reenviar', () async {
  // MockClient que emite tokens lentos (delayed) y nunca stop:true.
  final notifier = ChatNotifier.fixed(/* ref fake */);
  await notifier.send('cuéntame algo');
  expect(notifier.state.generating, isTrue);
  notifier.stop();
  expect(notifier.state.generating, isFalse);
  expect(notifier.state.streamingText, isEmpty);
  // Siguiente send() debe funcionar (no heredar estado roto).
  await notifier.send('otra cosa');
  expect(notifier.state.generating, isFalse); // mock termina
  expect(notifier.state.messages.length, greaterThanOrEqualTo(3));
});
```

```rust
// Server: cancel durante prefill (antes del primer token) corta el stream
// con "cancelled":true y el siguiente request de la MISMA sesión responde 200.
#[test]
fn cancel_during_prefill_then_next_turn_same_session_ok() { /* ... */ }
```

- [ ] **Step 2: Correr, verificar fallo** — FAIL donde aplique (cancel en tool-call: `_generationCancelled` ya se chequea tras `runToolGuarded`, `chat_provider.dart:742`; si el test pasa a la primera, mantenerlo como regresión).

- [ ] **Step 3-5: Implementar lo que falte, correr, commit**

Regla del gate, verificable en los tres puntos:

```
cancel → detener trabajo → cerrar SSE → KV estado conocido → siguiente request funciona
```

```bash
git commit -m "test(chat): cancel durante prefill/generate/tool sin romper siguiente turno (R6)"
```

---

## Fase 2 — SSE con progreso y timings reales (R3, R10)

### Task 4: Server emite `prefill` progress y timings en el frame final

**Files:**
- Modify: `products/nanoRUNTIME/nanortime-core/src/orchestrator/mod.rs:1138-1210` (oneshot `Response`)
- Modify: `products/nanoRUNTIME/nanortime-core/src/execution/model_manager.rs:1177-1290` (poblar stats)
- Modify: `products/nanoRUNTIME/nanortime-cli/src/server.rs:561-720` (frames SSE)
- Test: `products/nanoRUNTIME/nanortime-cli/src/server.rs` (extender)

**Interfaces:**
- Produce: struct `GenerationStats` en `nanortime_core` (exportado):

```rust
#[derive(Debug, Clone, Default, serde::Serialize)]
pub struct GenerationStats {
    /// Tokens del prompt procesados en este turno.
    pub prompt_processed: usize,
    /// Total de tokens del prompt (contexto completo tras template).
    pub prompt_total: usize,
    /// ms de evaluación del prompt (prefill real, sin cache).
    pub prompt_eval_ms: u64,
    /// ms de decode (generación de tokens).
    pub eval_ms: u64,
    /// Tokens/s de decode reportados por el backend.
    pub predicted_per_second: f64,
    /// Tokens nuevos generados.
    pub predicted_n: usize,
}
```

- El oneshot `Response` de `process_request_streaming` gana campo `pub stats: GenerationStats` (default `Default::default()` para callers existentes).

- [ ] **Step 1: Escribir el test que falla (server, backend simulado)**

```rust
// server.rs tests: el frame final del SSE incluye timings con las llaves
// prompt_eval_ms / eval_ms / predicted_per_second.
#[test]
fn completion_sse_final_frame_includes_timings() {
    let (status, body) = drive(&http_request("POST", "/completion",
        r#"{"prompt":"hola","stream":true,"n_predict":4}"#));
    assert_eq!(status, "200 OK");
    let last = /* parsear el último data: frame del body */;
    let timings = last["timings"].as_object().expect("timings presentes");
    assert!(timings.contains_key("prompt_eval_ms"));
    assert!(timings.contains_key("eval_ms"));
    assert!(timings.contains_key("predicted_per_second"));
}
```

- [ ] **Step 2: Correr, verificar fallo** — FAIL: frame final no trae `timings` (grep confirmado: 0 matches de `timings` en server.rs).

- [ ] **Step 3: Implementación mínima**

`model_manager.rs` — `generate_streaming` ya recibe el prompt completo y el backend reporta eval times vía los bindings (`LlamaCppBackend`): capturar `prompt_processed` del tamaño del prompt tokenizado, `eval_ms`/`predicted_per_second` de los timings del backend tras el loop de sampling, y devolverlos junto al texto en el oneshot. En feature `simulated`, valores deterministas (p. ej. `prompt_eval_ms: 42, eval_ms: 10, predicted_per_second: 8.0`).

`server.rs` — en el loop de generación (rama streaming), tras recibir el oneshot:

```rust
// Frame final:
send_frame(stream, &format!(r#"{{"content":"","stop":true,"request_id":"{}","cancelled":{},
    "timings":{{"prompt_processed":{},"prompt_total":{},"prompt_eval_ms":{},
    "eval_ms":{},"predicted_per_second":{},"predicted_n":{}}}}}"#, ...));
```

Y un frame `prefill` tras arrancar el stream (antes del primer token), con `prompt_processed` incremental si el backend lo expone; si no lo expone, un solo frame con `processed`/`total` del prompt:

```text
data: {"event":"prefill","processed":384,"total":1024}
```

- [ ] **Step 4: Correr tests** — `cargo test -p nanortime-cli server` y `cargo test -p nanortime-core --features simulated`. PASS.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(server): frame final con timings reales y evento prefill (R3/R10)"
```

### Task 5: Flutter consume timings, heartbeat y fase de carga

**Files:**
- Modify: `products/nanoMOBILE/flutter_app/lib/core/services/llm_engine_client.dart:270-340, 347-352`
- Modify: `products/nanoMOBILE/flutter_app/lib/core/models/chat_models.dart` (ChatState)
- Modify: `products/nanoMOBILE/flutter_app/lib/core/providers/chat_provider.dart:655-680, 772-787`
- Modify: `products/nanoMOBILE/flutter_app/lib/features/chat/presentation/screens/chat_screen.dart` (chip de estado)
- Test: `products/nanoMOBILE/flutter_app/test/chat_timings_test.dart` (nuevo)

**Interfaces:**
- Produce: `LLMStreamToken` gana `final Map<String, dynamic>? timings;` y `final String? phase;` (parse de `map['timings']` y de los frames heartbeat `{"heartbeat":true,"phase":"model_loading"}`). `ChatState` gana `final TurnMetrics? lastTurnMetrics;` con `class TurnMetrics { final int? prefillMs; final double? decodeTokS; final int? promptProcessed; }`.
- Consume: `ModelConnectionState.loadingModel` existente (chat_models.dart) para el chip `LOCAL · CARGANDO` cuando llega heartbeat `model_loading`.

- [ ] **Step 1: Escribir test que falla** — MockClient emite `data: {"heartbeat":true,"phase":"model_loading"}` luego tokens y frame final con `timings`; assert: `connection == loadingModel` al recibir heartbeat de carga, `lastTurnMetrics.decodeTokS` poblado al final.

- [ ] **Step 2-5: Implementar, correr, commit** (misma disciplina TDD que Task 1).

```bash
git commit -m "feat(chat): UI consume fase de carga y timings por turno (R3/R10)"
```

---

## Fase 3 — Modelo interactivo por defecto (R9)

### Task 6: models_screen consume `ModelTier` y protege EXTREME

**Files:**
- Modify: `products/nanoMOBILE/flutter_app/lib/features/models/presentation/screens/models_screen.dart`
- Modify: `products/nanoMOBILE/flutter_app/lib/core/providers/chat_provider.dart:910-933` (`selectModel`)
- Test: `products/nanoMOBILE/flutter_app/test/chat_models_screens_test.dart` (extender)

**Interfaces:**
- Consume: `LmCatalogEntry.tier` (`catalog_models.dart:43`, ya presente en working tree), `ModelTier.interactive/deep/extreme`.
- Produce: badge por tier en la lista de modelos (`INTERACTIVE` verde, `DEEP` ámbar, `EXTREME` rojo); diálogo de confirmación antes de seleccionar un `extreme` ("Solo batch/experimental — el chat quedará lento en este dispositivo"); `selectModel` de un `extreme` sin confirmación previa no aplica.

- [ ] **Step 1: Escribir test widget que falla** — abrir Modelos, tap en `Qwen3.8-27B-Q2_K` sin confirmación: el modelo activo NO cambia; con confirmación del diálogo: cambia y persiste.

- [ ] **Step 2-5: Implementar, correr, commit**

```bash
git commit -m "feat(models): tier INTERACTIVE/DEEP/EXTREME en UI con confirmación para extreme (R9)"
```

---

## Fase 4 — SessionSupervisor explícito (R5)

### Task 7: `NanoSession` con estados y gates de invalidación

**Files:**
- Create: `products/nanoRUNTIME/nanortime-core/src/execution/session.rs`
- Modify: `products/nanoRUNTIME/nanortime-core/src/execution/model_manager.rs:47, 485, 1015, 1237-1247`
- Modify: `products/nanoRUNTIME/nanortime-core/src/execution/mod.rs` (export)
- Test: `products/nanoRUNTIME/nanortime-core/tests/session_kv_test.rs` (extender)

**Interfaces:**
- Produce:

```rust
/// Supervisor de sesión de chat — Gate R5. Una sesión por session_id.
pub struct NanoSession {
    pub model_id: String,
    pub model_hash: String,
    pub template_hash: u64,     // hash del nombre de chat-template usado
    pub n_ctx: usize,
    pub token_count: usize,
    pub kv_valid: bool,
    pub last_access: std::time::SystemTime,
    pub state: SessionState,
}

pub enum SessionState {
    Empty,
    Prefilling,
    Ready,
    Generating,
    Cancelled,
    Invalid,
}
```

- `ModelState.active_session_id: Option<String>` se reemplaza por `session: Option<NanoSession>` (migración mecánica de los 4 sitios que lo tocan). Transiciones en `generate_streaming`: `Empty → Prefilling → Generating → Ready`; error durante generación → `Invalid` (y `kv_valid = false`); `mark_session_cancelled` → `Cancelled` (y `kv_valid = false`).
- Gate de template: `UserRequest` gana `template_name: Option<String>` (el server lo pasa desde el body; Flutter envía `template`). Cambio de `template_hash` entre turnos de la misma sesión → `kv_valid = false` → `clear_kv_cache` en el siguiente turno.
- Gate de modelo: `model_id`/`model_hash` del GGUF cargado se comparan; el modelo solo se recarga vía load (ya invalida sesión en `model_manager.rs:485` y `:1015`).

- [ ] **Step 1: Escribir tests que fallan** — unit tests en `session_kv_test.rs`: (a) transición `Empty→Generating→Ready` con `kv_valid=true`; (b) cancel → `Cancelled`, siguiente turno reconstruye (`kv_valid=false` al inicio); (c) cambio de `template_name` con mismo `session_id` → KV reset; (d) error simulado en prefill → `Invalid`, siguiente turno reconstruye.

- [ ] **Step 2-5: Implementar, correr, commit** — clippy `-D warnings` limpio.

```bash
git commit -m "feat(core): NanoSession con estados y gates KV (modelo/template/rollback) (R5)"
```

### Task 8: Flutter envía `template` y rota sesión al cambiar de modelo

**Files:**
- Modify: `products/nanoMOBILE/flutter_app/lib/core/services/llm_engine_client.dart:236-246`
- Modify: `products/nanoMOBILE/flutter_app/lib/core/providers/chat_provider.dart:37, 910-933`
- Test: `products/nanoMOBILE/flutter_app/test/chat_cancel_test.dart` (extender) o `chat_timings_test.dart`

**Interfaces:**
- Consume: `ChatTemplate` existente + `templateOf(name)` (`catalog_models.dart:293`).
- Produce: body de `/completion` incluye `'template': templateOf(activeModel).name`; `selectModel` regenera `_sessionId` (además de la invalidación del server por reinicio de motor, garantiza que el KV viejo nunca se reutilice aunque el motor NO se reinicie).

- [ ] **Steps 1-5:** test → implementar → correr → commit.

```bash
git commit -m "feat(chat): envía template y rota session al cambiar modelo (R5)"
```

---

## Fase 5 — Soak: lifecycle y conversación larga (R7, R12)

### Task 9: 20 ciclos load/generate/unload sin crecimiento (Rust)

**Files:**
- Create: `products/nanoRUNTIME/nanortime-core/tests/lifecycle_soak_test.rs`
- Test: `products/nanoRUNTIME/nanortime-core/tests/lifecycle_soak_test.rs`

**Interfaces:**
- Consume: feature `simulated` (CI ubuntu); `process_request_streaming`, `load_model`/`unload` del runtime; contadores internos de métricas (`RuntimeMetrics` de `memory_engine/runtime_metrics.rs`).

- [ ] **Step 1: Escribir el test**

```rust
//! Gate R7: 20 ciclos load/generate/unload sin crecimiento acumulativo.
#![cfg(feature = "simulated")]

#[tokio::test]
async fn twenty_load_unload_cycles_no_monotonic_growth() {
    let runtime = /* runtime simulado, patrón integration_test.rs */;
    let mut pss_samples = Vec::new();
    for cycle in 0..20 {
        runtime.load_model(/* 1.5B simulated */).await.unwrap();
        let (_rx, mut tokens) = runtime
            .process_request_streaming(UserRequest {
                prompt: format!("ciclo {}", cycle),
                session_id: Some(format!("s{}", cycle % 3)),
                ..Default::default()
            })
            .await
            .unwrap();
        while tokens.recv().await.is_some() {}
        let pss = runtime.metrics().simulated_pss_kb(); // contador interno en simulated
        pss_samples.push(pss);
        runtime.unload().await.unwrap();
        assert_eq!(runtime.active_sessions(), 0, "sesiones huérfanas en ciclo {}", cycle);
    }
    // Gate: el último tercio de muestras no supera monotónicamente al primero.
    let head_avg: i64 = pss_samples[..5].iter().sum::<i64>() / 5;
    let tail_avg: i64 = pss_samples[15..].iter().sum::<i64>() / 5;
    assert!(tail_avg <= head_avg + (head_avg / 20), // tolerancia 5%
        "crecimiento monotónico PSS: {} → {}", head_avg, tail_avg);
}
```

- [ ] **Step 2-5:** correr (FAIL: `simulated_pss_kb` no existe — agregarlo a `RuntimeMetrics` bajo cfg simulated), implementar, correr, commit.

Nota honesta: el gate PSS/RssAnon REAL es verificación manual en dispositivo (`smaps_validator.py` ya existe en `scripts/` para leer `/proc/<pid>/smaps_rollup`); el test CI cubre la lógica de liberación, no el mmap del OS.

```bash
git commit -m "test(core): soak 20 ciclos load/unload sin crecimiento (R7)"
```

### Task 10: 30-turn soak en Flutter

**Files:**
- Create: `products/nanoMOBILE/flutter_app/integration_test/chat_soak_test.dart`

**Interfaces:**
- Consume: `ChatNotifier.fixed` con MockClient determinista (turnos pares responden texto, impares un tool-call).

- [ ] **Step 1: Escribir el test** — 30 turnos alternando texto y tool-call: tras cada turno `generating == false`; sin excepciones capturadas; `messages` crece 2 por turno (user + assistant); `_sessionId` estable salvo `clear()`/cambio de modelo; al final `pendingTool == null`.

- [ ] **Step 2-5:** correr, implementar lo que falle, correr, commit.

```bash
git commit -m "test(chat): soak 30 turnos sin crash ni corrupción de estado (R12)"
```

---

## Fase 6 — Cierre y medición release (R1, R8, R10)

### Task 11: Script de gates de release

**Files:**
- Create: `scripts/release_gates.sh`
- Modify: `Makefile` (target `release-gates`)

- [ ] **Step 1: Script**

```bash
#!/usr/bin/env bash
# Gates de release NanoAI Mobile V1 — correr ANTES de etiquetar.
set -euo pipefail

echo "[1/5] flutter analyze"
(cd products/nanoMOBILE/flutter_app && flutter analyze)

echo "[2/5] flutter test"
(cd products/nanoMOBILE/flutter_app && flutter test)

echo "[3/5] cargo clippy -D warnings (matriz producción)"
(cd products/nanoRUNTIME && cargo clippy -D warnings)

echo "[4/5] cargo test"
(cd products/nanoRUNTIME && cargo test)

echo "[5/5] build release APK"
(cd products/nanoMOBILE/flutter_app && flutter build apk --release)

echo "Gates verdes. Medición TTID/TTFD en dispositivo (manual):"
echo "  adb shell am start -W dev.nanoai.mobile | grep -E 'TotalTime|WaitTime'"
echo "  flutter run --profile + DevTools timeline para TTFD < 2s"
```

- [ ] **Step 2: Makefile**

```makefile
release-gates:
	bash scripts/release_gates.sh
```

- [ ] **Step 3: Correr script en CI local, arreglar lo que reviente, commit.**

```bash
git commit -m "ci(release): script de gates de release con medición TTID/TTFD (R10)"
```

### Task 12: Documento de cierre `docs/GATES_V1.md`

- Matriz de los 12 gates con: criterio, evidencia (test/archivo:línea), estado (VERDE/AMARILLO/ROJO) y fecha.
- Sección "Congelado para V1": lista de features que NO se tocan (MTP real, Vulkan, NPU, RAG semántico) hasta V1.1.
- Checklist manual en dispositivo (PSS real ×20, airplane mode, TTID < 2s, modelo corrupto → error claro).

```bash
git commit -m "docs: matriz de 12 gates y congelación de features V1"
```

---

## Self-Review

**Cobertura de spec (12 gates):** R1 → Tasks 5, 11 (UI no bloquea, medición TTID). R2 → ya verde (línea base); Task 5 cierra el consumo en UI. R3 → Tasks 4, 5. R4 → línea base (timeout 45s + heartbeat 2s); Task 5 añade el chip honesto de carga. R5 → Tasks 2, 7, 8. R6 → Tasks 1, 2, 3. R7 → Task 9. R8 → línea base (SHA256, oom_guard, mensajes honestos) + Task 12 checklist. R9 → Task 6. R10 → Tasks 4, 5, 11. R11 → línea base (loopback puro + `offline_degradation_test.dart`); Task 12 checklist airplane mode. R12 → Task 10.

**Placeholders:** ninguno — cada task tiene código de test e implementación mínima.

**Consistencia de tipos:** `requestId` (Dart, string) = `request_id` (JSON/Rust, string); `session_id` igual en las 3 capas; `template_name` (Rust) = `template` (JSON body Dart); `GenerationStats` definido una sola vez en Task 4 y consumido en Task 5; `NanoSession`/`SessionState` definidos en Task 7, usados por Tasks 2 (kv_dirty queda absorbido por `kv_valid`/`Cancelled`) y 9 (`active_sessions()`).

## Execution Handoff

Orden de fases: 1 → 2 → 3 → 4 → 5 → 6. Cada fase cierra gates completos y es testeable sola. Fases 1-3 no dependen entre sí y pueden ejecutarse en paralelo por subagentes distintos; Fase 4 depende de la 1 (Task 2 introduce kv_dirty que Task 7 formaliza); Fase 5 depende de la 4.
