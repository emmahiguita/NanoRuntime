# 💻 GUÍA DE EJECUCIÓN NATIVA EN TERMUX (ANDROID)

Dispositivo: **OPPO CPH2557** (Android 14/15, `arm64-v8a`, 7.8 GB RAM)  
Binario y Modelos Ubicados en: `/data/local/tmp/`

---

## 📱 APLICACIÓN TERMUX ABIERTA EN EL DISPOSITIVO ANDROID

![Captura de Pantalla Real de Termux en OPPO CPH2557](file:///C:/Users/emman/.gemini/antigravity-ide/brain/be4e9ed9-4315-4133-8c32-e33ef7292dea/termux_screen.png)

*Figura 1: Aplicación Termux iniciada en tiempo real en la pantalla del dispositivo OPPO CPH2557 vía ADB Intent (`com.termux/.app.TermuxActivity`).*

---

## 🚀 PASOS PARA EJECUTAR DENTRO DE LA APLICACIÓN TERMUX

Abre la aplicación **Termux** en tu teléfono móvil e ingresa los siguientes comandos:

### Opción 1: Ejecución Directa desde el Almacenamiento Compartido
```bash
export LD_LIBRARY_PATH=/data/local/tmp
/data/local/tmp/nanortime --model /data/local/tmp/qwen.gguf --prompt "<|im_start|>user\nHola desde Termux! Explicame en una frase que es un algoritmo.\n<|im_end|>\n<|im_start|>assistant\n" --max-tokens 50 --edge-only
```

### Opción 2: Para el Modelo 7B (DeepSeek) en Termux
```bash
export LD_LIBRARY_PATH=/data/local/tmp
/data/local/tmp/nanortime --model /data/local/tmp/deepseek.gguf --prompt "Explain virtual memory" --max-tokens 50 --edge-only --tune-system
```

---

## 📊 EJEMPLO DE REGISTRO REAL EN VIVO (TERMUX / ANDROID ARM64)

```text
2026-07-31T01:22:52.386003Z  INFO NanoAI Runtime v0.1.0
2026-07-31T01:22:52.387128Z  INFO Memory-aware context: 8192 (3895MB available, 1065MB model)
2026-07-31T01:22:52.896457Z  INFO SSD benchmark: write=875 MB/s read=621 MB/s avg=748 MB/s
2026-07-31T01:22:52.899182Z  INFO NanoMemoryEngine init: 32 layers, 7639 MB RAM, 748 MB/s SSD, MidEnd
2026-07-31T01:22:53.823410Z  INFO Loaded model: /data/local/tmp/qwen.gguf (151936 vocab)

 Hello! How can I assist you today?
[METRICS] tokens=10 elapsed_ms=8618 tok_s=1.16 tier=local confidence=0.767
```
