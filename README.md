# NanoRuntime

Runtime de inferencia LLM para Android con gestión de memoria consciente de recursos.
Ejecuta modelos 7B en dispositivos con menos de 4 GB RAM sin OOM crashes.

## Características

- **Graceful Degradation**: Reduce contexto automáticamente (8192→512) cuando la RAM es insuficiente
- **OS-Level Memory Paging**: `madvise(DONTNEED)` quirúrgico por capa, RSS variance < 1 MB
- **Auto-Configuration**: Detecta hardware (`/proc/meminfo`, thermal, battery) y se ajusta solo
- **OOM Guard**: Monitorea `oom_score` y activa modo supervivencia antes del crash
- **Thermal Controller**: Reduce carga si el dispositivo supera 42°C
- **Battery Guardian**: Modo Eco/Balanced/Survival según nivel de batería
- **Entropy Routing**: Confianza del modelo (`1 - H_norm`) decide local vs cloud
- **Memory Model**: 5 fórmulas validadas empíricamente para predecir RSS/VMA/throughput

## Validación

- 185+ consultas en 2 dispositivos físicos (Samsung A30s 3.72GB, OPPO CPH2557 7.8GB)
- 0 OOM crashes
- DeepSeek-R1-Distill-Qwen-7B (4.68GB) sobrevive en Samsung A30s (3.72GB RAM)
- Speculative decoding confirmado en hardware (OPPO, 111s run)

## Compilación

### Android ARM64 (via GitHub Actions — recomendado)

```bash
# 1. Push a GitHub
git push origin main
# 2. Actions → "Build NanoRuntime ARM64" → Run workflow
# 3. Descargar artifact "nanortime-arm64"
# 4. Desplegar:
adb push nanortime-arm64.tar.gz /data/local/tmp/
adb shell "cd /data/local/tmp && tar -xzf nanortime-arm64.tar.gz"
```

### Local (Windows)

```bash
cargo build --release -p nanortime-cli
# Binario: target/release/nanortime.exe
```

### Cross-compile ARM64

```bash
cargo build --target aarch64-linux-android --release -p nanortime-cli
# Requiere NDK configurado en ANDROID_NDK_HOME
```

## Uso

```bash
# Chat simple
nanortime --model qwen.gguf --prompt "¿Qué es la IA?"

# Con gestión de memoria avanzada
nanortime --model deepseek.gguf --prompt "hola" --tune-system

# Respuestas completas sin cortes
nanortime --model qwen.gguf --prompt "explica X" --natural-stops --temperature 0.3
```

## Arquitectura

```
nanortime-core/src/
├── memory_engine/       # 15+ módulos de gestión de memoria
│   ├── hardware_hal.rs        # Detección de hardware
│   ├── auto_config.rs         # Auto-configuración
│   ├── execution_planner.rs   # Planificador (RAM+thermal+battery)
│   ├── oom_guard.rs           # Monitor OOM Killer
│   ├── thermal_controller.rs  # Control térmico
│   ├── battery_guardian.rs    # Guardián de batería
│   ├── memory_model.rs        # 5 fórmulas del Memory Model
│   ├── cache_aware_loader.rs  # Layer streaming (VMA < 1GB)
│   └── ...
├── orchestrator/        # Routing, confianza, privacidad
├── execution/           # ModelManager, MemoryManager, tools
└── streaming_output.rs  # Streaming token a token
```

## Licencia

Código bajo licencia privada. Contacto: emmanuel.higuita.gomez@gmail.com
