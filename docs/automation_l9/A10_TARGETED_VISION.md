# A10 — Targeted Vision Perception

> Estado: DOMAIN COMPLETE · BACKEND NOT YET DEVICE-READY · NO WIRED (sin
> backend real).

## Propósito

Vision como ÚLTIMO escalado de percepción estructurada, después de ObjectMemory
→ Accessibility → OCR. Produce observaciones ESTRUCTURADAS (role/label/bounds/
confidence), nunca prosa ejecutable.

## Backend / modelo

**No hay backend local viable hoy**: el runtime NanoRuntime es text-only
(llama.cpp + embeddings BGE-micro). No existe VLM/CLIP/LLaVA/Qwen-VL/YOLO/ONNX/
MNN/MediaPipe. No se introdujo un backend falso: se reporta DOMAIN COMPLETE /
BACKEND NOT YET DEVICE-READY. A10 NO añade dependencias de visión (sección 44:
no blind dependency).

## Contratos

`VisionBackend.analyze(VisionRequest) → VisionResult`. `VisionObject { role
(SemanticRole, sin taxonomía duplicada), label, bounds, confidence, boundsSpace }`.
`VisionMode { detectObjects, locateTarget }`. `CoordinateSpace { screenAbsolute,
cropRelative, imageRelative }`.

## Targeted-first / full-screen last

`PerceptionRequest.region` define el crop. Full-screen solo si no hay región Y
policy.allowFullScreenVision Y budget.maxFullScreenVisionCalls > 0 (default 0).
Track separado (`fullScreenCalls`).

## Budget / policy

`maxVisionCalls = 1` (default). `maxFullScreenVisionCalls = 0` (default).
`allowVision = false` (default, conservador). `allowFullScreenVision = false`.
Vision es el último recurso y NO se habilita por defecto.

## Espacios de coordenadas

A10 establece semántica explícita de coordenadas (`CoordinateSpace`) y
transforma crop-relative → screen-absolute (`toScreenAbsolute`) ANTES de
devolver la observación. PROVEN BY UNIT TEST (Rect(100,200,400,500) + local
Rect(10,20,100,80) → (110,220,200,280)). A9 detectó el problema; A10 lo resuelve
para Vision (el retro-fit de OCR se documenta como deuda).

## Fusión / conflicto

`PerceptionFusionEngine.fuseWithVision(accObject, ocr, vision)` → evidencia
triple [accessibility, ocr, vision]. El role lo aporta Accessibility (factual);
Vision solo añade concepto visual. Precedencia: Accessibility structural >
OCR text > Vision role inference (no sobrescribe en conflicto).

## Seguridad

Contenido visual = OBSERVACIÓN NO CONFIABLE. Regression test: texto visual
malicioso → observación, no autoridad. Sin tap, sin ToolCall, sin CandidateAction.

## Privacidad / rendimiento

Sin persistencia de screenshots, sin upload, sin logging de imagen. Vision solo
cuando las 3 fuentes previas fallan. Sin VLM residente (futuro HOT/WARM/COLD).

## Device verification

IMPLEMENTED BUT NOT DEVICE-VERIFIED (y BACKEND NOT DEVICE-READY). Falta un
backend local real (detector/VLM pequeño) antes de validación física.

## Limitations

- Sin backend de visión real (runtime text-only).
- Bounds OCR (A9) siguen imageRelative (retro-fit pendiente).
- Vision no crea CandidateAction (futuro ScreenGraphCandidateProvider).

## A11 seam

Vision es la última fuente de percepción. A11 introduce la capa de GOBIERNO
(IntentSpec, IntentFirewall, PreActionCritic, PrivilegeBroker) antes de ampliar
autonomía.
