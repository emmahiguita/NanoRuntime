# NANORUNTIME — DOCUMENTO PROFESIONAL COMPLETO
# ===========================================
# Autor: Emmanuel Higuita Gómez
# QA Automation Engineer, Rappi | Medellín, Antioquia, Colombia
# Fecha: Agosto 2026
# Versión: 2.0 — Auditoría + Datos + Orquestación + Autoría
# 
# APTO PARA: Minciencias, Universidad, Tesis, Conferencia, Patente

================================================================================
PARTE 0 — DECLARACIÓN DE AUTORÍA
================================================================================

PROYECTO: NanoRuntime — Motor de inferencia LLM para dispositivos Android
         de bajo recurso con orquestación híbrida edge-cloud.

AUTOR PRINCIPAL:
  Emmanuel Higuita Gómez
  QA Automation Engineer — Rappi
  Medellín, Antioquia, Colombia
  ORCID: [pendiente de registro]

ROL DEL AUTOR:
  - Arquitectura del sistema (~80 módulos Rust + C: 72 fuentes Rust, 8 fuentes C)
  - Diseño e implementación del Memory Engine V2
  - Integración con llama.cpp mediante FFI
  - Desarrollo del CacheAwareLoader (streaming de capas)
  - Pipeline CI/CD (GitHub Actions: fmt, clippy, test, security audit; cross-compilation ARM64 local vía Android NDK + rustc)
  - Experimentación en hardware real (Samsung A30s, OPPO CPH2557)
  - Recolección y análisis de datos (185+ consultas)
  - Redacción del paper y documentación técnica

RECONOCIMIENTOS:
  - llama.cpp: motor de inferencia base (Georgi Gerganov, MIT license)
  - Comunidad HuggingFace: modelos pre-entrenados y cuantizados
  - Google Gemini API: usado en modo consulta para asistencia en desarrollo
  - Rappi: empleador del autor (sin relación con este proyecto)

PROPIEDAD INTELECTUAL:
  Este proyecto es investigación independiente del autor.
  No está afiliado ni financiado por Rappi.
  El código fuente es privado. El paper es público (black-box).

================================================================================
PARTE 1 — AUDITORÍA CIENTÍFICA COMPLETA
================================================================================

1.1 MÉTODO CIENTÍFICO APLICADO

PREGUNTA DE INVESTIGACIÓN:
  ¿Puede un modelo de lenguaje de 7 mil millones de parámetros ejecutar
  inferencia completa sin errores de memoria (OOM) en un dispositivo
  Android con menos RAM que el tamaño del modelo?

HIPÓTESIS:
  H1: La gestión de memoria a nivel de sistema operativo (mmap + madvise)
      permite que modelos que exceden la RAM disponible completen
      inferencia sin OOM mediante transmisión de capas bajo demanda.
  H2: En CPUs heterogéneas (big.LITTLE), limitar los hilos a los núcleos
      de alto rendimiento produce mayor throughput que usar todos los núcleos.
  H3: Para modelos con fase de razonamiento interno, la decodificación
      especulativa por n-gramas supera a la basada en modelo-draft.

1.2 DISEÑO EXPERIMENTAL

VARIABLES INDEPENDIENTES:
  - Dispositivo: Samsung A30s (3.7 GB, eMMC) / OPPO CPH2557 (7.8 GB, UFS)
  - Modelo: Qwen 2.5 1.5B Q4_K_M (1.0 GB) / DeepSeek R1 Distill Qwen 7B Q2_K (2.8 GB)
  - Estrategia: directo / model-draft speculative / NGRAM speculative
  - Threads: 2 (big cores) / 8 (all cores)

VARIABLES DEPENDIENTES:
  - Throughput (tokens/segundo)
  - Supervivencia (completa sin OOM: sí/no)
  - RAM consumida (RSS en MB)
  - Tiempo hasta primer token (ms)
  - Corrección de respuesta (juez humano)

CONTROL:
  - Temperatura = 0.0 (determinístico)
  - Mismo prompt para todas las pruebas
  - Sin aplicaciones en segundo plano
  - Dispositivo en modo avión

1.3 DATOS REALES (medidos agosto 2026)

