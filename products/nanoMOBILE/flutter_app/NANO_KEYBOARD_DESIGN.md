# Nano Keyboard 2026 — Especificación y Tokens de Diseño Material 3 Expressive

## 1. Identidad Visual y Concepto
- **Concepto**: Minimalismo iOS + Material 3 Expressive + Identidad original del Búho Nano.
- **Rostro del Búho**: Integrado en la barra superior en `(28 * density) dp`, utilizando el recurso oficial transparente (`R.drawable.nano_owl_idle`) sin deformación ni reemplazo por emojis.
- **Geometría de Teclas**: Bordes redondeados uniformes de **7.5 dp**, trazo perimetral fino de `0.7 dp` y separación de `2.2 dp` horizontal y `3.5 dp` vertical.

---

## 2. Tokens de Color Semánticos

### Tema Claro (Light Mode)
- **Superficie / Fondo IME**: `#F0F2F5`
- **Teclas Alfanuméricas**: `#FFFFFF`
- **Teclas Especiales (Shift, Backspace, ?123, Modos)**: `#DDE2E9`
- **Acción Principal (Enter/Enviar/Buscar)**: `#6087B2` (Acento Azul Nano, sin verde chillón)
- **Texto Principal**: `#20242B`
- **Texto Secundario / Sugerencias**: `#646C78`
- **Borde de Tecla**: `#D6DAE2`
- **Estado Presionado (Touch Feedback)**: `#E4E7ED`
- **Fondo de Barra de Herramientas**: `#EAECEF`
- **Divisor Superior**: `#D1D5DB`

### Tema Oscuro (Dark Mode)
- **Superficie / Fondo IME**: `#1C1F25`
- **Teclas Alfanuméricas**: `#343942`
- **Teclas Especiales**: `#454B55`
- **Acción Principal**: `#8EAED7` (Acento Azul Nano Claro)
- **Texto Principal**: `#F6F7FA`
- **Texto Secundario / Sugerencias**: `#BEC5D0`
- **Borde de Tecla**: `#3C424E`
- **Estado Presionado**: `#4C5360`
- **Fondo de Barra de Herramientas**: `#15171B`
- **Divisor Superior**: `#2D3139`

---

## 3. Tipografía y Métricas
- **Fuente**: `sans-serif` nativa del sistema.
- **Teclas de Caracteres**: 19 sp (letras simples) / 13 sp (símbolos compuestos o etiquetas).
- **Espacio**: 12 sp.
- **Acción Contextual (Enter)**: 13.5 sp.
- **Barra de Sugerencias**: 13.5 sp con pills redondeados a 6 dp.
- **Panel de Emojis**: 21 sp para visualización cómoda y nítida.
- **Altura de Tecla**: 46 dp en modo vertical; 34 dp en modo horizontal para no obstaculizar la app anfitriona.
