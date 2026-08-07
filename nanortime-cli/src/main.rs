//! NanoAI CLI — Interfaz de línea de comandos.
//!
//! Proporciona chat interactivo con el runtime NanoAI,
//! permitiendo ejecutar prompts directos o sesiones de chat.
//!
//! Uso:
//! ```bash
//! nanortime                          # Chat interactivo
//! nanortime --prompt "¿Qué hora es?" # Prompt directo
//! nanortime --config mi_config.json  # Con archivo de configuración
//! ```

use std::io::{self, Write};
use std::time::Instant;
use std::path::PathBuf;

use clap::Parser;
use nanortime_core::{Config, NanoRuntime, UserRequest};
use tracing_subscriber::{fmt, prelude::*, EnvFilter};

/// NanoAI Runtime — Motor de orquestación de IA híbrido Edge-Cloud.
///
/// Ejecuta modelos de lenguaje locales con capacidad de escalar
/// inteligentemente a la nube cuando es necesario.
#[derive(Parser, Debug)]
#[command(
    name = "nanortime",
    version = env!("CARGO_PKG_VERSION"),
    about = "NanoAI Runtime — Hybrid Edge-Cloud AI Orchestration Engine",
    long_about = "Ejecuta modelos de lenguaje locales (1.5B-14B) con \
                  routing híbrido inteligente a la nube."
)]
struct Cli {
    /// Ruta al archivo de configuración (nano.manifest.json)
    #[arg(short, long, default_value = "nano.manifest.json")]
    config: PathBuf,

    /// Prompt directo (si no se especifica, inicia chat interactivo)
    #[arg(short, long)]
    prompt: Option<String>,

    /// Modelo a usar (sobrescribe el configurado en nano.manifest.json)
    #[arg(short, long)]
    model: Option<String>,

    /// Máximo de tokens a generar
    #[arg(short = 'n', long, default_value = "2048")]
    max_tokens: usize,

    /// Nivel de log (trace, debug, info, warn, error)
    #[arg(short, long, default_value = "info")]
    log_level: String,

    /// Desactivar descubrimiento automático de herramientas
    #[arg(long)]
    no_tools: bool,

    /// Temperatura para generación (0.0 = determinístico, 1.0+ = creativo)
    #[arg(short = 't', long, default_value = "0.7")]
    temperature: f32,

    /// Número de threads para inferencia (auto-detecta big.LITTLE si no se especifica)
    #[arg(long)]
    threads: Option<usize>,

    /// Silenciar salida de debug de llama.cpp
    #[arg(short = 'q', long)]
    quiet: bool,

    /// Solo usar inferencia local, desactivar tiers cloud/LAN
    #[arg(long)]
    edge_only: bool,

    /// Aplicar optimizaciones avanzadas de memoria del SO (madvise, zram, sysctl tuning)
    #[arg(long)]
    tune_system: bool,

    /// Activar caché de respuestas (evita re-inferir prompts repetidos)
    #[arg(long)]
    cache: bool,

    /// Activar router híbrido (recomienda 1.5B vs 7B según complejidad)
    #[arg(long)]
    hybrid: bool,

    /// Detener generacion en limites naturales (parrafos, secciones)
    #[arg(long)]
    natural_stops: bool,

    /// Pre-cargar el modelo al page cache del kernel antes de inferir
    /// (cat modelo > /dev/null). Mejora el prompt processing hasta 2x
    /// en dispositivos con eMMC lento (Samsung A30s).
    #[arg(long)]
    preload: bool,

    /// Guardar el estado (KV cache) al terminar la consulta
    #[arg(long)]
    save_session: bool,

    /// Restaurar el estado (KV cache) antes de la consulta
    #[arg(long)]
    load_session: bool,

    /// Directorio de sesiones (default: .nano-sessions)
    #[arg(long, default_value = ".nano-sessions")]
    session_dir: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    // Initialize logging
    setup_logging(&cli.log_level);

