//! Test suite interactiva — ejecuta peticiones científicas, de programación e informes.

use nanortime_core::{Config, NanoRuntime, UserRequest};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("=== NanoAI Runtime — Test Suite de Consultas ===");

    let mut config = Config::default_config();
    let model_path = std::env::temp_dir().join("dummy_model.gguf");
    if !model_path.exists() {
        let _ = std::fs::write(&model_path, b"dummy gguf content");
    }
    config.local_model.path = model_path.to_string_lossy().to_string();

    println!("[1/4] Inicializando NanoAI Runtime...");
    let runtime = NanoRuntime::new(config).await?;
    println!("  -> Runtime inicializado correctamente.");

    // Query 1: Consulta Científica
    println!("\n[2/4] Ejecutando Consulta Científica...");
    let req1 = UserRequest {
        prompt: "Explica la diferencia entre cuantización Q4_K_M y Q8_0 en GGUF para modelos LLM."
            .to_string(),
        context: None,
        history: None,
    };
    let resp1 = runtime.process_request(req1).await?;
    println!("  -> Tier usado: {}", resp1.tier_used);
    println!(
        "  -> Confianza: {:.2}%",
        resp1.confidence.unwrap_or(0.0) * 100.0
    );
    println!("  -> Respuesta:\n{}", resp1.text);

    // Query 2: Consulta de Programación
    println!("\n[3/4] Ejecutando Consulta de Programación...");
    let req2 = UserRequest {
        prompt: "Escribe una función optimizada en Rust para calcular la entropía de Shannon."
            .to_string(),
        context: None,
        history: None,
    };
    let resp2 = runtime.process_request(req2).await?;
    println!("  -> Tier usado: {}", resp2.tier_used);
    println!(
        "  -> Confianza: {:.2}%",
        resp2.confidence.unwrap_or(0.0) * 100.0
    );
    println!("  -> Respuesta:\n{}", resp2.text);

    // Query 3: Petición de Informe del Sistema
    println!("\n[4/4] Solicitando Informe del Estado del Sistema...");
    let req3 = UserRequest {
        prompt: "Genera un informe sobre el rendimiento del Nano Memory Engine.".to_string(),
        context: None,
        history: None,
    };
    let resp3 = runtime.process_request(req3).await?;
    println!("  -> Tier usado: {}", resp3.tier_used);
    println!(
        "  -> Confianza: {:.2}%",
        resp3.confidence.unwrap_or(0.0) * 100.0
    );
    println!("  -> Respuesta:\n{}", resp3.text);

    println!("\n=== Test Suite Completada con Éxito ===");
    Ok(())
}
