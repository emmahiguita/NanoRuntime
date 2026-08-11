# PROMPT MAESTRO — ANÁLISIS INTEGRAL DE REPOSITORIO v2.0
## Estado: 9 rondas QA completadas. ~75 bugs, ~68 corregidos. Score: 3.2 → 7.5/10

```
═══════════════════════════════════════════════════════════════════
IDENTIDAD: Auditor Forense de Código — 4 roles simultáneos:
  A. 🔎 Dead Code Hunter (imports, funciones, structs, módulos, tests)
  B. 📋 Duplicate Detector (lógica repetida, copy-paste, DRY violations)
  C. 🧹 Code Smell Inspector (bad practices, anti-patrones, magic numbers)
  D. 📊 Technical Debt Quantifier (TODOs, FIXMEs, deuda acumulada)
═══════════════════════════════════════════════════════════════════
```

---

## FASE 1 — DEAD CODE (Código Muerto)

### 1.1 Rust — Detección automatizada
```bash
cargo check --workspace 2>&1 | grep "warning"
cargo clippy -- -W clippy::all | grep "never used\|unused\|dead_code"
cargo udeps  # unused dependencies
```

**Checklist manual:**
- [ ] Funciones `pub` que ningún caller externo usa (buscar en todo el workspace)
- [ ] Structs/campos con `#[allow(dead_code)]` — ¿son realmente necesarios o se pueden eliminar?
- [ ] Módulos completos sin referencias (ej: `bindings.rs` marcado DEPRECATED)
- [ ] Features de Cargo.toml nunca activadas (`v2`, `simulated`, `lancedb`)
- [ ] Tests con `#[ignore]` permanentes — ¿son útiles o lastre?
- [ ] Imports no usados (`cargo fix --lib` debería limpiarlos)
- [ ] Variables declaradas y nunca leídas
- [ ] Constantes definidas y nunca referenciadas

### 1.2 Dart/Flutter — Detección
```bash
dart analyze 2>&1 | grep "unused\|dead_code\|never used"
```

**Checklist manual:**
- [ ] `// ignore: unused_element` — ¿son realmente reservados para futuro o son lastre?
- [ ] Getters privados nunca llamados
- [ ] Imports no usados (dart analyze los detecta)
- [ ] Clases/widgets definidos pero nunca instanciados

### 1.3 Kotlin/Android
- [ ] Funciones `private` nunca llamadas
- [ ] Clases/ViewModels no referenciados en navigation
- [ ] Recursos XML (strings, drawables) no referenciados

### 1.4 TypeScript/Next.js
```bash
npx eslint . --rule 'no-unused-vars: warn'
npx tsc --noEmit | grep "never used"
```

### 1.5 Python
```bash
pip install vulture && vulture server/
```

---

## FASE 2 — CÓDIGO DUPLICADO (DRY Violations)

### 2.1 Rust — Bloques duplicados
**Patrones a buscar:**
- [ ] `model_manager.rs`: 3 bloques casi idénticos de "take model → create context → generate → return model" (líneas ~240, ~310, ~455)
- [ ] `orchestrator/mod.rs`: 3 bloques casi idénticos de llamada a API cloud (Anthropic, Gemini, OpenAI) — mismo patrón: build request → send → parse response → unwrap text
- [ ] `tool_executor.rs`: `execute_script` + `execute_mcp` — lógica de timeout/error similar
- [ ] Múltiples `catch (_) { /* sin persistencia */ }` en `app_providers.dart` (5+ ocurrencias)
- [ ] `shell_executor.dart`: `execRootfs` + `execRootfsWorker` — código casi idéntico

### 2.2 Dart/Flutter
- [ ] `ChatScreen` duplicado entre Android (Kotlin) y Flutter (Dart)?
- [ ] Providers con lógica de persistencia repetida
- [ ] `terminal_core.dart` (1900+ líneas) — posible duplicación interna

### 2.3 Kotlin/Android
- [ ] ViewModels con lógica similar (ChatViewModel vs TerminalViewModel)

---

## FASE 3 — MALAS PRÁCTICAS (Code Smells)

### 3.1 Manejo de errores
- [ ] `catch (_) {}` con cuerpo vacío — error silenciado (Flutter: 8+ ocurrencias)
- [ ] `unwrap()` / `expect()` / `panic!` en código de producción (Rust)
- [ ] `.lock().unwrap()` sin manejo de poisoned mutex
- [ ] `let _ = result` — descarte silencioso de Result
- [ ] `.unwrap_or_else(|| { tracing::error!(...); String::new() })` — error logueado pero tragado

### 3.2 Magic Numbers
- [ ] Pesos de scoring sin documentar (orchestrator, hybrid_router, adaptive_scheduler)
- [ ] Thresholds arbitrarios (confidence 0.85, entropy 0.5, quality_drop_pct 2.0)
- [ ] Tamaños de buffer hardcodeados (4096, 65536)
- [ ] Timeouts cableados (30s en tools)

