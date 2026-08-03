//! Comprehensive validation script for NanoAI v0.1.0
//! Tests all core components: config, PII, entropy, routing, tools, RAG.
//! Run: cargo run --example validate

use std::io::Write;

use nanortime_core::{
    config::manifest::Config,
    execution::{ToolExecutor, VectorEngine},
    orchestrator::{confidence, privacy},
    NanoRuntime, UserRequest,
};

#[tokio::main]
async fn main() {
    let mut passed = 0;
    let mut failed = 0;

    println!("╔══════════════════════════════════════════════╗");
    println!("║     NanoAI v0.1.0 — Validation Suite         ║");
    println!("╚══════════════════════════════════════════════╝\n");

    // ── 1. Config Loading ────────────────────────────────────
    println!("─── Config Loading ───");
    match test_config_loading() {
        Ok(()) => { passed += 1; println!("  ✓ Config loads and validates") }
        Err(e) => { failed += 1; println!("  ✗ Config: {}", e) }
    }

    // ── 2. PII Detection ─────────────────────────────────────
    println!("\n─── PII Detection ───");
    let pii_tests = [
        ("Email detection", "Contact juan@ejemplo.com", true),
        ("Phone detection", "Call 555-123-4567", true),
        ("Credit card", "Card: 4111-1111-1111-1111", true),
        ("Clean text", "Hello world, how are you?", false),
        ("Anonymization", "", false), // special case below
    ];

    for (name, text, should_detect) in &pii_tests {
        if *name == "Anonymization" {
            let original = "Email: juan@mail.com, Phone: 555-123-4567";
            let anon = privacy::anonymize(original);
            if anon.contains("[EMAIL]") && anon.contains("[PHONE]")
                && !anon.contains("juan@mail.com") && !anon.contains("555-123-4567")
            {
                passed += 1;
                println!("  ✓ Anonymization works");
            } else {
                failed += 1;
                println!("  ✗ Anonymization failed: {}", anon);
            }
        } else {
            let detected = privacy::contains_pii(text);
            if detected == *should_detect {
                passed += 1;
                println!("  ✓ {} ({})", name, if detected { "detected" } else { "clean" });
            } else {
                failed += 1;
                println!("  ✗ {}: expected {}, got {}", name, should_detect, detected);
            }
        }
    }

    // ── 3. Entropy & Confidence ──────────────────────────────
    println!("\n─── Entropy & Confidence ───");
    let entropy_tests = [
        ("Uniform [0.25x4]", vec![0.25, 0.25, 0.25, 0.25], 2.0, 0.01),
        ("Certain [1.0, 0.0]", vec![1.0, 0.0], 0.0, 0.01),
        ("Mixed [0.7, 0.2, 0.1]", vec![0.7, 0.2, 0.1], 1.156, 0.05),
    ];

    for (name, probs, expected, tolerance) in &entropy_tests {
        let entropy = confidence::calculate_entropy(probs);
        if (entropy - expected).abs() < *tolerance {
            passed += 1;
            println!("  ✓ {}: entropy={:.4}", name, entropy);
        } else {
            failed += 1;
            println!("  ✗ {}: expected {:.4}, got {:.4}", name, expected, entropy);
        }
    }

    // Confidence score: low entropy → high confidence
    let high_conf = confidence::entropy_to_confidence(&[0.9, 0.05, 0.05]);
    let low_conf = confidence::entropy_to_confidence(&[0.5, 0.5]);
    if high_conf > 0.5 && low_conf < 0.5 {
        passed += 1;
        println!("  ✓ Confidence scoring: high={:.3}, low={:.3}", high_conf, low_conf);
    } else {
        failed += 1;
        println!("  ✗ Confidence scoring off");
    }

    // Perplexity
    let ppl = confidence::perplexity(&[0.25, 0.25, 0.25, 0.25]);
    if (ppl - 4.0).abs() < 0.1 {
        passed += 1;
        println!("  ✓ Perplexity: {:.2} (expected ~4.0)", ppl);
    } else {
        failed += 1;
        println!("  ✗ Perplexity: {:.2} (expected ~4.0)", ppl);
    }

    // ── 4. Tool Executor ─────────────────────────────────────
    println!("\n─── Tool Executor ───");
    match test_tool_executor().await {
        Ok(()) => { passed += 1; println!("  ✓ Tool registration and listing") }
        Err(e) => { failed += 1; println!("  ✗ Tools: {}", e) }
    }

    match test_tool_validation().await {
        Ok(()) => { passed += 1; println!("  ✓ Tool parameter validation") }
        Err(e) => { failed += 1; println!("  ✗ Tool validation: {}", e) }
    }

    match test_template_interpolation().await {
        Ok(()) => { passed += 1; println!("  ✓ Template interpolation ({{{{var}}}} syntax)") }
        Err(e) => { failed += 1; println!("  ✗ Template: {}", e) }
    }

    // ── 5. Vector Engine (RAG) ───────────────────────────────
    println!("\n─── Vector Engine (RAG) ───");
    match test_vector_engine().await {
        Ok(()) => { passed += 1; println!("  ✓ Document indexing and search") }
        Err(e) => { failed += 1; println!("  ✗ RAG: {}", e) }
    }

    match test_vector_clear().await {
        Ok(()) => { passed += 1; println!("  ✓ Index clearing") }
        Err(e) => { failed += 1; println!("  ✗ Clear: {}", e) }
    }

    // ── 6. Routing ──────────────────────────────────────────
    println!("\n─── Routing ───");
    match test_routing_pii().await {
        Ok(()) => { passed += 1; println!("  ✓ PII forces local routing") }
        Err(e) => { failed += 1; println!("  ✗ Routing: {}", e) }
    }

    // ── 7. End-to-End Pipeline ───────────────────────────────
    println!("\n─── End-to-End Pipeline ───");
    match test_e2e_pipeline().await {
        Ok(text) => {
            passed += 1;
            println!("  ✓ Full pipeline: {} chars response", text.len());
            println!("    Response preview: {}...", &text[..text.len().min(80)]);
        }
        Err(e) => { failed += 1; println!("  ✗ Pipeline: {}", e) }
    }

    // ── 8. Memory Manager ────────────────────────────────────
    println!("\n─── Memory Manager ───");
    let mm = nanortime_core::execution::MemoryManager::new(1024, 8192, 0);
    let stats = mm.get_stats();
    if stats.total_system_mb > 0 && stats.available_mb > 0 {
        passed += 1;
        println!("  ✓ Memory stats: {}MB total, {}MB available", stats.total_system_mb, stats.available_mb);
    } else {
        failed += 1;
        println!("  ✗ Memory stats invalid");
    }

    let est_1b5 = nanortime_core::execution::MemoryManager::estimate_model_memory(1.5, 4);
    let est_7b = nanortime_core::execution::MemoryManager::estimate_model_memory(7.0, 4);
    let est_14b = nanortime_core::execution::MemoryManager::estimate_model_memory(14.0, 4);
    if est_1b5 < est_7b && est_7b < est_14b {
        passed += 1;
        println!("  ✓ Model memory estimates: 1.5B={}MB, 7B={}MB, 14B={}MB", est_1b5, est_7b, est_14b);
    } else {
        failed += 1;
        println!("  ✗ Model memory estimates inconsistent");
    }

    // ── 9. Grammar ───────────────────────────────────────────
    println!("\n─── Grammar ───");
    match test_grammar() {
        Ok(()) => { passed += 1; println!("  ✓ JSON tool call grammar") }
        Err(e) => { failed += 1; println!("  ✗ Grammar: {}", e) }
    }

    match test_yes_no_grammar() {
        Ok(()) => { passed += 1; println!("  ✓ Yes/No grammar validation") }
        Err(e) => { failed += 1; println!("  ✗ Yes/No: {}", e) }
    }

    // ── 10. Token Stream ─────────────────────────────────────
    println!("\n─── Token Stream ───");
    match test_token_stream().await {
        Ok(()) => { passed += 1; println!("  ✓ Async token streaming") }
        Err(e) => { failed += 1; println!("  ✗ Stream: {}", e) }
    }

    // ── Summary ──────────────────────────────────────────────
    println!("\n╔══════════════════════════════════════════════╗");
    let total = passed + failed;
    let status = if failed == 0 { "ALL PASSED" } else { "SOME FAILED" };
    println!("║  Results: {}/{} {} {}", passed, total, status, if failed == 0 { "✓" } else { "✗" });
    println!("╚══════════════════════════════════════════════╝");

    if failed > 0 {
        std::process::exit(1);
    }
}

