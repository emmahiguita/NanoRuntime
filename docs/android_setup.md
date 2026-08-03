# NanoAI Runtime — Android ARM64 Setup & Deployment Guide

Esta guía documenta la configuración paso a paso para compilar y ejecutar **NanoAI Runtime** en dispositivos móviles Android (ARM64 `aarch64-linux-android`).

---

## 📋 Requisitos Previos

1. **Android NDK** r26b o superior ([descargar](https://developer.android.com/ndk/downloads)).
2. **Rust & Target ARM64**:
   ```bash
   rustup target add aarch64-linux-android
   rustup target add armv7-linux-androideabi
   ```
3. **cargo-ndk**:
   ```bash
   cargo install cargo-ndk
   ```

---

## 🚀 Compilación para Android ARM64

### 1. Configurar variables de entorno

```bash
export ANDROID_NDK_HOME=$HOME/android-ndk-r26b
export PATH=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH
```

### 2. Compilar librería nativa (.so)

```bash
cargo ndk -t arm64-v8a -o ./android-libs build --features simulated --release
```

El resultado se genera en `./android-libs/arm64-v8a/libnanortime_ffi.so`.

---

## 📱 Ejecución en Dispositivo Android (vía ADB / Termux)

### Opción A: Termux en Android

```bash
# 1. Copiar el binario al dispositivo vía ADB
adb push ./target/aarch64-linux-android/release/nanortime /data/local/tmp/

# 2. Asignar permisos de ejecución y correr
adb shell
cd /data/local/tmp
chmod +x nanortime
./nanortime --prompt "Hola desde Android ARM64"
```

### Opción B: Integración en App Android (JNI Kotlin/Java)

```kotlin
class NanoAIActivity : AppCompatActivity() {
    companion object {
        init {
            System.loadLibrary("nanortime_ffi")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Inicializar NanoAI Runtime en Android
    }
}
```

---

## 📊 Especificaciones Recomendadas en Android

| Dispositivo | RAM | Modelo Recomendado | Rendimiento Esperado |
|---|---|---|---|
| **Android Gama Alta** (S23/S24, Pixel 8) | 12 GB | Qwen 2.5 3B (Q4_K_M) | 10-15 tokens/sec |
| **Android Gama Media** (Galaxy A54, Redmi Note) | 6-8 GB | Qwen 2.5 1.5B (Q4_K_M) | 6-10 tokens/sec |
| **Android Gama Entrada** | 4 GB | DeepSeek 1.5B (Q4_0) | 3-6 tokens/sec |
