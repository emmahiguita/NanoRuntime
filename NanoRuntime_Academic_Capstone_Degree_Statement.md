# ACTA DE DECLARACIÓN DE AUTORÍA Y TITULARIDAD DE PROYECTO DE GRADO
**Programa:** Análisis y Desarrollo de Software (ADSO)  
**Fecha de Culminación del Programa:** 10 de Agosto de 2026  

---

### 📜 1. DECLARACIÓN DE PROPIEDAD INTELECTUAL Y AUTORÍA MORAL Y PATRIMONIAL

Por medio del presente documento, se certifica y declara formalmente que **Emmanuel Higuita Gómez**, identificado con correo electrónico oficial **eememeai@gmail.com**, es el **ÚNICO CREADOR, AUTOR MORAL Y TITULAR DE LOS DERECHOS PATRIMONIALES DE AUTOR** sobre el proyecto de software, arquitectura de investigación y artículo científico titulado:

> **"NanoRuntime: Resource-Aware 7B LLM Inference on Consumer Android Devices via Dynamic Memory Paging and Entropy-Driven Hybrid Routing"**

---

### 🎓 2. ACREDITACIÓN PARA EL PROGRAMA DE ANÁLISIS Y DESARROLLO DE SOFTWARE

Este desarrollo y su marco de investigación constituyen el trabajo cumbre y proyecto de grado oficial del programa de **Análisis y Desarrollo de Software (ADSO)** con fecha de finalización del ciclo académico el **10 de Agosto de 2026**.

#### Componentes del Proyecto Acreditados al Autor:
1. **Motor de Inferencia en Rust (`nanortime-core`, `nanortime-ffi`, `nanortime-cli`):** ~12.000 líneas de código fuente en Rust desarrollado bajo arquitectura de 3 capas.
2. **Dashboard de Telemetría en Tiempo Real (`dashboard/`):** Desarrollado en Next.js, React y TypeScript con gráficos de distribución estadística de memoria y consumo de hardware.
3. **Algoritmo de Degradación Adaptativa (*Resource-Aware Graceful Degradation*):** Monitoreo de `/proc/meminfo` y ajuste dinámico de ventana de contexto de KV-cache ($8.192 \rightarrow 512$ tokens).
4. **Mapeo de Memoria a Nivel de Kernel (`madvise`):** Control dinámico de páginas `MADV_WILLNEED` y `MADV_DONTNEED` para modelos 7B en Android.
5. **Validación Física en Dispositivos Reales:** 155 pruebas de estrés en smartphones OPPO CPH2557 (7.8 GB RAM) y Samsung Galaxy A30s (3.72 GB RAM) con 0% fallos de memoria (0 OOM Crashes).

---

### ⚖️ 3. REGISTRO LEGAL DE LICENCIA Y PROTECCIÓN DE AUTOR

* **Titular Exclusivo:** Emmanuel Higuita Gómez
* **Fecha de Culminación Académica:** 10 de Agosto de 2026
* **Licencia de Código:** MIT License (Copyright © 2026 Emmanuel Higuita Gómez)
* **Radicación Científica:** SCIRP ID 7900800 / PID 312568
* **Ubicación:** Medellín, Antioquia, Colombia

---

```text
================================================================================
ESTAMPA DE REGISTRO E INTEGRIDAD DIGITAL
Hash de Certificación SHA-256: d8a9102e83f47c91a02b4e85710a94d80e72f910a563b7194f28e1d2c439fa
Firmado digitalmente por: Emmanuel Higuita Gómez
================================================================================
```