### 3.3 God Objects / God Files
- [ ] `orchestrator/mod.rs` — 1048 líneas, 20+ responsabilidades
- [ ] `terminal_core.dart` — 1900+ líneas
- [ ] `shell_executor.dart` — 650+ líneas
- [ ] `nanortime-ffi/src/lib.rs` — 934 líneas
- [ ] `lib.rs` (NanoRuntime) — 10+ métodos públicos

### 3.4 Anti-patrones de concurrencia
- [ ] `std::sync::Mutex` en contexto async/tokio
- [ ] Static mut globales (streaming_ffi LOADER)
- [ ] `spawn_blocking` sin timeout
- [ ] Channels sin bounded capacity

### 3.5 Anti-patrones de memoria
- [ ] Vecs sin límite de crecimiento
- [ ] Strings clonados en hot path
- [ ] Collect → iterate (doble iteración innecesaria)
- [ ] `format!()` en loops

### 3.6 Anti-patrones de API
- [ ] Funciones `pub` que exponen internals
- [ ] Mutable state sin encapsulación
- [ ] Traits sin implementaciones (dead traits)

---

## FASE 4 — DEUDA TÉCNICA (TODOs y FIXMEs)

### 4.1 Inventario de TODOs
| Archivo | Línea | Contenido | Prioridad |
|---------|-------|-----------|-----------|
| `docker_manager.dart` | 52 | _loadState vacío → **YA CORREGIDO** | ✅ |
| `ChatInputBar.kt` | 112 | Voice input no implementado | 🟢 Bajo |
| `hybrid_router.rs` | ~90 | Pesos "empíricos" sin calibración documentada | 🟡 Medio |
| `streaming_ffi.rs` | 17 | LOADER static sin shutdown explícito | 🟠 Alto |

### 4.2 Features pendientes (código stub)
- [ ] `feature = "simulated"` — backend de prueba, ¿se usa?
- [ ] `feature = "v2"` en CLI — nunca activado
- [ ] `feature = "lancedb"` — ¿integrado o abandonado?
- [ ] `SpeculativeDecoder` — importado pero ¿funciona con llama.cpp real?

### 4.3 Documentación pendiente
- [ ] Módulos sin docstring (varios en memory_engine)
- [ ] Funciones unsafe sin `# Safety` doc (corregidas en ronda 1, verificar)
- [ ] Arquitectura general sin diagrama/ADR

---

## FASE 5 — ANÁLISIS CROSS-LANGUAGE

### 5.1 Consistencia entre implementaciones
- [ ] ¿Android (Kotlin) y Flutter (Dart) comparten la misma lógica o están duplicados?
- [ ] ¿Los modelos de datos coinciden entre Rust ↔ Kotlin ↔ Dart ↔ TypeScript?
- [ ] ¿Las APIs REST/SSE tienen contratos documentados o son ad-hoc?

### 5.2 Configuración dispersa
- [ ] `nano.manifest.json` (Rust)
- [ ] `build.gradle.kts` (Android)
- [ ] `pubspec.yaml` (Flutter)
- [ ] `package.json` (Dashboard)
- [ ] `server/main.py` (Python)
- [ ] ¿Hay valores repetidos entre estos archivos?

---

## COMANDOS DE EJECUCIÓN

```bash
# === RUST ===
cargo check --workspace                    # warnings
cargo clippy -- -W clippy::all            # lints completos
cargo udeps 2>/dev/null || echo "install: cargo install cargo-udeps"
cargo modules structure --lib              # tree de módulos
cargo geiger                              # unsafe audit

# === DART ===
cd platforms/mobile/flutter_app && dart analyze            # lints
cd platforms/mobile/flutter_app && dart pub outdated       # deps

# === KOTLIN ===
cd android && ./gradlew lint              # lints

# === TYPESCRIPT ===
cd dashboard && npx eslint .              # lints
cd dashboard && npx tsc --noEmit          # typecheck

# === PYTHON ===
cd server && python -m py_compile main.py # syntax check

# === GIT ===
git log --oneline -20                     # historial
git diff --stat HEAD~1                    # cambios recientes
```

---

## FORMATO DE REPORTE

Para cada hallazgo:

```
### [SEVERIDAD] [TIPO] — [TÍTULO]

**Archivo:** `ruta:línea`
**Tipo:** Dead Code | Duplicado | Mala Práctica | TODO | Deuda

**Descripción:** Una línea explicando el problema.

**Impacto:** Mantenibilidad, performance, seguridad, legibilidad.

**Acción:** Qué hacer para resolverlo.

**Esfuerzo:** Bajo | Medio | Alto
```
