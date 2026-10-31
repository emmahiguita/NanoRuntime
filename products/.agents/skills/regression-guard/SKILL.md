---
name: regression-guard
description: Use when fixing a reproducible bug or preventing a previously fixed defect from returning.
---

# Regression Guard

1. Revisar el fallo reportado y el código afectado.
2. Consultar regresiones conocidas relacionadas.
3. Reproducir el comportamiento defectuoso en dispositivo o entorno estático.
4. Crear o identificar una comprobación/test que demuestre la causa raíz.
5. Implementar la corrección mínima suficiente sin romper contratos existentes.
6. Confirmar que la verificación ahora pasa.
7. Ejecutar análisis estático (`dart analyze`) y compilación.
8. Registrar la causa raíz y la regla protectora.

## Casos y Reglas Protectoras Aprendidas

### 1. Espacio vacío inferior al activar Modo Drawer
- **Síntoma**: Al cambiar a Modo Drawer (icono del búho arriba a la izquierda), queda una franja blanca/vacía masiva en la parte inferior de la pantalla.
- **Causa Raíz**:
  1. `NanoDockViewport` recibía un `reserve` positivo (mínimo 58 dp + insets) calculado en `nano_navigation_panel.dart` incluso cuando el dock inferior estaba apagado (`!navState.isBottomBarMode`).
  2. Vistas como `SettingsScreen` y `MessagingCenterView` calculaban `kNanoBarScrollReserve` de manera estática sin comprobar si la barra inferior estaba realmente activa.
- **Solución Obligatoria**:
  - En `nano_navigation_panel.dart`: Si `!isBottomBar`, `baseReserve = 0.0`, `measuredReserve = 0.0` y `reserve = 0.0`.
  - En las pantallas (`SettingsScreen`, `MessagingCenterView`): Si `!navState.isBottomBarMode`, usar únicamente el padding seguro del sistema (`padding.bottom + 16/20`), eliminando la reserva de 116 dp.
- **Verificación**: Comprobar en dispositivo físico que el contenido se extienda fluidamente hasta la barra de navegación del sistema sin huecos artificiales.
