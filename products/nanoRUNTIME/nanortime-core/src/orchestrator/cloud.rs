//! cloud.rs — Cloud inference providers (Tier 3).
//!
//! ## SOLID: Single Responsibility Principle
//! Extracted from `orchestrator/mod.rs` which had ~1000 lines mixing routing,
//! privacy, RAG, tool execution, AND cloud API calls. This module handles only
//! HTTP communication with Anthropic, Gemini, and OpenAI.
//!
//! ## Open/Closed Principle
//! Adding a new provider requires: (1) add variant to match, (2) implement
//! one async fn. The `execute_cloud` dispatcher is the only extension point.

use crate::config::manifest::Tier3Config;
use crate::error::{NanoError, Result};
use crate::orchestrator::cloud_provider::{
    AnthropicProvider, CloudRequest, GeminiProvider, OpenAiProvider, ProviderRegistry,
};
use crate::orchestrator::Response;

/// Dispatches cloud inference to the configured Tier 3 provider.
pub async fn execute_cloud(tier3: &Tier3Config, prompt: &str) -> Result<Response> {
    let api_key = std::env::var(&tier3.api_key_env).map_err(|_| NanoError::ConfigError {
        reason: format!(
            "Tier 3 API key not found in env var '{}'",
            tier3.api_key_env
        ),
    })?;

    let provider_name = match tier3.provider.as_str() {
        "anthropic" => "anthropic",
        "google" | "gemini" => "gemini",
        "openai" => "openai",
        other => {
            return Err(NanoError::ConfigError {
                reason: format!("Unknown Tier 3 provider: {}", other),
            })
        }
    };

    let mut registry = ProviderRegistry::new();
    match provider_name {
        "anthropic" => registry.register(Box::new(AnthropicProvider::new(api_key)?)),
        "gemini" => registry.register(Box::new(GeminiProvider::new(api_key)?)),
        "openai" => registry.register(Box::new(OpenAiProvider::new(api_key)?)),
        _ => unreachable!("provider_name is normalized above"),
    }

    let provider = registry
        .find(provider_name)
        .ok_or_else(|| NanoError::Internal {
            message: format!("Tier 3 provider '{}' was not registered", provider_name),
        })?;

    let response_text = provider
        .generate(&CloudRequest {
            model: tier3.model.clone(),
            prompt: prompt.to_string(),
            max_tokens: tier3.max_tokens,
            temperature: tier3.temperature,
            top_p: 1.0,
        })
        .await?;

    Ok(Response {
        text: response_text,
        tier_used: "cloud".to_string(),
        confidence: None,
        tool_calls: vec![],
        sources: vec![],
        tokens_generated: 0,
        model_memory_mb: 0,
        stats: None,
    })
}
