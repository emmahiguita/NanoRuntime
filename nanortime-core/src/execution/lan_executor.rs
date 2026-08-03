use crate::error::{Result, NanoError};
use reqwest::Client;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct LanRequest {
    pub prompt: String,
    pub max_tokens: Option<u32>,
    pub temperature: Option<f32>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct LanResponse {
    pub text: String,
    pub confidence: f32,
}

pub struct LanExecutor {
    client: Client,
    endpoint: String,
}

impl LanExecutor {
    pub fn new(ip_or_url: &str) -> Self {
        let endpoint = if ip_or_url.starts_with("http") {
            format!("{}/v1/chat/completions", ip_or_url)
        } else {
            format!("http://{}/v1/chat/completions", ip_or_url)
        };
        
        Self {
            client: Client::new(),
            endpoint,
        }
    }

    pub async fn execute(&self, prompt: &str) -> Result<LanResponse> {
        let req = LanRequest {
            prompt: prompt.to_string(),
            max_tokens: Some(2048),
            temperature: Some(0.7),
        };

        let response = self.client
            .post(&self.endpoint)
            .json(&req)
            .send()
            .await
            .map_err(|e| NanoError::Network(format!("LAN execution failed: {}", e)))?;

        if !response.status().is_success() {
            return Err(NanoError::Network(format!("LAN tier returned error status: {}", response.status())));
        }

        let lan_res = response
            .json::<LanResponse>()
            .await
            .map_err(|e| NanoError::Parse(format!("Failed to parse LAN response: {}", e)))?;

        Ok(lan_res)
    }
}
