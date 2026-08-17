# Cargo config — split repo/usuario

## Principio

`.cargo/config.toml` (este repo, versionado) contiene **solo lo portable**: linkers por
nombre (`x86_64-linux-gnu-gcc`), rustflags de CPU (`+neon,+dotprod,+fp16`), opciones
válidas en cualquier host. **Ninguna ruta de máquina.**

Las toolchains locales (Android NDK, ninja del SDK, `CC`/`CXX`/`AR` del NDK) van en el
config de **usuario**, no versionado:

- Windows: `%USERPROFILE%\.cargo\config.toml`
- Linux/macOS: `~/.cargo/config.toml`

Cargo fusiona ambos (repo + usuario + sistema) — la máquina con la toolchain instalada
compila sin variables manuales.

## Por qué

`[env]` de cargo no tiene scope por target (verificado en cargo 1.96: ni
`[target.<triple>.env]` ni `[target.'cfg(...)'.env]` inyectan a build scripts).
Un `[env]` global con rutas Windows contamina cualquier build Linux/WSL
(`CMAKE_MAKE_PROGRAM` apuntando a `C:\...` rompe el build nativo).

## Windows (esta máquina)

`%USERPROFILE%\.cargo\config.toml` ya contiene NDK 28.2 + ninja del SDK. Verificar:

```powershell
cargo check -p nanortime-core                          # nativo
cargo check --target aarch64-linux-android -p nanortime-core   # Android
```

## Ubuntu/WSL

No copies el config de usuario de Windows. Requisitos:

```bash
sudo apt install -y build-essential cmake ninja-build clang libclang-dev pkg-config libssl-dev
cargo build --workspace
```

`x86_64-unknown-linux-gnu` usa el gcc del sistema. Para Android desde Linux, los
workflows de CI (`build_android_arm64.yml`) instalan el NDK y setean `ANDROID_NDK`
como env — el `build.rs` de `llama-cpp-sys-2` lo auto-detecta.

## Raspberry Pi / aarch64 Linux

`[target.aarch64-unknown-linux-gnu]` solo define linker. El cross-build del C
(CMake) necesita `CMAKE_TOOLCHAIN_FILE` propio: el `build.rs` de llama-cpp-sys-2 solo
define toolchain para Android. Build nativo en la Pi o toolchain cross explícita.