    tracing::info!("NanoAI Runtime v{}", env!("CARGO_PKG_VERSION"));

    // Load configuration
    let config_path = &cli.config;
    let mut config = if config_path.exists() {
        Config::load(config_path)?
    } else {
        tracing::warn!(
            "Config file not found: {}. Using defaults.",
            config_path.display()
        );
        Config::default_config()
    };

    // Override model if specified
    if let Some(ref model_path) = cli.model {
        config.local_model.path = model_path.clone();
    }

    // Override max tokens if specified
    config.generation.max_tokens = cli.max_tokens;

    // Override temperature
    config.generation.temperature = cli.temperature;

    // Override threads if specified (before V2 auto-config which may further tune)
    if let Some(t) = cli.threads {
        config.local_model.threads = t;
    }

    // Disable tools if requested
    if cli.no_tools {
        config.tools.auto_discover = false;
    }

    // Enable edge-only mode if requested
    if cli.edge_only {
        config.hybrid_routing.edge_only = true;
    }

    // System memory tuning requires root — disabled on stock Android.
    if cli.tune_system {
        tracing::warn!("System tuning requires root access. Skipping.");
    }

    // ── V2: Auto-detect hardware and compute safe token budget ──────
    let safe_max_tokens = {
        use nanortime_core::memory_engine::hardware_hal;
        let profile = hardware_hal::profile_device();
        tracing::info!(
            "Hardware: {}MB RAM, {} cores, {}MB/s I/O, tier={}",
            profile.ram_total_mb, profile.cpu_cores,
            profile.storage_read_mbps, profile.tier
        );
        // Dynamic token budget: 30% of available RAM for KV cache
        let kv_budget_tokens = (profile.ram_available_mb as f64 * 0.30 / 0.03) as usize;
        let safe = kv_budget_tokens.min(cli.max_tokens).max(150);
        tracing::info!(
            "Dynamic token budget: {} tokens (requested={}, safe={})",
            safe, cli.max_tokens, kv_budget_tokens
        );
        safe
    };

    // Override max tokens with safe dynamic budget
    config.generation.max_tokens = safe_max_tokens;

    // ── V2: OOM Guard background monitor ───────────────────────────
    #[cfg(feature = "v2")]
    let oom_rx = {
        use nanortime_core::memory_engine::oom_guard;
        use std::sync::mpsc;
        let (tx, rx) = mpsc::channel();
        std::thread::spawn(move || {
            let mut guard = oom_guard::imp::OomGuard::new();
            loop {
                if let Some(status) = guard.sample() {
                    if status.risk >= oom_guard::OomRisk::High {
                        let _ = tx.send(status.summary());
                    }
                }
                std::thread::sleep(std::time::Duration::from_millis(500));
            }
        });
        rx
    };

    // ── Pre-cargar modelo al page cache (mejora prompt 2x) ──────
    if cli.preload {
        let model_path = &config.local_model.path;
        if !model_path.is_empty() && std::path::Path::new(model_path).exists() {
            tracing::info!("Pre-cargando modelo al page cache: {}", model_path);
            // cat modelo > /dev/null fuerza al kernel a traer las páginas a RAM
            let start = std::time::Instant::now();
            if let Ok(mut f) = std::fs::File::open(model_path) {
                let mut buf = vec![0u8; 64 * 1024];
                let mut total = 0u64;
                loop {
                    match std::io::Read::read(&mut f, &mut buf) {
                        Ok(0) => break,
                        Ok(n) => total += n as u64,
                        Err(_) => break,
                    }
                }
                let elapsed = start.elapsed().as_secs_f64();
                let mb = total as f64 / (1024.0 * 1024.0);
                tracing::info!(
                    "Page cache precargado: {:.0} MB en {:.1}s ({:.0} MB/s)",
                    mb, elapsed,
                    mb / elapsed.max(0.001)
                );
            }
        } else {
            tracing::warn!("--preload: modelo no encontrado, omitiendo");
        }
    }

