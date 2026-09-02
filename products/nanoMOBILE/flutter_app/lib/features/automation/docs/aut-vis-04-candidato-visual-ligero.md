# AUT-VIS-04 — Evaluación de candidato visual ligero

**Decisión: NO integrar un modelo visual dedicado en esta fase.**

## Evaluación (criterios del protocolo)

| Criterio | Estado actual (OCR + ScreenGraph + estructura) |
|---|---|
| Model file size | 0 (sin modelo adicional) |
| RAM peak | 0 adicional (ML Kit Image Labeling bajo demanda, ya integrado) |
| Load time | 0 para el flujo (ML Kit ~1s bajo demanda) |
| Inference latency | n/a en el camino principal |
| CPU/GPU/NPU | n/a |
| Quantization | n/a |
| Android support | n/a (ML Kit ya soportado) |
| UI grounding quality | Accesibilidad + OCR cubren los casos reales validados |
| Ability to unload | n/a |

## Justificación (regla del protocolo)

"NO elegir un modelo grande si OCR + ScreenGraph ya resuelven el caso."

Los casos reales encontrados en validación fueron resueltos con señales
estructurales:
- Iconos de acción (ImageView con content-desc) → perfiles con role image.
- Campo de búsqueda sin identidad accesible → único editable enfocado.
- Resultados patrocinados → exclusión por términos.
- Pantallas desconocidas → escalado OCR + grounding estructural.

## Cuándo volver a evaluar

- Una pantalla donde Accessibility ✗, OCR ✗ y memoria ✗ impida un flujo real.
- Candidatos pre-aprobados por contrato: MobileNet-SSD (cuantizado) o un
  detector de UI pequeño; NUNCA un VLM grande residente.
- El contrato ya existe: `VisionBackend` (vision_contracts.dart) + la
  política de recursos (`VisualResourcePolicy`, AUT-VIS-03) — integrar un
  modelo nuevo NO toca el core.