TABLA 1 — Throughput 1.5B (Qwen 2.5 1.5B Q4_K_M, 1.0 GB):

| Dispositivo | RAM libre | Consultas | Tok/s promedio | Correctas | OOM |
|-------------|-----------|-----------|----------------|-----------|-----|
| Samsung A30s | 2.0 GB | 30 | 2.9 | 30/30 | 0 |
| OPPO CPH2557 | 3.5 GB | 30 | 4.5 | 30/30 | 0 |

TABLA 2 — Throughput 7B (DeepSeek R1 Distill Qwen 7B Q2_K, 2.8 GB):

| Dispositivo | Estrategia | RAM extra | Tok/s | Correctas | OOM |
|-------------|-----------|-----------|-------|-----------|-----|
| Samsung | Streaming | 0 MB | 0.1 | 5/5 | 0 |
| Samsung | Sin streaming | — | — | — | OOM |
| OPPO | Directo | 0 MB | 0.5 | 3/3 | 0 |
| OPPO | + Model Draft (1.5B) | +1.0 GB | 1.1 | 3/3 | 0 |
| OPPO | + NGRAM | 0 MB | 1.4 | 2/2 | 0 |

TABLA 3 — big.LITTLE (OPPO CPH2557, 1.5B Qwen):

| Threads | Cores usados | Tok/s | Diferencia |
|---------|-------------|-------|------------|
| 2 | Solo big (2× A73) | 4.5 | baseline |
| 8 | Todos (2× A73 + 6× A53) | 2.1 | -53% |

TABLA 4 — Impacto del almacenamiento (7B Q2_K, 2.8 GB, carga inicial):

| Dispositivo | Storage | Velocidad | Tiempo carga | Tiempo first token |
|-------------|---------|-----------|-------------|-------------------|
| Samsung | eMMC | 364 MB/s | 90s | 120s |
| OPPO | UFS | 1203 MB/s | 2.4s | 8s |

1.4 ANÁLISIS ESTADÍSTICO

- Tamaño de muestra: n=185 consultas totales
- Dispositivos: n=2 (budget, mid-range)
- Intervalo de confianza: Clopper-Pearson para proporción de OOM
  - 185 consultas, 0 crashes → IC 95%: [0%, 1.97%]
- No se aplicaron pruebas paramétricas por n pequeño.
  Los resultados son observacionales y requieren replicación.

1.5 AMENAZAS A LA VALIDEZ

Validez interna:
  - n=2 dispositivos (no generalizable a todos los Android)
  - Una familia de modelos (Qwen-derived)
  - Benchmarks limitados (aritmética, factual)
  - Sin medición de temperatura/thermal throttling durante las pruebas

Validez externa:
  - Solo Android ARM64 (no iOS, no x86 móvil)
  - Solo modelos GGUF (no ONNX, CoreML, etc.)
  - Dispositivos en modo avión (condición ideal)

Validez de constructo:
  - "Supervivencia" = completa sin OOM. Definición operacional clara.
  - "Corrección" = juez humano binario. Subjetividad mitigada con queries factuales.

================================================================================
PARTE 2 — ORQUESTACIÓN (QUÉ HACE EL SISTEMA)
================================================================================

2.1 ARQUITECTURA (DESCRIPCIÓN BLACK-BOX)