// ── Test implementations ──────────────────────────────────────

fn test_config_loading() -> Result<(), String> {
    // Test default config
    let config = Config::default_config();
    config.validate().map_err(|e| e.to_string())?;

    if config.hybrid_routing.confidence_threshold != 0.85 {
        return Err("Wrong default threshold".into());
    }
    if config.generation.max_tokens != 2048 {
        return Err("Wrong default max_tokens".into());
    }

    // Test validation of invalid config
    let mut bad_config = Config::default_config();
    bad_config.hybrid_routing.confidence_threshold = 2.0;
    if bad_config.validate().is_ok() {
        return Err("Should reject threshold > 1.0".into());
    }

    // Test loading from actual file
    let config = Config::load("nano.manifest.json").map_err(|e| e.to_string())?;
    if config.version != "1.0" {
        return Err("Wrong manifest version".into());
    }

    Ok(())
}

async fn test_tool_executor() -> Result<(), String> {
    let config = Config::default_config();
    let executor = ToolExecutor::new(&config).await.map_err(|e| e.to_string())?;

    let json = r#"{"name":"test_tool","description":"A test tool","parameters":{},"execution":{"type":"http","method":"GET","url":"https://example.com"}}"#;
    executor.register_from_json(json).await.map_err(|e| e.to_string())?;

    let tools = executor.list_tools().await;
    if !tools.contains(&"test_tool".to_string()) {
        return Err("Tool not found after registration".into());
    }

    Ok(())
}

