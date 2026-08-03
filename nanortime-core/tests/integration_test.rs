//! Integration tests for NanoAI Runtime.
//!
//! Tests the full pipeline: privacy → RAG → routing → execution.
//! Requires the `simulated` feature to run without a real GGUF model.
//! Run with: cargo test --features simulated

#![cfg(feature = "simulated")]

use std::io::Write;

use nanortime_core::{Config, NanoRuntime, UserRequest};

/// Creates a test runtime with a temporary dummy model file.
async fn setup_test_runtime() -> (NanoRuntime, tempfile::TempDir) {
    let dir = tempfile::tempdir().expect("Failed to create temp dir");
    let model_path = dir.path().join("dummy.gguf");
    std::fs::File::create(&model_path)
        .and_then(|mut f| f.write_all(b"dummy gguf content"))
        .expect("Failed to create dummy model file");

    let mut config = Config::default_config();
    config.local_model.path = model_path.to_string_lossy().to_string();

    let runtime = NanoRuntime::new(config).await.expect("Failed to create runtime");
    (runtime, dir)
}

#[tokio::test]
async fn test_runtime_initialization() {
    let (_runtime, _dir) = setup_test_runtime().await;
}

#[tokio::test]
async fn test_process_simple_request() {
    let (runtime, _dir) = setup_test_runtime().await;

    let response = runtime
        .process_request(UserRequest {
            prompt: "Hello, how are you?".to_string(),
            context: None,
            history: None,
        })
        .await
        .unwrap();

    assert!(!response.text.is_empty());
    assert_eq!(response.tier_used, "local");
}

#[tokio::test]
async fn test_process_request_with_history() {
    let (runtime, _dir) = setup_test_runtime().await;

    let response = runtime
        .process_request(UserRequest {
            prompt: "What did I just ask?".to_string(),
            context: None,
            history: Some(vec![
                nanortime_core::ChatMessage {
                    role: "user".to_string(),
                    content: "What is Rust?".to_string(),
                },
                nanortime_core::ChatMessage {
                    role: "assistant".to_string(),
                    content: "Rust is a systems programming language.".to_string(),
                },
            ]),
        })
        .await
        .unwrap();

    assert!(!response.text.is_empty());
}

#[tokio::test]
async fn test_process_request_with_context() {
    let (runtime, _dir) = setup_test_runtime().await;

    let response = runtime
        .process_request(UserRequest {
            prompt: "Summarize the document".to_string(),
            context: Some("This is a long document about AI safety...".to_string()),
            history: None,
        })
        .await
        .unwrap();

    assert!(!response.text.is_empty());
}

#[tokio::test]
async fn test_index_and_search_rag() {
    let (runtime, _dir) = setup_test_runtime().await;

    runtime
        .index_document(
            "NanoAI is a hybrid edge-cloud AI runtime built in Rust.",
            serde_json::json!({"source": "readme.md"}),
        )
        .await
        .unwrap();

    let response = runtime
        .process_request(UserRequest {
            prompt: "What is NanoAI?".to_string(),
            context: None,
            history: None,
        })
        .await
        .unwrap();

    assert!(!response.text.is_empty());
}

#[tokio::test]
async fn test_tool_registration() {
    let (runtime, _dir) = setup_test_runtime().await;

    let tool_json = r#"{
        "name": "echo",
        "description": "Echo back the input",
        "parameters": {
            "message": { "type": "string", "required": true }
        },
        "execution": {
            "type": "http",
            "method": "GET",
            "url": "https://httpbin.org/get?msg={{message}}"
        }
    }"#;

    let result = runtime.register_tool(tool_json).await;
    assert!(result.is_ok());

    let tools = runtime.tool_executor().list_tools().await;
    assert!(tools.contains(&"echo".to_string()));
}

#[tokio::test]
async fn test_privacy_filter_forces_local() {
    let dir = tempfile::tempdir().expect("Failed to create temp dir");
    let model_path = dir.path().join("dummy.gguf");
    std::fs::File::create(&model_path)
        .and_then(|mut f| f.write_all(b"dummy gguf content"))
        .expect("Failed to create dummy model file");

    let mut config = Config::default_config();
    config.local_model.path = model_path.to_string_lossy().to_string();
    config.tiers.tier3.enabled = true;
    std::env::set_var("NANO_API_KEY", "test-key");

    let runtime = NanoRuntime::new(config).await.unwrap();

    let response = runtime
        .process_request(UserRequest {
            prompt: "Send an email to juan@ejemplo.com with my card 4111-1111-1111-1111"
                .to_string(),
            context: None,
            history: None,
        })
        .await
        .unwrap();

    assert_eq!(response.tier_used, "local");
}

#[tokio::test]
async fn test_grammar_validation() {
    use nanortime_core::inference::grammar::Grammar;

    let grammar = Grammar::json_tool_call();
    assert!(grammar.validate(r#"{"tool": "get_weather", "parameters": {"city": "London"}}"#));
    assert!(!grammar.validate("not json at all"));
    assert!(grammar.validate(r#"{"tool": "echo", "parameters": {}}"#));
}

#[tokio::test]
async fn test_hallucination_detector() {
    use nanortime_core::inference::research::hallucination_detector::{
        HallucinationDetector, HallucinationType,
    };

    let mut d = HallucinationDetector::new(0.2, 0.8, 5);
    for (t, p) in &[("fn", 0.95), ("main", 0.92), ("(", 0.88), (")", 0.85)] {
        d.feed_token(t, *p);
    }
    assert!(d.check().is_none());

    d.feed_token("nonexistent_api", 0.03);
    let s = d.check();
    assert!(s.is_some());
    assert_eq!(s.unwrap().htype, HallucinationType::LowProbability);
}

#[tokio::test]
async fn test_index_directory_reads_files() {
    let dir = tempfile::tempdir().unwrap();
    let model_path = dir.path().join("dummy.gguf");
    std::fs::File::create(&model_path)
        .and_then(|mut f| f.write_all(b"dummy")) .unwrap();

    let src = dir.path().join("src");
    std::fs::create_dir_all(&src).unwrap();
    std::fs::write(src.join("main.rs"), "fn main() { println!(\"hello\"); }").unwrap();
    std::fs::write(src.join("lib.py"), "def hello():\n    print('hello')").unwrap();
    std::fs::write(src.join("binary"), &[0u8; 50]).unwrap(); // binary, no ext

    let mut cfg = Config::default_config();
    cfg.local_model.path = model_path.to_string_lossy().to_string();
    let rt = NanoRuntime::new(cfg).await.unwrap();

    let count = rt.index_directory(src.to_str().unwrap()).await.unwrap();
    assert_eq!(count, 2, "Should index 2 text files (rs + py)");
}