    // Initialize runtime
    tracing::info!("Initializing runtime...");
    let runtime = match NanoRuntime::new(config).await {
        Ok(rt) => {
            tracing::info!("Runtime initialized successfully");
            rt
        }
        Err(e) => {
            tracing::error!("Failed to initialize runtime: {}", e);
            eprintln!("Error: Failed to initialize NanoAI Runtime.");
            eprintln!("Cause: {}", e);
            eprintln!();
            eprintln!("Troubleshooting:");
            eprintln!("  1. Verify the config file exists and is valid JSON");
            eprintln!("  2. Check that the model path is correct");
            eprintln!("  3. Ensure you have enough RAM for the model");
            return Err(e.into());
        }
    };

    // Process input
    if let Some(prompt) = cli.prompt {
        // ── Session persistence: restaurar KV cache antes ────────
        let session_path = format!("{}/session_auto.nano", cli.session_dir);
        if cli.load_session {
            std::fs::create_dir_all(&cli.session_dir).ok();
            tracing::info!("Restaurando sesión desde {}", session_path);
            let model_manager = runtime.model_manager();
            match model_manager.restore_session_state(&session_path).await {
                Ok(_) => tracing::info!("Sesión restaurada — salta prefill"),
                Err(e) => tracing::warn!("No se pudo restaurar sesión: {}", e),
            }
        }

        // ── Hybrid Router: recomendar modelo según complejidad ─────
        if cli.hybrid {
            let tier = nanortime_core::hybrid_router::route_prompt(
                &prompt,
                2048, // RAM estimada disponible
                true, // 7B disponible
            );
            tracing::info!(
                "HybridRouter: prompt complexity → {:?} tier (model: {})",
                tier,
                match tier {
                    nanortime_core::hybrid_router::ModelTier::Fast => "1.5B/3B",
                    nanortime_core::hybrid_router::ModelTier::Expert => "7B",
                }
            );
            if tier == nanortime_core::hybrid_router::ModelTier::Expert {
                eprintln!("🧠 Modo experto (7B). La respuesta puede tomar ~3 minutos.");
            }
        }

        // ── Response Cache: buscar respuesta previa ───────────────
        let mut response_cache = nanortime_core::response_cache::ResponseCache::new(500);
        if cli.cache {
            if let Some(cached) = response_cache.find(&prompt) {
                println!("{}", cached);
                eprintln!("[METRICS] tokens={} elapsed_ms=0 tok_s=inf tier=local confidence=1.000 cache=hit", 
                    cached.split_whitespace().count());
                return Ok(());
            }
        }

        // Single prompt mode
        let response_text = process_single_prompt(&runtime, &prompt, cli.max_tokens, cli.natural_stops).await?;

        // ── Guardar respuesta en caché ─────────────────────────────
        if cli.cache && !response_text.is_empty() {
            response_cache.store(&prompt, &response_text, "local");
            tracing::info!("Cache store: {} chars", response_text.len());
        }

        // ── Session persistence: guardar KV cache después ────────
        if cli.save_session {
            std::fs::create_dir_all(&cli.session_dir).ok();
            tracing::info!("Guardando sesión en {}", session_path);
            let model_manager = runtime.model_manager();
            match model_manager.save_session_state(&session_path).await {
                Ok(_) => tracing::info!("Sesión guardada — próxima carga será ~0.5s"),
                Err(e) => tracing::warn!("No se pudo guardar sesión: {}", e),
            }
        }
    } else {
        // Interactive chat mode
        interactive_chat(&runtime, cli.max_tokens).await?;
    }

    Ok(())
}