async fn test_tool_validation() -> Result<(), String> {
    let config = Config::default_config();
    let executor = ToolExecutor::new(&config).await.map_err(|e| e.to_string())?;

    let json = r#"{"name":"validate_test","description":"Test","parameters":{"x":{"type":"string","required":true}},"execution":{"type":"http","method":"GET","url":"https://example.com"}}"#;
    executor.register_from_json(json).await.map_err(|e| e.to_string())?;

    let tool = executor.get_tool("validate_test").await.ok_or("Tool not found")?;

    // Valid params
    tool.validate_parameters(&serde_json::json!({"x": "hello"}))
        .map_err(|e| format!("Valid params rejected: {}", e))?;

    // Missing required param
    let result = tool.validate_parameters(&serde_json::json!({}));
    if result.is_ok() {
        return Err("Should reject missing required param".into());
    }

    Ok(())
}

async fn test_template_interpolation() -> Result<(), String> {
    let config = Config::default_config();
    let executor = ToolExecutor::new(&config).await.map_err(|e| e.to_string())?;

    let result = executor.interpolate_template(
        "Hello {{name}}, your score is {{score}}",
        &serde_json::json!({"name": "Alice", "score": 95}),
    );
    if result != "Hello Alice, your score is 95" {
        return Err(format!("Wrong interpolation: '{}'", result));
    }

    Ok(())
}

async fn test_vector_engine() -> Result<(), String> {
    let config = Config::default_config();
    // Clean up any persisted data from previous tests
    let persist_path = std::path::Path::new(&config.memory.vector_db_path).with_extension("json");
    let _ = std::fs::remove_file(&persist_path);
    let engine = VectorEngine::new(&config).await.map_err(|e| e.to_string())?;

    engine.index_document("NanoAI is a hybrid edge-cloud AI runtime in Rust",
        serde_json::json!({"source": "readme"}), None).await.map_err(|e| e.to_string())?;
    engine.index_document("Python is a popular language for AI development",
        serde_json::json!({"source": "article"}), None).await.map_err(|e| e.to_string())?;

    let mut results = engine.search("NanoAI Rust runtime", 5, None).await.map_err(|e| e.to_string())?;
    if results.is_empty() {
        return Err("No results for relevant query".into());
    }
    if !results[0].content.contains("NanoAI") {
        return Err("Top result doesn't contain NanoAI".into());
    }

    Ok(())
}

