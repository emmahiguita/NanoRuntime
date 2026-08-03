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
pub fn run_single(
    model_path: &str,
    prompt: &str,
    max_tokens: usize,
    temperature: f32,
) -> Result<SingleResult> {
    // Crear runtime (bloqueante — carga el modelo)
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| crate::error::NanoError::Internal { message: e.to_string() })?;

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
        let runtime = NanoRuntime::new(config)
            .await
            .map_err(|e| crate::error::NanoError::Internal { message: format!("Runtime init: {}", e) })?;

        // 3. Procesar la petición
        let request = UserRequest {
            prompt: prompt.to_string(),
            context: None,
            history: None,
        };

        let response = runtime
            .process_request(request)
            .await
            .map_err(|e| crate::error::NanoError::Internal { message: format!("Inference: {}", e) })?;

        // 4. Extraer texto y métricas
        let text = response.text.clone();
        let confidence = response.confidence.unwrap_or(0.0) as f64;
        // tok/s se estima: tokens_generated / tiempo. Sin timer aquí,
        // reportamos 0.0 y el servidor web muestra la respuesta igualmente.
        let tok_s = 0.0;

        Ok(SingleResult {
            text,
            tok_s,
            confidence,
        })
    })
}