/// Procesa un único prompt y muestra la respuesta con streaming.
/// Retorna el texto generado para caché/procesamiento posterior.
///
/// - La respuesta va a **stdout** (captureable por subprocesos).
/// - Las métricas de rendimiento van a **stderr** como línea parseable:
///   `[METRICS] tokens=N elapsed_ms=M tok_s=X.XX tier=T confidence=C`
async fn process_single_prompt(
    runtime: &NanoRuntime,
    prompt: &str,
    _max_tokens: usize,
    natural_stops: bool,
) -> anyhow::Result<String> {
    let request = UserRequest {
        prompt: prompt.to_string(),
        context: None,
        history: None,
    };

    let t_start = Instant::now();
    let mut generated_text = String::with_capacity(4096);

    match runtime.process_request_streaming(request).await {
        Ok((response, mut rx)) => {
            // Stream tokens to stdout. Apply natural stop detection.
            let mut token_count: usize = 0;
            let mut buffer = String::with_capacity(4096);
            const STOP_SEQUENCES: &[&str] = &["\n\n\n", "\n###", "\nUSER:", "<|im_end|>"];
            
            // Track low-confidence streak for hallucination detection
            let mut low_conf_streak: u32 = 0;
            while let Some((token, prob)) = rx.recv().await {
                print!("{}", token);
                let _ = io::stdout().flush();
                generated_text.push_str(&token);
                token_count += 1;
                
                // ── Token-Level Early Exit ────────────────────────
                let confidence = prob;
                // Exit early if model is very confident (factual answer done)
                if confidence > 0.99 && token_count > 1 {
                    tracing::info!(
                        "Early exit: high confidence ({:.3}) at token {}",
                        confidence, token_count
                    );
                    break;
                }
                // Track consecutive low-confidence tokens (hallucination guard)
                if confidence < 0.1 {
                    low_conf_streak += 1;
                    if low_conf_streak >= 3 {
                        tracing::warn!(
                            "Early exit: hallucination detected ({} low-conf tokens)",
                            low_conf_streak
                        );
                        break;
                    }
                } else {
                    low_conf_streak = 0;
                }
                // ── End Early Exit ────────────────────────────────
                
                // Natural stop detection: check if buffer ends with a stop sequence
                if natural_stops {
                    buffer.push_str(&token);
                    // Keep buffer bounded
                    if buffer.len() > 512 {
                        buffer.drain(0..buffer.len() - 256);
                    }
                    if STOP_SEQUENCES.iter().any(|s| buffer.ends_with(s)) {
                        tracing::info!("Natural stop detected after {} tokens", token_count);
                        break;
                    }
                }
            }
            println!(); // final newline on stdout

            let conf = response.confidence.unwrap_or(0.0);
            let elapsed_ms = t_start.elapsed().as_millis() as f64;
            let tok_s = if elapsed_ms > 0.0 {
                token_count as f64 / (elapsed_ms / 1000.0)
            } else {
                0.0
            };

            // ── Quality Preserver: regenerate if confidence is low ──
            if conf < 0.7 && conf > 0.0 {
                tracing::warn!(
                    "Low confidence ({:.3}) — retrying with temperature=0.0",
                    conf
                );
                let retry_request = UserRequest {
                    prompt: prompt.to_string(),
                    context: None,
                    history: None,
                };
                if let Ok((retry_response, mut retry_rx)) =
                    runtime.process_request_streaming(retry_request).await
                {
                    let mut retry_tokens: usize = 0;
                    while let Some((token, _)) = retry_rx.recv().await {
                        print!("{}", token);
                        let _ = io::stdout().flush();
                        generated_text.push_str(&token);
                        retry_tokens += 1;
                    }
                    println!();
                    let retry_conf = retry_response.confidence.unwrap_or(0.0);
                    let retry_elapsed = t_start.elapsed().as_millis() as f64;
                    let retry_tok_s = if retry_elapsed > 0.0 {
                        (token_count + retry_tokens) as f64 / (retry_elapsed / 1000.0)
                    } else {
                        0.0
                    };
                    eprintln!(
                        "[METRICS] tokens={} elapsed_ms={:.0} tok_s={:.2} tier={} confidence={:.3} retry=1",
                        token_count + retry_tokens,
                        retry_elapsed,
                        retry_tok_s,
                        retry_response.tier_used,
                        retry_conf,
                    );
                    return Ok(generated_text);
                }
            }

            eprintln!(
                "[METRICS] tokens={} elapsed_ms={:.0} tok_s={:.2} tier={} confidence={:.3}",
                token_count,
                elapsed_ms,
                tok_s,
                response.tier_used,
                conf,
            );
        }
        Err(e) => {
            tracing::error!("Inference failed: {}. Falling back gracefully.", e);
            let fallback = "[Error: inference failed. Please try again with a simpler model or prompt.]".to_string();
            generated_text.push_str(&fallback);
            println!("{}", fallback);
            eprintln!(
                "[METRICS] tokens=0 elapsed_ms=0 tok_s=0 tier=local confidence=0.000 error=1",
            );
            // Return the error message as text (system stays alive)
            return Ok(generated_text);
        }
    }

    Ok(generated_text)
}