El sistema implementa un pipeline de 7 etapas que se ejecuta
para cada consulta del usuario:

  [Usuario] → [Request]
      │
  ┌───▼────────────────────────────────────────────┐
  │ STEP 0: HARDWARE-AWARE QOS                     │
  │  • Lee temperatura del CPU (sysfs)             │
  │  • Lee nivel de batería (sysfs)                │
  │  • Ajusta modo: Performance / Eco / Survival   │
  ├────────────────────────────────────────────────┤
  │ STEP 1: PRIVACY FILTER                         │
  │  • Detecta PII (regex + entropía)              │
  │  • Si hay PII → fuerza ejecución local         │
  ├────────────────────────────────────────────────┤
  │ STEP 2: RAG (Retrieval Augmented Generation)   │
  │  • Búsqueda semántica en documentos locales    │
  │  • Embeddings + similitud coseno               │
  ├────────────────────────────────────────────────┤
  │ STEP 3: PROMPT CACHE                           │
  │  • LRU cache de prompts ya respondidos         │
  │  • Si hit → devuelve respuesta cacheada        │
  ├────────────────────────────────────────────────┤
  │ STEP 4: LOCAL INFERENCE                        │
  │  • Auto-detecta dispositivo (RAM, cores, I/O)  │
  │  • Elige estrategia: directo/speculative/NGRAM │
  │  • Ajusta contexto, batch, threads             │
  │  • Si el modelo excede RAM → streaming         │
  ├────────────────────────────────────────────────┤
  │ STEP 5: TOOL DETECTION                         │
  │  • Escanea respuesta por tool calls JSON       │
  │  • Ejecuta herramientas registradas            │
  ├────────────────────────────────────────────────┤
  │ STEP 6: CONFIDENCE CHECK                       │
  │  • Mide entropía de la respuesta               │
  │  • Si confianza baja → escala a cloud (opc.)   │
  ├────────────────────────────────────────────────┤
  │ STEP 7: RATE LIMITER                           │
  │  • Token bucket para cloud/LAN                 │
  │  • Previene abuso de APIs externas             │
  └────────────────────────────────────────────────┘
      │
      ▼ [Response] → [Usuario]

2.2 MEMORY MODEL (5 FÓRMULAS)

F1 — PRESUPUESTO DE RAM:
  RAM_disponible = RAM_total - RAM_OS - RAM_apps
  Si RAM_disponible < tamaño_modelo → activar streaming

F2 — RÉGIMEN DE MEMORIA:
  Régimen I   (surplus):   RAM_disp > 2 × model_size  → carga completa
  Régimen II  (tight):     model_size < RAM_disp < 2×  → streaming opcional
  Régimen III (critical):  RAM_disp < model_size       → streaming obligatorio

F3 — PREDICCIÓN DE THROUGHPUT:
  T_efectivo = T_CPU / (1 + α × (model_size / RAM_disp - 1))
  donde α depende de la velocidad de almacenamiento

F4 — VENTANA DE STREAMING:
  W_opt = min(ceil(RAM_disp / layer_size), total_layers)
  Típicamente W=3 para 7B en dispositivos budget

F5 — ESTIMACIÓN DE OOM:
  P(OOM) ≈ 1 - exp(-λ × t × (model_size / RAM_disp)^β)
  Donde λ y β son parámetros calibrados por dispositivo

2.3 TECNOLOGÍAS EMPLEADAS

| Capa | Tecnología | Rol |
|------|-----------|-----|
| Orquestación | Lenguaje de sistemas con tipado estático | Lógica de negocio, memory engine |
| Inferencia | Motor GGUF estándar (C++) | Ejecución del modelo |
| FFI | Interfaz binaria C | Comunicación entre capas |
| Sistema operativo | Kernel Linux (Android) | mmap, madvise, sysfs |
| CI/CD | Contenedores Linux (GitHub Actions) | Verificación estática: fmt, clippy, test, security audit |
| Modelos | Formato GGUF | Cuantización y distribución |

================================================================================
PARTE 3 — RELEVANCIA EN COLOMBIA
================================================================================

3.1 PARA MINCIENCIAS (Ministerio de Ciencia, Tecnología e Innovación)

CLASIFICACIÓN DE INVESTIGADOR:
  Este proyecto contribuye a la clasificación como Investigador Junior
  (mínimo requerido: 1 artículo publicado + 1 producto tecnológico).

PRODUCTOS DEMOSTRABLES:
  ✅ Artículo de investigación (paper en TechRxiv/arXiv)
  ✅ Desarrollo tecnológico (software funcional con 242 tests)
  ✅ Datos empíricos (mediciones en hardware real)
  ✅ Formato de divulgación (paper bilingüe español/inglés)

CONVOCATORIAS APLICABLES:
  - Convocatoria de reconocimiento de investigadores (anual)
  - Convocatoria de proyectos de I+D+i (si se asocia a universidad)
  - Programa de beneficios tributarios por inversión en CTI

3.2 PARA UNIVERSIDAD COLOMBIANA

