# QA Report — NanoAI v0.1.0
## Análisis completo de código, seguridad, arquitectura y performance

**Fecha:** 2026-08-07
**Método:** Análisis estático automatizado (cargo clippy, dart analyze) + revisión manual profunda de 35+ archivos
**Severidad:** 🔴 6 Críticos | 🟠 9 Altos | 🟡 5 Medios | 🟢 4 Bajos
**Total hallazgos:** 24

---

## 🔴 CRÍTICO #1 — nanortime-ffi no compila: macro `ffi_catch_unwind!` rota

**Archivo:** `nanortime-ffi/src/lib.rs:719`
**Lenguaje:** Rust
**Ingeniero(s):** ⚪ FFI Specialist, 🔴 Security Auditor

**Descripción:** La variante `()` de la macro `ffi_catch_unwind!` tiene un `;` al final que convierte la expresión en un statement. Cuando se usa como tail expression de un bloque (en `nano_model_free`, `nano_context_free`, `nano_string_free`), el compilador emite 6 errores — 3 de "expected expression, found let statement" y 3 de "trailing semicolon in macro used in expression position". Este warning era future-incompatible y ya es **hard error** en Rust actual. El crate **no compila**.

**Código actual:**
```rust
// Línea 718-720: la variante () termina con ;
($body:expr, ()) => {
    let _ = catch_unwind(AssertUnwindSafe(|| $body));  // ← el ; rompe todo
};
```

**Código corregido:**
```rust
($body:expr, ()) => {{
    let _ = catch_unwind(AssertUnwindSafe(|| $body));
}};
```

**Impacto:**
- Estabilidad: El build completo del workspace falla. CI (que corre `cargo clippy -- -D warnings`) está roto en main.
- Seguridad: Las funciones FFI que deberían tener catch_unwind NO lo tienen. Un panic en Rust dentro de una llamada desde C/Kotlin es **undefined behavior**.

---

## 🔴 CRÍTICO #2 — `weight_cache_aware` referenciado pero no existe

**Archivo:** `nanortime-core/src/memory_engine/cache_aware_loader.rs:140-141`
**Lenguaje:** Rust
**Ingeniero(s):** 🟡 Systems Architect

**Descripción:** `unmap_current()` referencia `crate::memory_engine::weight_cache_aware::WeightCacheManager` y `WeightCacheConfig`, **pero el archivo `weight_cache_aware.rs` NO existe** en `memory_engine/`. El directorio no lo contiene, grep no lo encuentra. Esto impide compilar `nanortime-core`.

**Código actual:**
```rust
let wc = crate::memory_engine::weight_cache_aware::WeightCacheManager::new(
    crate::memory_engine::weight_cache_aware::WeightCacheConfig::default()
);
let _ = unsafe { wc.mark_kv_cold(ptr as *mut u8, size) };
let _ = unsafe { wc.pageout_kv(ptr as *mut u8, size) };
```

**Código corregido:**
```rust
// Opción A: Crear el módulo weight_cache_aware.rs con las implementaciones
// Opción B: Si la feature no está lista, comentar estas líneas con feature-gate
#[cfg(feature = "weight-cache-v2")]
{
    let wc = crate::memory_engine::weight_cache_aware::WeightCacheManager::new(/*...*/);
    // ...
}
```

---

## 🔴 CRÍTICO #3 — JNI Bridge Kotlin ↔ Rust: las funciones nativas no existen

**Archivos:** `android/.../NanoRuntimeBridge.kt:81-89` + búsqueda en todos los `*.rs`
**Lenguaje:** Kotlin + Rust
**Ingeniero(s):** 🟠 Mobile Engineer, ⚪ FFI Specialist

**Descripción:** `NanoRuntimeBridge.kt` declara 4 métodos `external`:
- `nativeInitBackend(): Int`
- `nativeLoadModel(path: String, gpuLayers: Int): Long`
- `nativeFreeModel(handle: Long)`
- `nativeGenerateText(modelPath, prompt, maxTokens, temperature): String`