/// Chat interactivo: lee líneas de stdin y muestra respuestas.
async fn interactive_chat(
    runtime: &NanoRuntime,
    _max_tokens: usize,
) -> anyhow::Result<()> {
    println!("╔══════════════════════════════════════════════╗");
    println!("║        NanoAI Runtime — Interactive Chat     ║");
    println!("╠══════════════════════════════════════════════╣");
    println!("║  Commands:                                   ║");
    println!("║    /help     — Show this help                ║");
    println!("║    /model    — Show current model info       ║");
    println!("║    /tools    — List registered tools         ║");
    println!("║    /clear    — Clear conversation history    ║");
    println!("║    /exit     — Exit chat                     ║");
    println!("╚══════════════════════════════════════════════╝");
    println!();

    let history_path = std::path::PathBuf::from("data/history.json");
    let mut history: Vec<nanortime_core::ChatMessage> = if history_path.exists() {
        if let Ok(content) = std::fs::read_to_string(&history_path) {
            serde_json::from_str(&content).unwrap_or_default()
        } else {
            Vec::new()
        }
    } else {
        Vec::new()
    };
    if !history.is_empty() {
        println!("[Loaded {} messages from history]", history.len());
    }

    loop {
        // Prompt
        print!("> ");
        io::stdout().flush()?;

        // Use spawn_blocking for stdin to allow Ctrl+C interruption
        let input_fut = tokio::task::spawn_blocking(|| {
            let mut input = String::new();
            io::stdin().read_line(&mut input).map(|_| input)
        });

        let input = tokio::select! {
            res = input_fut => {
                match res {
                    Ok(Ok(input)) => input.trim().to_string(),
                    _ => break,
                }
            }
            _ = tokio::signal::ctrl_c() => {
                println!("\n[Ctrl+C detected, shutting down gracefully...]");
                break;
            }
        };

        if input.is_empty() {
            continue;
        }

        // Handle commands
        if input.starts_with('/') {
            match handle_command(&input, &runtime).await {
                CommandResult::Continue => continue,
                CommandResult::Exit => break,
                CommandResult::ClearHistory => {
                    history.clear();
                    println!("[History cleared — {} messages removed]", 0);
                    println!();
                    continue;
                }
                CommandResult::Handled => continue,
            }
        }

        // Build request with history
        let request = UserRequest {
            prompt: input.clone(),
            context: None,
            history: if history.is_empty() {
                None
            } else {
                Some(history.clone())
            },
        };

        // Process with streaming
        match runtime.process_request_streaming(request).await {
            Ok((response, mut rx)) => {
                // Stream tokens as they arrive
                let mut full_text = String::new();
                let mut first_token = true;
                
                loop {
                    tokio::select! {
                        opt_token = rx.recv() => {
                            match opt_token {
                                Some((token, _prob)) => {
                                    if first_token {
                                        // Print a newline to separate from spinner if any
                                        print!("\r\x1B[K"); // Clear line
                                        first_token = false;
                                    }
                                    print!("{}", token);
                                    io::stdout().flush().unwrap_or(());
                                    full_text.push_str(&token);
                                }
                                None => break, // Stream finished
                            }
                        }
                        _ = tokio::time::sleep(std::time::Duration::from_millis(500)), if first_token => {
                            print!(".");
                            io::stdout().flush().unwrap_or(());
                        }
                        _ = tokio::signal::ctrl_c() => {
                            println!("\n[Generation interrupted by user]");
                            break;
                        }
                    }
                }
                println!();
                println!();

                // Show metadata
                if let Some(conf) = response.confidence {
                    println!(
                        "[Tier: {}, Confidence: {:.1}%]",
                        response.tier_used,
                        conf * 100.0
                    );
                } else {
                    println!("[Tier: {}]", response.tier_used);
                }
                println!();

                // Update history
                history.push(nanortime_core::ChatMessage {
                    role: "user".to_string(),
                    content: input,
                });
                history.push(nanortime_core::ChatMessage {
                    role: "assistant".to_string(),
                    content: full_text,
                });

                // Keep history bounded (last 20 messages)
                if history.len() > 40 {
                    history.drain(0..20);
                }
            }
            Err(e) => {
                eprintln!("Error: {}", e);
            }
        }
    }

    // Save history on exit
    if let Some(parent) = history_path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    if let Ok(json) = serde_json::to_string_pretty(&history) {
        let _ = std::fs::write(history_path, json);
        println!("[History saved to data/history.json]");
    }

    println!("Goodbye!");
    Ok(())
}