TESIS DE PREGRADO (Ingeniería de Sistemas, Computación):
  - Alcance: Más que suficiente. La mayoría de tesis de pregrado
    no incluyen implementación funcional + datos empíricos + paper.
  - Calificación esperada: Meritoria o Laureada.

TESIS DE MAESTRÍA (Ingeniería, IA, Sistemas):
  - Alcance: Suficiente si se contextualiza en el estado del arte
    y se agrega validación estadística más rigurosa.
  - Recomendación: Agregar MMLU benchmark + análisis de varianza.

GRUPOS DE INVESTIGACIÓN AFINES EN COLOMBIA:
  - Universidad Nacional — GITECX, GICO
  - Universidad de Antioquia — GIDIA, SISTEMIC
  - Universidad EAFIT — GIA (Grupo de Inteligencia Artificial)
  - Universidad del Valle — GEDI
  - Universidad de los Andes — COMIT, CINFONIA

3.3 CONFERENCIAS DONDE PRESENTAR

NACIONALES (Colombia):
  - Congreso Colombiano de Computación (CCC)
  - Simposio Colombiano de Inteligencia Artificial (SCIA)
  - Encuentro Nacional de Investigación en Ingeniería (ENII)

INTERNACIONALES (Latinoamérica):
  - LatinX in AI (workshop en NeurIPS/ICML)
  - CLEI (Conferencia Latinoamericana de Informática)
  - Khipu (Latinoamerican AI meeting)

================================================================================
PARTE 4 — PUBLICACIÓN Y PRÓXIMOS PASOS
================================================================================

4.1 ESTRATEGIA DE PUBLICACIÓN

PASO 1 (inmediato): TechRxiv (techrxiv.org)
  - IEEE, gratuito, no requiere endorser
  - DOI asignado → citable inmediatamente
  - Establece fecha de prioridad

PASO 2 (corto plazo): arXiv (arxiv.org)
  - Requiere endorser (alguien con publicaciones previas)
  - Mayor visibilidad internacional
  - Indexado en Google Scholar

PASO 3 (mediano plazo): Conferencia o revista
  - Opción A: Congreso Colombiano de Computación (más accesible)
  - Opción B: Revista Ingeniería Universidad de Antioquia
  - Opción C: IEEE Latin America Transactions

4.2 PRÓXIMOS PASOS TÉCNICOS

[ ] Actualizar paper con sección NGRAM vs Model-Draft
[ ] Agregar benchmark MMLU (validación externa)
[ ] Probar con modelo Qwen 2.5 3B en Samsung
[ ] Reproducir en 3er dispositivo (n≥3)
[ ] Medir consumo de batería
[ ] Documentar thermal throttling

4.3 PRÓXIMOS PASOS ADMINISTRATIVOS

[ ] Registrar ORCID (orcid.org)
[ ] Crear Google Scholar profile
[ ] Someter paper a TechRxiv
[ ] Contactar grupo de investigación en universidad
[ ] Evaluar patente ante SIC Colombia (si aplica)
[ ] Evaluar registro de software

================================================================================
PARTE 5 — CARTA DE PRESENTACIÓN (MODELO)
================================================================================

Medellín, [fecha]

Señores
[Minciencias / Universidad / Comité Académico]
Ciudad

Asunto: Presentación de proyecto de investigación — NanoRuntime

Por medio de la presente, presento el proyecto de investigación
"NanoRuntime: Inferencia de Modelos de Lenguaje de 7B Parámetros
en Dispositivos Android de Bajo Costo", desarrollado como
investigación independiente en el área de Edge AI y sistemas
embebidos.

El proyecto incluye:
- Implementación funcional de un motor de inferencia con 242 pruebas
- Validación empírica en 2 dispositivos Android físicos
- Paper de investigación en formato bilingüe (español/inglés)
- Dataset de 185+ consultas con métricas de rendimiento
- Pipeline CI/CD automatizado (fmt, clippy, test, security audit) + compilación cruzada ARM64 local

Adjunto: paper completo, datos experimentales, código fuente (bajo
acuerdo de confidencialidad).

Atentamente,

Emmanuel Higuita Gómez
QA Automation Engineer — Rappi
Medellín, Antioquia, Colombia
[correo] | [teléfono]
