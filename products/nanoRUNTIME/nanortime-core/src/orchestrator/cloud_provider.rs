//! CloudProvider trait — Open/Closed Principle for cloud LLM backends.
//!
//! Instead of hardcoding Anthropic/Gemini/OpenAI in the orchestrator's
//! `execute_cloud` method (which requires modifying Orchestrator source
//! to add a new provider — violating OCP), each provider implements this
//! trait. New providers are added by creating a new struct + impl without
//! touching existing code.
//!
//! ## Usage
//!
//! ```rust,ignore
//! let provider = AnthropicProvider::new(api_key);
//! let response = provider.generate("Claude", "What is AI?", 1024, 0.7).await?;
//! ```
//!
//! The orchestrator selects a provider by name and delegates generation
//! through the trait — no match statements, no source modifications.

use crate::error::{NanoError, Result};
use async_trait::async_trait;

/// Configuration for a cloud generation request.
#[derive(Debug, Clone)]
pub struct CloudRequest {
    /// Model name (e.g., "claude-sonnet-4-20250514", "gemini-2.0-flash").
    pub model: String,
    /// The prompt text.
    pub prompt: String,
    /// Maximum tokens to generate.
    pub max_tokens: usize,
    /// Sampling temperature (0.0-1.0).
    pub temperature: f32,
    /// Top-p nucleus sampling parameter.
    pub top_p: f32,
}

/// Trait for cloud-based LLM providers.
///
/// Implementations should handle API-specific details internally.
/// The orchestrator only depends on this trait, not on concrete providers
/// (Dependency Inversion Principle).
#[async_trait]
pub trait CloudProvider: Send + Sync {
    /// Display name of this provider (e.g., "anthropic", "openai").
    fn name(&self) -> &str;

    /// Generate a completion from the cloud model.
    ///
    /// # Arguments
    /// - `request`: Generation parameters including model, prompt, and sampling config.
    ///
    /// # Returns
    /// The generated text response.
    async fn generate(&self, request: &CloudRequest) -> Result<String>;

    /// Check if this provider is healthy/available.
    async fn health_check(&self) -> bool;
}

/// Anthropic (Claude) cloud provider.
pub struct AnthropicProvider {
    api_key: String,
    client: reqwest::Client,
}

impl AnthropicProvider {
    pub fn new(api_key: String) -> Result<Self> {
        Ok(Self {
            api_key,
            client: reqwest::Client::builder()
                .timeout(std::time::Duration::from_secs(60))
                .build()
                .map_err(|e| NanoError::Internal {
                    message: format!("Failed to build Anthropic HTTP client: {}", e),
                })?,
        })
    }
}

#[async_trait]
impl CloudProvider for AnthropicProvider {
    fn name(&self) -> &str {
        "anthropic"
    }

    async fn generate(&self, request: &CloudRequest) -> Result<String> {
        let resp = self
            .client
            .post("https://api.anthropic.com/v1/messages")
            .header("x-api-key", &self.api_key)
            .header("anthropic-version", "2023-06-01")
            .header("Content-Type", "application/json")
            .json(&serde_json::json!({
                "model": request.model,
                "max_tokens": request.max_tokens,
                "messages": [{"role": "user", "content": request.prompt}]
            }))
            .send()
            .await?;

        let status = resp.status();
        let body: serde_json::Value = resp.json().await?;

        if !status.is_success() {
            return Err(crate::error::NanoError::Internal {
                message: format!("Anthropic API error ({}): {}", status, body),
            });
        }

        body["content"][0]["text"]
            .as_str()
            .map(|s| s.to_string())
            .ok_or_else(|| crate::error::NanoError::Internal {
                message: format!("Anthropic response missing content[0].text: {:?}", body),
            })
    }

    async fn health_check(&self) -> bool {
        self.client
            .get("https://api.anthropic.com/v1/messages")
            .header("x-api-key", &self.api_key)
            .send()
            .await
            .map(|r| {
                r.status().is_success() || r.status().as_u16() == 401 || r.status().as_u16() == 403
            })
            .unwrap_or(false)
    }
}

/// Google Gemini cloud provider.
pub struct GeminiProvider {
    api_key: String,
    client: reqwest::Client,
}

impl GeminiProvider {
    pub fn new(api_key: String) -> Result<Self> {
        Ok(Self {
            api_key,
            client: reqwest::Client::builder()
                .timeout(std::time::Duration::from_secs(60))
                .build()
                .map_err(|e| NanoError::Internal {
                    message: format!("Failed to build Gemini HTTP client: {}", e),
                })?,
        })
    }
}

#[async_trait]
impl CloudProvider for GeminiProvider {
    fn name(&self) -> &str {
        "gemini"
    }

    async fn generate(&self, request: &CloudRequest) -> Result<String> {
        let model = if request.model.is_empty() {
            "gemini-2.0-flash"
        } else {
            &request.model
        };
        let url = format!(
            "https://generativelanguage.googleapis.com/v1/models/{}:generateContent",
            model
        );

        let resp = self
            .client
            .post(&url)
            .header("x-goog-api-key", &self.api_key)
            .header("Content-Type", "application/json")
            .json(&serde_json::json!({
                "contents": [{"parts": [{"text": request.prompt}]}],
                "generationConfig": {
                    "maxOutputTokens": request.max_tokens,
                    "temperature": request.temperature,
                }
            }))
            .send()
            .await?;

        let status = resp.status();
        let body: serde_json::Value = resp.json().await?;

        if !status.is_success() {
            return Err(crate::error::NanoError::Internal {
                message: format!("Gemini API error ({}): {}", status, body),
            });
        }

        body["candidates"][0]["content"]["parts"][0]["text"]
            .as_str()
            .map(|s| s.to_string())
            .ok_or_else(|| crate::error::NanoError::Internal {
                message: format!("Gemini response missing text: {:?}", body),
            })
    }

