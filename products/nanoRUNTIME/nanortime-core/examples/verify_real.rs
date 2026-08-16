//! Phase 1 FINAL. Real verification, no closures.

#[tokio::main]
async fn main() {
    // Ver los logs reales de la inyección (GGUF layout, memory engine).
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .try_init();

    // El manifest declara rutas relativas a la raíz del repo
    // (`models/...`) — mover el cwd antes de validar.
    let repo_root = concat!(env!("CARGO_MANIFEST_DIR"), "/../../..");
    if let Err(e) = std::env::set_current_dir(repo_root) {
        eprintln!("WARN: no se pudo cambiar cwd a {}: {}", repo_root, e);
    }

    let mut p: u32 = 0;
    let mut f: u32 = 0;
    macro_rules! ok {
        ($s:expr) => {{
            p += 1;
            println!("  ✓ {}", $s);
        }};
    }
    macro_rules! ko {
        ($s:expr, $e:expr) => {{
            f += 1;
            println!("  ✗ {}: {}", $s, $e);
        }};
    }

    println!("╔══════════════════════════════════════════════╗");
    println!("║  NanoAI Phase 1 — REAL Verification FINAL   ║");
    println!("╚══════════════════════════════════════════════╝\n");
    // Ruta real del modelo: argumento CLI o default relativo al repo
    // (misma ubicación que usa gguf_probe).
    let default_mp = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../../models/qwen2.5-1.5b-instruct-q4_k_m.gguf"
    );
    let mp = std::env::args()
        .nth(1)
        .unwrap_or_else(|| default_mp.to_string());

    println!("─── 1. Config ───");
    let manifest = concat!(env!("CARGO_MANIFEST_DIR"), "/../../../nano.manifest.json");
    match nanortime_core::Config::load(manifest) {
        Ok(c) => {
            if c.version == "1.0" {
                ok!("Load manifest");
            } else {
                ko!("Config", "version");
            }
            match c.validate() {
                Ok(_) => ok!("Validate"),
                Err(e) => ko!("Validate", &e.to_string()),
            }
        }
        Err(e) => ko!("Load", &e.to_string()),
    }
    let mut bad = nanortime_core::Config::default_config();
    bad.hybrid_routing.confidence_threshold = 5.0;
    if bad.validate().is_err() {
        ok!("Reject invalid threshold");
    } else {
        ko!("Reject", "accepted 5.0");
    }

    println!("\n─── 2. PII Detection ───");
    use nanortime_core::orchestrator::privacy;
    for (l, t, e) in [
        ("Email", "juan@ejemplo.com", true),
        ("Phone", "555-123-4567", true),
        ("Card", "4111-1111-1111-1111", true),
        ("SSN", "SSN: 123-45-6789", true),
        ("Clean", "Hello world", false),
        ("Code", "fn main() {}", false),
    ] {
        if privacy::contains_pii(t) == e {
            ok!(l);
        } else {
            ko!(l, "wrong");
        }
    }
    let anon = privacy::anonymize("juan@mail.com, 555-123-4567, 4111-1111-1111-1111");
    if anon.contains("[EMAIL]")
        && anon.contains("[PHONE]")
        && anon.contains("[CARD]")
        && !anon.contains("@")
    {
        ok!("Anonymization");
    } else {
        ko!("Anonymization", "incomplete");
    }

    println!("\n─── 3. Entropy ───");
    use nanortime_core::orchestrator::confidence;
    let eu = confidence::calculate_entropy(&[0.25, 0.25, 0.25, 0.25]);
    if (eu - 2.0).abs() < 0.01 {
        ok!("Uniform = 2.0");
    } else {
        ko!("Uniform", &format!("got {:.4}", eu));
    }
    if confidence::calculate_entropy(&[1.0, 0.0]).abs() < 0.01 {
        ok!("Certain = 0.0");
    } else {
        ko!("Certain", "wrong");
    }
    let hc = confidence::entropy_to_confidence(&[0.9, 0.05, 0.05]);
    let lc = confidence::entropy_to_confidence(&[0.5, 0.5]);
    if hc > 0.5 && lc < 0.5 {
        ok!(&format!("Confidence high={:.3} low={:.3}", hc, lc));
    } else {
        ko!("Confidence", "wrong");
    }
    let ppl = confidence::perplexity(&[0.25, 0.25, 0.25, 0.25]);
    if (ppl - 4.0).abs() < 0.1 {
        ok!(&format!("Perplexity={:.2}", ppl));
    } else {
        ko!("Perplexity", "wrong");
    }

    println!("\n─── 4. Tool Executor ───");
    let c = nanortime_core::Config::default_config();
    let te = nanortime_core::execution::ToolExecutor::new(&c)
        .await
        .unwrap();
    let json = r#"{"name":"t1","description":"d","parameters":{"x":{"type":"string","required":true}},"execution":{"type":"http","method":"GET","url":"https://httpbin.org/get?x={{x}}"}}"#;
    match te.register_from_json(json).await {
        Ok(_) => {
            ok!("Register tool");
            if te.list_tools().await.contains(&"t1".to_string()) {
                ok!("List tools");
            } else {
                ko!("List", "not found");
            }
        }
        Err(e) => ko!("Register", &e.to_string()),
    }
    let interp = te.interpolate_template("Hi {{name}}!", &serde_json::json!({"name":"Alice"}));
    if interp == "Hi Alice!" {
        ok!("Template {{var}}");
    } else {
        ko!("Template", &interp);
    }
    if !te.build_system_prompt().await.is_empty() {
        ok!("System prompt");
    } else {
        ko!("Prompt", "empty");
    }
    match te.get_tool("t1").await {
        Some(t) => {
            if t.validate_parameters(&serde_json::json!({"x":"hi"}))
                .is_ok()
            {
                ok!("Validate params")
            } else {
                ko!("Params", "rejected")
            }
            if t.validate_parameters(&serde_json::json!({})).is_err() {
                ok!("Require missing")
            } else {
                ko!("Missing", "accepted")
            }
        }
        None => ko!("GetTool", "not found"),
    }

    println!("\n─── 5. RAG ───");
    let ve = nanortime_core::execution::VectorEngine::new(&c)
        .await
        .unwrap();
    ve.index_document(
        "Rust is a systems programming language",
        serde_json::json!({"s":"rust"}),
        None,
    )
    .await
    .unwrap();
    ve.index_document(
        "Python is great for AI and ML",
        serde_json::json!({"s":"py"}),
        None,
    )
    .await
    .unwrap();
    ve.index_document(
        "NanoAI is a hybrid edge-cloud AI runtime in Rust",
        serde_json::json!({"s":"nano"}),
        None,
    )
    .await
    .unwrap();
    if ve.document_count().await == 3 {
        ok!("Index 3 docs")
    } else {
        ko!("Index", "wrong count")
    }
    let r = ve.search("Rust programming", 3, None).await.unwrap();
    if !r.is_empty() && r[0].content.contains("Rust") {
        ok!("Search Rust")
    } else {
        ko!("Search Rust", "miss")
    }
    let r2 = ve.search("NanoAI runtime", 3, None).await.unwrap();
    if !r2.is_empty() && r2[0].content.contains("NanoAI") {
        ok!("Search NanoAI")
    } else {
        ko!("Search NanoAI", "miss")
    }
    ve.clear().await.unwrap();
    if ve.document_count().await == 0 {
        ok!("Clear index")
    } else {
        ko!("Clear", "not empty")
    }

    println!("\n─── 6. Grammar ───");
    let g = nanortime_core::inference::grammar::Grammar::json_tool_call();
    if g.to_gbnf().contains("root ::=") {
        ok!("GBNF output")
    } else {
        ko!("GBNF", "bad")
    }
    if g.validate(r#"{"tool":"x","parameters":{"a":"b"}}"#) {
        ok!("JSON validates")
    } else {
        ko!("JSON", "rejected")
    }
    if !g.validate("not json") {
        ok!("JSON rejects invalid")
    } else {
        ko!("JSON", "accepted invalid")
    }
    let yn = nanortime_core::inference::grammar::Grammar::yes_no();
    if yn.validate("Yes") && yn.validate("No") && !yn.validate("Maybe") {
        ok!("Yes/No grammar")
    } else {
        ko!("YesNo", "wrong")
    }

    println!("\n─── 7. Memory ───");
    let mm = nanortime_core::execution::MemoryManager::new(1024, 8192, 0);
    let s = mm.get_stats();
    if s.total_system_mb > 0 && s.available_mb > 0 {
        ok!(&format!(
            "Stats: {}MB total {}MB avail",
            s.total_system_mb, s.available_mb
        ))
    } else {
        ko!("Stats", "invalid")
    }
    let e15 = nanortime_core::execution::MemoryManager::estimate_model_memory(1.5, 4);
    let e7 = nanortime_core::execution::MemoryManager::estimate_model_memory(7.0, 4);
    let e14 = nanortime_core::execution::MemoryManager::estimate_model_memory(14.0, 4);
    if e15 < e7 && e7 < e14 {
        ok!(&format!(
            "Estimates: 1.5B={}MB 7B={}MB 14B={}MB",
            e15, e7, e14
        ))
    } else {
        ko!("Estimates", "wrong")
    }

    println!("\n─── 8. REAL Model ───");
    let mut cfg = nanortime_core::Config::default_config();
    cfg.local_model.path = mp.clone();
    cfg.local_model.context_size = 2048;
    cfg.tools.auto_discover = false;
    let mgr = nanortime_core::execution::ModelManager::new(cfg)
        .await
        .unwrap();
    ok!("ModelManager created");
    match mgr.load_model(&mp).await {
        Ok(_) => ok!("GGUF loaded"),
        Err(e) => ko!("Load model", &e.to_string()),
    }
    match mgr.generate_with_confidence("Hello!", 30, None).await {
        Ok((text, probs)) => {
            if !text.is_empty() && !probs.is_empty() {
                println!("     → {}", &text[..text.len().min(100)]);
                ok!(&format!(
                    "Generate: {} chars {} probs",
                    text.len(),
                    probs.len()
                ))
            } else {
                ko!("Generate", "empty")
            }
        }
        Err(e) => ko!("Generate", &e.to_string()),
    }

    println!("\n─── 9. Token Stream ───");
    let tb = nanortime_core::inference::token_stream::TokenStreamBuilder::new(10);
    tb.send_text("Real", 0.9).await.unwrap();
    tb.send_text(" inference", 0.95).await.unwrap();
    let mut ts = tb.finish();
    let tx = ts.collect_text().await;
    if tx == "Real inference" {
        ok!("Token streaming")
    } else {
        ko!("Stream", &tx)
    }

    println!("\n─── 10. Full Pipeline ───");
    let mut cfg2 = nanortime_core::Config::default_config();
    cfg2.local_model.path = mp.clone();
    cfg2.local_model.context_size = 2048;
    cfg2.tools.auto_discover = false;
    match nanortime_core::NanoRuntime::new(cfg2).await {
        Ok(rt) => {
            ok!("Runtime init");
            match rt
                .process_request(nanortime_core::UserRequest {
                    prompt: "Explain Rust in one sentence.".into(),
                    context: None,
                    history: None,
                    session_id: None,
                    max_tokens: None,
                    temperature: None,
                })
                .await
            {
                Ok(resp) => {
                    if !resp.text.is_empty() && resp.tier_used == "local" {
                        println!("     → {}", &resp.text[..resp.text.len().min(120)]);
                        ok!(&format!(
                            "Pipeline: tier={} {} chars",
                            resp.tier_used,
                            resp.text.len()
                        ))
                    } else {
                        ko!("Pipeline", "bad response")
                    }
                }
                Err(e) => ko!("Pipeline req", &e.to_string()),
            }
        }
        Err(e) => ko!("Runtime init", &e.to_string()),
    }

    println!("\n─── 11. PII Routing ───");
    let mut cfg3 = nanortime_core::Config::default_config();
    cfg3.local_model.path = mp.clone();
    cfg3.local_model.context_size = 1024;
    cfg3.hybrid_routing.privacy_filter = true;
    cfg3.tiers.tier3.enabled = true;
    cfg3.tools.auto_discover = false;
    std::env::set_var("NANO_API_KEY", "fake");
    match nanortime_core::NanoRuntime::new(cfg3).await {
        Ok(rt) => {
            ok!("PII runtime init");
            match rt
                .process_request(nanortime_core::UserRequest {
                    prompt: "Email juan@ejemplo.com card 4111-1111-1111-1111".into(),
                    context: None,
                    history: None,
                    session_id: None,
                    max_tokens: None,
                    temperature: None,
                })
                .await
            {
                Ok(resp) => {
                    if resp.tier_used == "local" {
                        ok!("PII forces local routing");
                        println!("     {} chars tier={}", resp.text.len(), resp.tier_used);
                    } else {
                        ko!("PII routing", &format!("got tier={}", resp.tier_used))
                    }
                }
                Err(e) => ko!("PII request", &e.to_string()),
            }
        }
        Err(e) => ko!("PII init", &e.to_string()),
    }

    let total = p + f;
    println!("\n╔══════════════════════════════════════════════╗");
    if f == 0 {
        println!("║  ALL {} TESTS PASSED — REAL Verified ✓     ║", total);
    } else {
        println!(
            "║  {}/{} passed, {} FAILED ✗                  ║",
            p, total, f
        );
    }
    println!("╚══════════════════════════════════════════════╝");
    if f > 0 {
        std::process::exit(1);
    }
}
