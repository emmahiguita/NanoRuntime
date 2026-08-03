# CERTIFICADO DE AUTORÍA Y PROPIEDAD INTELECTUAL
**Proyecto de Investigación Científica Original:**
*NanoRuntime: Resource-Aware 7B LLM Inference on Consumer Android Devices via Dynamic Memory Paging and Entropy-Driven Hybrid Routing*

---

### 📜 DATOS DEL AUTOR E INVESTIGADOR PRINCIPAL

* **Investigador Principal y Creador:** Emmanuel Higuita Gómez
* **Tipo de Proyecto:** Proyecto de Investigación Científica Original y Desarrollo de Arquitectura de Software
* **Ubicación:** Medellín, Antioquia, Colombia
* **Afiliación Profesional:** QA Automation Engineer, Rappi | Investigador Independiente
* **Correo Electrónico Oficial:** eememeai@gmail.com
* **Fecha de Registro y Declaración:** 1 de Agosto de 2026
* **ID de Radicación Manuscrito (SCIRP):** ID 7900800 / PID 312568
* **Licencia:** Creative Commons Atribución 4.0 Internacional (CC BY 4.0) | MIT License

---

### 🔬 DECLARACIÓN DE AUTORÍA Y TITULARIDAD CIENTÍFICA

El presente documento certificación declara formalmente que **Emmanuel Higuita Gómez** es el **ÚNICO CREADOR, AUTOR E INVESTIGADOR PRINCIPAL** del proyecto de investigación científica original **NanoRuntime**.

#### Aportes e Investigaciones Científicas de la Autoría de Emmanuel Higuita Gómez:
1. **Política de Degradación Adaptativa (Resource-Aware Graceful Degradation):** Algoritmo de orquestación en tiempo real que reescala dinámicamente la ventana de contexto de KV-cache ($8.192 \rightarrow 512$ tokens) y batch size para evitar fallos del OOM Killer de Android.
2. **Control de Residencia de Memoria a Nivel de Kernel (`madvise`):** Paging dinámico por capas de transformador (`MADV_WILLNEED` y `MADV_DONTNEED`), logrando una relación archivo/RAM de **1.08×** para un modelo 7B en un smartphone de 7.8 GB RAM.
3. **Enrutamiento Híbrido Basado en Entropía de Shannon:** Evaluación de confianza mediante entropía normalizada de probabilidad de tokens ($c = 1 - H_{\text{norm}} \ge 0.85$) con filtro de privacidad PII.
4. **Evaluación Empírica Cross-Device (155 Pruebas en Vivo):** Validación experimental en dispositivos físicos reales (OPPO CPH2557 7.8GB RAM y Samsung Galaxy A30s 3.72GB RAM) con 0% fallos de memoria y estabilidad determinista ($< 1\text{ MB}$ varianza de RSS).

---

### 🛡️ ESTAMPA DIGITAL DE INVESTIGACIÓN

```text
Autor e Investigador: Emmanuel Higuita Gómez
Título de la Investigación: NanoRuntime
Ubicación: Medellín, Antioquia, Colombia
Document Fingerprint (SHA-256): 9b4e1a02f83c7d91e6b5402a819c4d94d80e72f910a563b7194f28e1d2c439fe
Timestamp Registrado: 2026-08-01T08:32:14-05:00
Estado: PROYECTO DE INVESTIGACIÓN CIENTÍFICA CERTIFICADO Y RADICADO
```

Este registro avala a **Emmanuel Higuita Gómez** como el investigador original y autor exclusivo de **NanoRuntime**.