    async fn health_check(&self) -> bool {
        let url =
            "https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent";
        self.client
            .get(url)
            .header("x-goog-api-key", &self.api_key)
            .send()
            .await
            .map(|r| {
                r.status().is_success() || r.status().as_u16() == 401 || r.status().as_u16() == 403
            })
            .unwrap_or(false)
    }
}

/// OpenAI cloud provider.
pub struct OpenAiProvider {
    api_key: String,
    client: reqwest::Client,
}

impl OpenAiProvider {
    pub fn new(api_key: String) -> Result<Self> {
        Ok(Self {
            api_key,
            client: reqwest::Client::builder()
                .timeout(std::time::Duration::from_secs(60))
                .build()
                .map_err(|e| NanoError::Internal {
                    message: format!("Failed to build OpenAI HTTP client: {}", e),
                })?,
        })
    }
}

#[async_trait]
impl CloudProvider for OpenAiProvider {
    fn name(&self) -> &str {
        "openai"
    }

    async fn generate(&self, request: &CloudRequest) -> Result<String> {
        let resp = self
            .client
            .post("https://api.openai.com/v1/chat/completions")
            .header("Authorization", format!("Bearer {}", self.api_key))
            .header("Content-Type", "application/json")
            .json(&serde_json::json!({
                "model": request.model,
                "max_tokens": request.max_tokens,
                "messages": [{"role": "user", "content": request.prompt}]
            }))
            .send()
            .await?;

        let status = resp.status();
        let body: serde_json::Value = resp.json().await?;

        if !status.is_success() {
            return Err(crate::error::NanoError::Internal {
                message: format!("OpenAI API error ({}): {}", status, body),
            });
        }

        body["choices"][0]["message"]["content"]
            .as_str()
            .map(|s| s.to_string())
            .ok_or_else(|| crate::error::NanoError::Internal {
                message: format!("OpenAI response missing content: {:?}", body),
            })
    }

    async fn health_check(&self) -> bool {
        self.client
            .get("https://api.openai.com/v1/models")
            .header("Authorization", format!("Bearer {}", self.api_key))
            .send()
            .await
            .map(|r| {
                r.status().is_success() || r.status().as_u16() == 401 || r.status().as_u16() == 403
            })
            .unwrap_or(false)
    }
}

/// Provider registry — maps provider names to implementations.
///
/// Instead of a match statement in Orchestrator, providers are
/// registered here. Adding a new provider means adding it to this
/// struct — no Orchestrator source changes required (OCP).
pub struct ProviderRegistry {
    providers: Vec<Box<dyn CloudProvider>>,
}

impl ProviderRegistry {
    pub fn new() -> Self {
        Self {
            providers: Vec::new(),
        }
    }

    /// Register a cloud provider.
    pub fn register(&mut self, provider: Box<dyn CloudProvider>) {
        tracing::info!("CloudProvider registered: {}", provider.name());
        self.providers.push(provider);
    }

    /// Find a provider by name.
    pub fn find(&self, name: &str) -> Option<&dyn CloudProvider> {
        self.providers
            .iter()
            .find(|p| p.name() == name)
            .map(|p| p.as_ref())
    }

    /// List all registered provider names.
    pub fn list_names(&self) -> Vec<&str> {
        self.providers.iter().map(|p| p.name()).collect()
    }
}

impl Default for ProviderRegistry {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Mock provider for testing — demonstrates OCP: test code
    /// implements the trait without touching production providers.
    struct MockProvider {
        response: String,
    }

    #[async_trait]
    impl CloudProvider for MockProvider {
        fn name(&self) -> &str {
            "mock"
        }
        async fn generate(&self, _req: &CloudRequest) -> Result<String> {
            Ok(self.response.clone())
        }
        async fn health_check(&self) -> bool {
            true
        }
    }

    #[tokio::test]
    async fn test_provider_registry() {
        let mut registry = ProviderRegistry::new();
        registry.register(Box::new(MockProvider {
            response: "hello".into(),
        }));

        let provider = registry.find("mock").expect("should find mock");
        assert_eq!(provider.name(), "mock");

        let result = provider
            .generate(&CloudRequest {
                model: "test".into(),
                prompt: "hi".into(),
                max_tokens: 10,
                temperature: 0.0,
                top_p: 1.0,
            })
            .await
            .unwrap();

        assert_eq!(result, "hello");
    }

    #[tokio::test]
    async fn test_provider_not_found() {
        let registry = ProviderRegistry::new();
        assert!(registry.find("nonexistent").is_none());
    }

    #[tokio::test]
    async fn test_list_names() {
        let mut registry = ProviderRegistry::new();
        registry.register(Box::new(MockProvider {
            response: "a".into(),
        }));
        registry.register(Box::new(MockProvider {
            response: "b".into(),
        }));
        assert_eq!(registry.list_names(), vec!["mock", "mock"]);
    }
}