Pero en TODO el código Rust del proyecto, **no existe ninguna función con la convención JNI** (`Java_com_nanoai_data_runtime_NanoRuntimeBridge_*`). Las funciones `#[no_mangle] extern "C"` que existen (`nano_backend_init`, `nano_model_load`, etc. en `nanortime-ffi/src/lib.rs`) usan nombres C planos, no nombres JNI. Además, `nanortime-core` compila como `staticlib` pero `nanortime-ffi` compila como crate separado. La app Android carga `libnanortime_ffi.so` (línea 23 del bridge) pero el crate `nanortime-ffi` **no compila** (ver hallazgo #1).

El bridge JNI está **completamente no funcional**. La app Android solo funciona en "Safe Simulation Mode".

**Código corregido:**
```rust
// En nanortime-core o un crate específico para Android JNI:
#[no_mangle]
pub extern "system" fn Java_com_nanoai_data_runtime_NanoRuntimeBridge_nativeInitBackend(
    _env: JNIEnv, _class: JClass
) -> jint { /* ... */ }

#[no_mangle]
pub extern "system" fn Java_com_nanoai_data_runtime_NanoRuntimeBridge_nativeGenerateText(
    mut env: JNIEnv, _class: JClass,
    model_path: JString, prompt: JString,
    max_tokens: jint, temperature: jfloat
) -> jstring { /* ... */ }
```

---

## 🔴 CRÍTICO #4 — Command Injection en `tool_executor.rs`

**Archivo:** `nanortime-core/src/execution/tool_executor.rs:259-267`
**Lenguaje:** Rust
**Ingeniero(s):** 🔴 Security Auditor

**Descripción:** `execute_script()` ejecuta comandos shell con `sh -c` o `cmd /C` usando strings interpolados de templates sin sanitización. Un atacante que controle un tool definition JSON puede inyectar comandos arbitrarios: `"command": "echo hello; rm -rf /"`. Los parámetros se interpolan con `{{variable}}` pero el template mismo viene de JSON cargado del disco (tools/ directory) o registrado en runtime. Si `auto_discover` está activo, cualquier JSON en `tools/` se ejecuta.

**Código actual:**
```rust
std::process::Command::new("sh")
    .args(["-c", &resolved_cmd])  // ← ejecución directa sin sandbox
    .output()
```

**Código corregido:**
```rust
// Mínimo: validar el comando contra un allowlist
fn validate_command(cmd: &str) -> bool {
    // Solo permitir comandos seguros pre-registrados
    ALLOWED_COMMANDS.iter().any(|allowed| cmd.starts_with(allowed))
}
// Ideal: ejecutar en contenedor/sandbox (nsjail, bubblewrap, seccomp)
```

**Impacto:**
- Seguridad: Ejecución remota de código con privilegios del proceso NanoAI. En Android con proot, podría escapar el sandbox.

---

## 🔴 CRÍTICO #5 — `std::sync::Mutex` en FFI causa panics y deadlocks

**Archivo:** `nanortime-core/src/memory_engine/streaming_ffi.rs:16-17, 70-71, 86, 111, 120, 150`
**Lenguaje:** Rust
**Ingeniero(s):** ⚪ FFI Specialist, 🟢 Performance Engineer

**Descripción:** `streaming_ffi.rs` usa `std::sync::Mutex` en 6 lugares para proteger el `LOADER` y `LAYER_COUNT` globales. Estas funciones son `extern "C"` llamadas desde llama.cpp (C/C++). Tres problemas:
1. `.lock().unwrap()` — si el Mutex está poisoned (por un panic previo en otro hilo), **paniquea dentro de FFI** = UB.
2. `std::sync::Mutex` bloquea el thread del SO, no cede a async runtime. En un contexto C que espera la respuesta sincrónicamente, esto puede causar deadlocks si hay contención.
3. La documentación dice "Not thread-safe by design — must be called from the main thread" pero el código usa Mutex (herramienta de thread-safety). Contradicción.

**Código corregido:**
```rust
use std::sync::RwLock;
static LOADER: RwLock<Option<CacheAwareLoader>> = RwLock::new(None);

// Cambiar todos los .lock().unwrap() a:
let guard = LOADER.read().unwrap_or_else(|e| {
    tracing::error!("Loader lock poisoned: {:?}", e);
    return std::ptr::null_mut(); // o error code seguro
});
```

---

## 🔴 CRÍTICO #6 — `plan_survival` y `plan_cautious` usan `DeviceProfile::default()` falso

**Archivo:** `nanortime-core/src/memory_engine/execution_planner.rs:239-241, 280-281`
**Lenguaje:** Rust
**Ingeniero(s):** 🟡 Systems Architect, 🟠 Mobile Engineer

**Descripción:** Tanto `plan_survival()` como `plan_cautious()` construyen `RuntimeConfig` con `DeviceProfile::default()` en lugar de usar el perfil real del dispositivo. El perfil default tiene valores genéricos (RAM=0, tier=Budget, etc.) que no reflejan el dispositivo real. Esto significa que todas las decisiones de supervivencia (contexto, threads, batch, OOM threshold) se basan en datos **falsos** sobre el hardware.

**Código actual:**
```rust
let config = RuntimeConfig {
    // ...
    tier: DeviceProfile::default().tier,       // ← falso
    profile: DeviceProfile::default(),          // ← falso
};
```

**Código corregido:**
```ruby
// plan_survival debe recibir el DeviceProfile real como parámetro:
pub fn plan_survival(&self, available_mb: f64, total_mb: f64, profile: &DeviceProfile) -> PlanResult {
    let config = RuntimeConfig {
        tier: profile.tier,
        profile: profile.clone(),
        // ...
    };
}
```

---

## 🟠 ALTO #7 — `unsafe impl Send + Sync` para `NanoModel` es contradictorio

**Archivo:** `nanortime-ffi/src/lib.rs:78-79`
**Lenguaje:** Rust
**Ingeniero(s):** ⚪ FFI Specialist

**Descripción:** El comentario dice "llama.cpp allows using a model from any **single** thread" pero el código implementa `Sync` (múltiples threads pueden tener referencias compartidas). Si llama.cpp internamente tiene thread-local state o no es thread-safe para lecturas concurrentes, esto es **unsound** y puede causar data races en C.

---

## 🟠 ALTO #8 — O(n²) en chequeo de stop sequences

**Archivo:** `nanortime-ffi/src/lib.rs:372-374` (y 541-543 en `generate_streaming`)
**Lenguaje:** Rust
**Ingeniero(s):** 🟢 Performance Engineer

**Descripción:** En cada token generado, se clona el **string completo de output** (`output.clone()`) y se concatena el nuevo token solo para verificar stop sequences. Con 2048 tokens generados, esto es ~2M operaciones de clonación de strings.

**Código actual:**
```rust
let mut check = output.clone();  // O(n) clone cada token
check.push_str(&piece);          // → O(n²) total
if params.stop_sequences.iter().any(|s| check.contains(s)) { break; }
```

**Código corregido:**
```rust
// Solo verificar el sufijo del output contra stop sequences
let candidate = format!("{}{}", 
    &output[output.len().saturating_sub(64)..], piece);
if params.stop_sequences.iter().any(|s| candidate.ends_with(s) || candidate.contains(s)) { 
    break; 
}
```

---

## 🟠 ALTO #9 — Cálculo incorrecto de tokens-per-second

**Archivo:** `nanortime-ffi/src/lib.rs:380`
**Lenguaje:** Rust
**Ingeniero(s):** 🟢 Performance Engineer

**Descripción:** `tps` se calcula como `n_prompt as f64 / elapsed` — esto solo cuenta los tokens del prompt, **no los tokens generados**. El resultado subestima drásticamente el throughput real reportado al usuario. Debería ser `(n_prompt + tokens_generated) / elapsed` o `tokens_generated / decode_time`.

---

## 🟠 ALTO #10 — `CacheAwareLoader` usa `Ordering::Relaxed` en punteros críticos

**Archivo:** `nanortime-core/src/memory_engine/cache_aware_loader.rs:108-109, 120, 125, 132-133, 150-151`
**Lenguaje:** Rust
**Ingeniero(s):** ⚪ FFI Specialist, 🟢 Performance Engineer

**Descripción:** `mmap_ptr` y `mmap_size` son `AtomicUsize` con `Ordering::Relaxed` en todas las operaciones. Pero `get_layer_ptr()` (unsafe, línea 115) lee `mmap_ptr` con Relaxed y luego hace `base.add(offset)` — si otro hilo está ejecutando `unmap_current()` concurrentemente, la lectura Relaxed no garantiza visibilidad del nuevo valor ni del munmap. En teoría el Mutex en `streaming_ffi.rs` serializa el acceso, pero dentro de `CacheAwareLoader` mismo no hay protección. Si alguna vez se usa sin Mutex externo, hay riesgo de use-after-free.

**Corrección:** Cambiar loads a `Ordering::Acquire` y stores a `Ordering::Release`.

---

## 🟠 ALTO #11 — `OSMemoryPaginator`: `Send + Sync` con raw pointer

**Archivo:** `nanortime-core/src/memory_engine/os_paginator.rs:37-38`
**Lenguaje:** Rust
**Ingeniero(s):** ⚪ FFI Specialist

**Descripción:** `OSMemoryPaginator` contiene un raw pointer `mmap_ptr` pero implementa `Send + Sync` unsafe. Múltiples hilos concurrentes pueden llamar `prefetch_range()` y `evict_range()` con rangos solapados, resultando en comportamiento indefinido a nivel de SO (madvise concurrente en páginas solapadas).

---

## 🟠 ALTO #12 — Dos sistemas FFI diferentes coexistiendo

**Archivos:** `nanortime-ffi/src/lib.rs` y `nanortime-ffi/src/bindings.rs`
**Lenguaje:** Rust + C
**Ingeniero(s):** 🟡 Systems Architect

**Descripción:** `lib.rs` exporta funciones `nano_backend_init`, `nano_model_load`, etc. usando la Rust `llama-cpp-2` crate. `bindings.rs` declara funciones `nanortime_backend_init`, `nanortime_load_model`, etc. que supuestamente vienen de un `bridge.cpp` externo. Son **dos APIs diferentes** que probablemente eran parte de una migración. `bindings.rs` parece abandonado — sus tests están `#[ignore]`, no hay `bridge.cpp` en el repositorio. Es código muerto que confunde y podría causar link errors.

---

## 🟠 ALTO #13 — CI no ejecuta auditoría de dependencias

**Archivo:** `.github/workflows/ci.yml`
**Lenguaje:** YAML
**Ingeniero(s):** 🟣 DevOps/SRE

**Descripción:** El CI hace `cargo fmt`, `cargo clippy`, `cargo test`, y `cargo build` para 3 OS. Pero **no ejecuta `cargo audit`** para detectar CVEs en dependencias, **no ejecuta `cargo deny`** para licencias, **no ejecuta `cargo geiger`** para unsafe, **no ejecuta `dart analyze`** para Flutter, **no ejecuta `eslint`** para dashboard. El CI test/lint corre solo en ubuntu-latest — los tests específicos de Windows y macOS nunca se ejecutan.

---

## 🟠 ALTO #14 — Silenciamiento total de logs de llama.cpp

**Archivo:** `nanortime-ffi/src/lib.rs:51`
**Lenguaje:** Rust
**Ingeniero(s):** 🟣 DevOps/SRE

**Descripción:** `llama_log_set(Some(noop_llama_log), ...)` suprime TODOS los logs de llama.cpp incluyendo errores de carga de modelo, fallos de asignación de memoria, y warnings de cuantización. En producción, si un modelo GGUF está corrupto, no habrá absolutamente ningún mensaje de error — la carga simplemente fallará con un error genérico.

---

## 🟠 ALTO #15 — `transmute` de lifetime a `'static` en FFI

**Archivo:** `nanortime-ffi/src/lib.rs:172, 217`
**Lenguaje:** Rust
**Ingeniero(s):** ⚪ FFI Specialist

**Descripción:** `std::mem::transmute(inner)` para extender el lifetime de `LlamaContext` a `'static`. El comentario dice "ModelManager guarantees NanoModel outlives all contexts" pero transmute **bypassea el borrow checker completamente**. Si ModelManager tiene un bug, esto es UB silencioso (use-after-free del modelo C subyacente).

---

## 🟡 MEDIO #16 — `unwrap()` en stdin/stdout de child process

**Archivo:** `nanortime-core/src/execution/tool_executor.rs:326-327`
**Lenguaje:** Rust
**Ingeniero(s):** 🔵 QA Lead

**Descripción:** `execute_mcp()` hace `child.stdin.take().unwrap()` y `child.stdout.take().unwrap()`. Si la creación del proceso falla parcialmente (piped pero sin stdin/stdout), esto paniquea.

---

## 🟡 MEDIO #17 — Regex compilado en cada llamada

**Archivo:** `nanortime-core/src/execution/tool_executor.rs:419-421`
**Lenguaje:** Rust
**Ingeniero(s):** 🟢 Performance Engineer

**Descripción:** `interpolate_template()` compila un `Regex::new()` en cada llamada. Debería ser un `LazyLock<Regex>` estático.

---

## 🟡 MEDIO #18 — Dart: `print()` en código de producción + variables no usadas

**Archivos:** `flutter_app/lib/core/services/shell_executor.dart:73,76,140` y `command_dispatcher.dart`
**Lenguaje:** Dart
**Ingeniero(s):** 🔵 QA Lead

**Descripción:** `dart analyze` reporta `avoid_print` en shell_executor (3 ocurrencias), `unused_element` para `_bashPath` y `_toyboxPath`, y `unnecessary_null_comparison` en command_dispatcher. 17 packages desactualizados.

---

## 🟡 MEDIO #19 — Server Python: nombre de GPU hardcodeado como fallback

**Archivo:** `server/main.py:75`
**Lenguaje:** Python
**Ingeniero(s):** 🟣 DevOps/SRE

**Descripción:** `CACHED_GPU_METRICS` inicializa con `"NVIDIA GeForce RTX 3050 6GB Laptop GPU"` hardcodeado. Si nvidia-smi no está disponible, el dashboard mostrará este valor falso en vez de "N/A".

---

## 🟡 MEDIO #20 — CI: `cargo clippy -- -D warnings` rompe el build trivialmente

**Archivo:** `.github/workflows/ci.yml:45`
**Lenguaje:** YAML
**Ingeniero(s):** 🟣 DevOps/SRE

**Descripción:** El CI trata todos los warnings de clippy como errores. El warning `uninlined_format_args` en `nanortime-ffi/build.rs` (línea 17) ya rompe el build. Sumado a los 6 hard errors de la macro, el CI está permanentemente rojo.

---

## 🟢 BAJO — Varios hallazgos menores

21. **`nanortime-ffi/build.rs:17`** — `uninlined_format_args` (clippy pedantic)
22. **`cache_aware_loader.rs:108-109`** — `libc::madvise` resultado no verificado (línea 106)
23. **`hybrid_router.rs:90-93`** — Los pesos del scoring (0.25, 0.15, 0.35) son "empíricos" sin calibración documentada. El umbral 0.45 puede no generalizar entre modelos/lenguajes.
24. **`orchestrator/router.rs`** — El router NUNCA rutea a Cloud directamente (línea 61 retorna Local). El comentario dice "escalation happens post-generation" pero no hay código de escalación visible en el router. ¿Dónde está?

---

## Resumen de dependencias

| Herramienta | Estado |
|---|---|
| `cargo audit` | ❌ No instalado |
| `cargo deny` | ❌ No instalado |
| `cargo geiger` | ❌ No instalado |
| `cargo outdated` | ❌ No ejecutado |
| `dart analyze` | ✅ 17 packages outdated, múltiples warnings |
| `flutter analyze` | ✅ Warnings no críticos |
| `eslint` (dashboard) | ❌ No ejecutado |
| `npm audit` (dashboard) | ❌ No ejecutado |
| `pip-audit` (server) | ❌ No ejecutado |

---

## Prioridad de acción

1. **Arreglar `ffi_catch_unwind!` macro** — el proyecto no compila (hallazgo #1)
2. **Crear o eliminar referencia a `weight_cache_aware`** — bloquea compilación de nanortime-core (hallazgo #2)
3. **Implementar JNI exports reales** — la app Android solo funciona en simulación (hallazgo #3)
4. **Sanitizar `execute_script`** — command injection (hallazgo #4)
5. **Reemplazar `std::sync::Mutex` en FFI** — panics crossing FFI boundary (hallazgo #5)
6. **Corregir `DeviceProfile::default()` en survival plans** — decisiones basadas en datos falsos (hallazgo #6)
7. **Instalar `cargo-audit` en CI y local** — deuda de seguridad

---

*Reporte generado aplicando QA Master Prompt v10.0 adaptado a NanoAI. Análisis sobre 35+ archivos en Rust, Kotlin, Dart, TypeScript y Python.*
