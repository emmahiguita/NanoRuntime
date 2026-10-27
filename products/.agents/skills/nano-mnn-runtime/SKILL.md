---
name: nano-mnn-runtime
description: Maintain Nano's optional MNN-LLM Android backend and Qwen Omni package safely.
---

# Nano MNN runtime maintenance

Use this workflow when changing MNN, Qwen Omni packaging, native inference lifecycle, or runtime routing in Nano Mobile.

## Ground rules

- Discover the existing model and lifecycle flow through codebase-memory first; read the relevant source before editing.
- Check the pinned official MNN and model revisions before relying on API, package layout, or supported media behavior.
- Keep backend selection in catalog metadata (`litertlm`, `mnn`, or `gguf`). Never infer an engine from a file extension.
- Keep MNN optional to the app runtime: ship native libraries only in configured Android variants and download model weights separately.
- Start MT6833/MediaTek devices on the verified CPU path. Enable another accelerator only after device-specific evidence.
- Do not state performance parity or device support without measurements on that device.

## Package installation

- Pin a repository revision and an allowlist of required files; do not download a moving branch or the full repository.
- Verify each file with the checksum scheme returned by the pinned source (Hugging Face LFS SHA-256 or Git blob SHA-1).
- Download into a temporary staging directory, verify the complete package, then promote it atomically and write its manifest.
- Treat a missing file, size mismatch, checksum mismatch, interrupted transfer, or failed promotion as not installed.
- Reuse Nano's existing downloader and progress/cancel flow; avoid a second download stack.

## Runtime lifecycle

- Allow one inference engine and one generation request at a time.
- Serialize load, generate, unload, and model switches through the owning lifecycle controller.
- Cancellation signals the native decoder, waits for its request to finish, then frees model resources.
- Wrap every `GetStringUTFChars` result in a scoped JNI owner; release all acquired buffers on every early return and before long inference begins.
- Release the loaded runtime on model switch, explicit unload, and application lifecycle shutdown; do not leave native work running after the screen/session is gone.
- Pass real local media paths to MNN's supported image/audio prompt format. Never replace media with invented placeholder text.
- Propagate native errors and measured timing to the existing UI; do not fabricate tokens, completion, or performance values.
- Mark unsupported runtime metrics explicitly unavailable; never serialize placeholder zeros as measured values.

## Android build and review

- Keep MNN's Android build limited to LLM/Omni and required transitive components; use shared libraries and separate build targets when required by current MNN CMake.
- Preserve the repository's NDK, CMake, Gradle, and ABI configuration unless build evidence requires a change.
- Build each distributed flavor, inspect packaged ABIs/native libraries and APK sizes, and check 16 KB page alignment before claiming distribution readiness.
- Run `flutter analyze` and the relevant Gradle assemble tasks. Do not add or run automated tests when the task owner requests manual validation only.
- If a physical device is available, install the artifact and manually check load, text/image/audio prompts, cancellation, switching, app exit, crashes, and background native processes.
- Record TTFT, tokens per second, and memory only from real device measurements; leave device validation pending when no device is connected.

## MNN references

- [MNN LLM guide](https://github.com/alibaba/MNN/blob/3.6.1/docs/transformers/llm.md)
- [MNN Android LLM app](https://github.com/alibaba/MNN/blob/3.6.1/apps/Android/MnnLlmChat/README.md)
- [Pinned Qwen2.5 Omni MNN package](https://huggingface.co/taobao-mnn/Qwen2.5-Omni-3B-MNN/tree/0377bda)