async fn test_vector_clear() -> Result<(), String> {
    let config = Config::default_config();
    // Clean up any persisted data from previous tests
    let persist_path = std::path::Path::new(&config.memory.vector_db_path).with_extension("json");
    let _ = std::fs::remove_file(&persist_path);
    let engine = VectorEngine::new(&config).await.map_err(|e| e.to_string())?;
    engine.index_document("test", serde_json::json!({}), None).await.map_err(|e| e.to_string())?;
    if engine.document_count().await != 1 {
        return Err("Expected 1 document".into());
    }
    engine.clear().await.map_err(|e| e.to_string())?;
    if engine.document_count().await != 0 {
        return Err("Expected 0 after clear".into());
    }
    // Clean up
    let _ = std::fs::remove_file(&persist_path);
    Ok(())
}

async fn test_routing_pii() -> Result<(), String> {
    let dir = tempfile::tempdir().map_err(|e| e.to_string())?;
    let model_path = dir.path().join("dummy.gguf");
    std::fs::File::create(&model_path)
        .and_then(|mut f| f.write_all(b"dummy"))
        .map_err(|e| e.to_string())?;

    let mut config = Config::default_config();
    config.local_model.path = model_path.to_string_lossy().to_string();
    config.tiers.tier3.enabled = true;
    std::env::set_var("NANO_API_KEY", "test-key");

    let runtime = NanoRuntime::new(config).await.map_err(|e| e.to_string())?;

    let response = runtime.process_request(UserRequest {
        prompt: "Send email to juan@ejemplo.com with card 4111-1111-1111-1111".to_string(),
        context: None,
        history: None,
    }).await.map_err(|e| e.to_string())?;

    if response.tier_used != "local" {
        return Err(format!("PII should force local, got: {}", response.tier_used));
    }
    Ok(())
}

async fn test_e2e_pipeline() -> Result<String, String> {
    let dir = tempfile::tempdir().map_err(|e| e.to_string())?;
    let model_path = dir.path().join("dummy.gguf");
    std::fs::File::create(&model_path)
        .and_then(|mut f| f.write_all(b"dummy"))
        .map_err(|e| e.to_string())?;

    let mut config = Config::default_config();
    config.local_model.path = model_path.to_string_lossy().to_string();

    let runtime = NanoRuntime::new(config).await.map_err(|e| e.to_string())?;

    let response = runtime.process_request(UserRequest {
        prompt: "Hello! What time is it?".to_string(),
        context: None,
        history: None,
    }).await.map_err(|e| e.to_string())?;

    if response.text.is_empty() {
        return Err("Empty response".into());
    }
    if response.tier_used != "local" {
        return Err(format!("Expected local tier, got: {}", response.tier_used));
    }
    Ok(response.text)
}

fn test_grammar() -> Result<(), String> {
    let grammar = nanortime_core::inference::grammar::Grammar::json_tool_call();
    let gbnf = grammar.to_gbnf();
    if !gbnf.contains("root ::=") || !gbnf.contains("object ::=") {
        return Err("Invalid GBNF output".into());
    }

    // Valid JSON should pass
    if !grammar.validate(r#"{"tool": "test", "parameters": {"x": "y"}}"#) {
        return Err("Valid JSON tool call rejected".into());
    }

    // Invalid should fail
    if grammar.validate("not json at all") {
        return Err("Invalid text accepted as valid JSON".into());
    }

    Ok(())
}

fn test_yes_no_grammar() -> Result<(), String> {
    let grammar = nanortime_core::inference::grammar::Grammar::yes_no();
    if !grammar.validate("Yes") { return Err("'Yes' rejected".into()); }
    if !grammar.validate("No") { return Err("'No' rejected".into()); }
    if grammar.validate("Maybe") { return Err("'Maybe' accepted".into()); }
    if grammar.validate("yes") { return Err("'yes' accepted (case-sensitive)".into()); }
    Ok(())
}

async fn test_token_stream() -> Result<(), String> {
    use nanortime_core::inference::token_stream::TokenStreamBuilder;

    let builder = TokenStreamBuilder::new(10);
    builder.send_text("Hello", 0.9).await.map_err(|e| e.to_string())?;
    builder.send_text(" world", 0.85).await.map_err(|e| e.to_string())?;
    builder.send_text("!", 0.95).await.map_err(|e| e.to_string())?;

    let mut stream = builder.finish();
    let text = stream.collect_text().await;
    if text != "Hello world!" {
        return Err(format!("Expected 'Hello world!', got '{}'", text));
    }
    Ok(())
}