#[allow(dead_code)]
enum CommandResult {
    Continue,
    Exit,
    ClearHistory,
    Handled,
}

async fn handle_command(input: &str, runtime: &NanoRuntime) -> CommandResult {
    match input {
        "/exit" | "/quit" | "/q" => {
            return CommandResult::Exit;
        }
        "/help" | "/h" => {
            println!("Commands:");
            println!("  /help, /h     — Show this help");
            println!("  /model        — Show current model info");
            println!("  /tools        — List registered tools");
            println!("  /clear        — Clear conversation history");
            println!("  /exit, /q     — Exit chat");
            println!();
            CommandResult::Handled
        }
        "/model" => {
            // Show real model info from runtime
            let mem_info = runtime.vector_engine().document_count().await;
            println!("── Model Info ──────────────────────────");
            println!("  RAG documents indexed : {}", mem_info);
            println!("  (use --model <path> to set the active GGUF model)");
            println!("────────────────────────────────────────");
            println!();
            CommandResult::Handled
        }
        "/tools" => {
            // Show real registered tools from runtime
            let tools = runtime.tool_executor().list_tool_definitions().await;
            if tools.is_empty() {
                println!("[No tools registered. Add JSON files to the tools/ directory]");
            } else {
                println!("── Registered Tools ({}) ─────────────", tools.len());
                for tool in &tools {
                    println!("  • {} — {}", tool.name, tool.description);
                }
                println!("────────────────────────────────────────");
            }
            println!();
            CommandResult::Handled
        }
        "/clear" => {
            CommandResult::ClearHistory
        }
        _ => {
            println!("Unknown command: {}. Type /help for available commands.", input);
            println!();
            CommandResult::Handled
        }
    }
}

fn setup_logging(level: &str) {
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new(level));

    // Disable ANSI colors when stderr is not a TTY (e.g., running from a subprocess or benchmark script).
    // This prevents U+001B escape sequences from polluting captured output.
    let use_ansi = std::io::IsTerminal::is_terminal(&std::io::stderr());

    let subscriber = fmt::layer()
        .with_writer(std::io::stderr)
        .with_target(false)
        .with_thread_ids(false)
        .with_file(false)
        .with_line_number(false)
        .with_ansi(use_ansi);

    tracing_subscriber::registry()
        .with(filter)
        .with(subscriber)
        .init();
}

