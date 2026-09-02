# A9 — Targeted OCR Perception

> Estado: IMPLEMENTADO · WIRED · BUILD OK · DEVICE-VERIFIED: NO (backend real sin
> prueba en device físico).

## Propósito

OCR dirigido como fallback de percepción cuando ObjectMemory → Accessibility →
ScreenGraph no resuelven con confianza suficiente. Nunca OCR permanente, nunca
OCR full-screen por defecto, nunca generación directa de acciones.

## Backend elegido

ML Kit Text Recognition (bundled `com.google.mlkit:text-recognition:16.0.1`,
on-device, sin Google Play Services), detrás de `OcrBackend`. Captura de pantalla
vía `AccessibilityService.takeScreenshot` (API 30+). Sin captura MediaProjection
(no requiere permiso de proyección adicional).

## Captura utilizada

`AccessibilityService.takeScreenshot` (API 30+). API 26-29 no soportada
(documentado: se devuelve unavailable). Crop de región en nativo (`Bitmap.createBitmap`).

## Targeted-first

`PerceptionRequest.region` define la región objetivo. Si `region == null` → full
screen (solo cuando no hay región útil Y policy/budget lo permiten). Los tests
prueban que el crop recibe la región, no full-screen.

## Budget / policy

`PerceptionBudget.maxOcrCalls = 1` (default A9). `ObservationPolicy.allowOcr = true`
(default A9). Accessibility resuelto → 0 OCR (el mux retorna antes). Budget 0 →
OCR no llamado.

## Confidence

OCR engine confidence ≠ target match confidence. ML Kit no expone confidence
granular fiable → confidence fija 0.85 documentada. El matching usa el texto
OCR contra el concepto (contains).

## Fusión / conflictos

`PerceptionFusionEngine.fuse(accObject, ocrObservation)` → evidencia combinada
[accessibility, ocr]. NO inventa role (el objeto accesible conserva su role
factual). Si Accessibility ya resolvió → no hay OCR (no se sobrescribe).

## Seguridad

Texto OCR = OBSERVACIÓN NO CONFIABLE. Nunca goal/instrucción/policy/capability/
privilege/tool/CandidateAction. Regression test explícito.

## Privacidad

Sin persistencia de screenshots. Bitmap reciclado tras OCR. Sin logging de
contenido sensible. El screenshot no cruza el MethodChannel (captura+OCR en
nativo).

## Rendimiento

1 captura + 1 OCR solo cuando Accessibility falla. Milisegundos en ML Kit para
regiones pequeñas. 0 LLM.

## Device verification

IMPLEMENTED BUT NOT DEVICE-VERIFIED. Falta prueba real en dispositivo Android
(API 30+) sobre una región conocida.

## Limitations

- `takeScreenshot` API 30+ (API 26-29 sin OCR).
- ML Kit no da confidence granular (0.85 fijo).
- OCR no crea CandidateAction (eso es futuro ScreenGraphCandidateProvider).
- No fusiona OCR con bounds en coordenadas de pantalla absolutas (relativo a la
  imagen capturada).

## A10 seam

`PerceptionInsufficient(recommendedSource: vision)` queda como seam para A10
(VisionBackend → cropped visual detection). No se llama vision fake.
