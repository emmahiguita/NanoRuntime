//! CLI Inference Bridge — Punto de integración entre la interfaz
//! web/CLI y el runtime real.
//!
//! Expone `run_single()` que carga un modelo real, ejecuta una
//! consulta, y devuelve (texto, tok_s, confianza). Usado por el
//! servidor web (`nanortime-web`) y cualquier interfaz.

use crate::config::manifest::Config;
use crate::error::Result;
use crate::{NanoRuntime, UserRequest};

/// Resultado de una inferencia simple.
#[derive(Debug, Clone)]
pub struct SingleResult {
    pub text: String,
    pub tok_s: f64,
    pub confidence: f64,
}

/// Ejecuta una consulta con el runtime real.
///
/// # Argumentos
/// - `model_path`: ruta al modelo GGUF
/// - `prompt`: la pregunta
/// - `max_tokens`: tokens máximos
/// - `temperature`: 0.0 determinista
///
/// # Flujo
/// 1. Construye un Config con el modelo especificado
/// 2. Crea el NanoRuntime (carga el modelo real)
/// 3. Procesa la petición
/// 4. Devuelve texto + velocidad + confianza
///
/// # Performance note
/// Cada llamada crea y destruye el runtime completo (carga/descarga del modelo).
/// Para producción con múltiples requests, usar un runtime persistente (singleton)
/// en lugar de este bridge por-request. El modelo se libera correctamente al
/// finalizar — no hay leak — pero la carga desde disco es costosa (~2-10s).
pub fn run_single(
    model_path: &str,
    prompt: &str,
    max_tokens: usize,
    temperature: f32,
) -> Result<SingleResult> {
    // Crear runtime (bloqueante — carga el modelo)
    let rt = tokio::runtime::Runtime::new().map_err(|e| crate::error::NanoError::Internal {
        message: e.to_string(),
    })?;

    rt.block_on(async {
        // 1. Config con el modelo
        let mut config = Config::default_config();
        config.local_model.path = model_path.to_string();
        config.generation.max_tokens = max_tokens;
        config.generation.temperature = temperature;
        config.hybrid_routing.edge_only = true;
        // Desactivar herramientas: la web debe responder directamente,
        // no invocar tools (math, search, etc.)
        config.tools.auto_discover = false;

        // 2. Crear runtime (carga el modelo)
        let runtime =
            NanoRuntime::new(config)
                .await
                .map_err(|e| crate::error::NanoError::Internal {
                    message: format!("Runtime init: {}", e),
                })?;

        // 3. Procesar la petición
        let request = UserRequest {
            prompt: prompt.to_string(),
            context: None,
            history: None,
            session_id: None,
            max_tokens: Some(max_tokens),
            // Semántica del bridge: el llamador define la temperatura
            // explícitamente (0.0 = greedy determinista, documentado arriba).
            temperature: Some(temperature),
        };

        let started = std::time::Instant::now();

        let response = runtime.process_request(request).await.map_err(|e| {
            crate::error::NanoError::Internal {
                message: format!("Inference: {}", e),
            }
        })?;
        let elapsed = started.elapsed().as_secs_f64();

        // 4. Extraer texto y métricas
        let text = response.text.clone();
        let confidence = response.confidence.unwrap_or(0.0) as f64;
        // tok/s REAL: tokens generados / tiempo de la petición (el timer
        // arranca tras la carga del modelo, así que mide solo inferencia).
        let tok_s = if elapsed > 0.0 {
            response.tokens_generated as f64 / elapsed
        } else {
            0.0
        };

        Ok(SingleResult {
            text,
            tok_s,
            confidence,
        })
    })
}
