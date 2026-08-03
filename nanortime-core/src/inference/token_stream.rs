//! Stream de tokens para generación en tiempo real.
//!
//! Proporciona un stream async que emite tokens a medida que
//! el modelo los genera, permitiendo mostrar la respuesta
//! progresivamente al usuario.

use tokio::sync::mpsc;

use crate::error::{NanoError, Result};

/// Un token individual generado por el modelo.
#[derive(Debug, Clone)]
pub struct Token {
    /// El texto del token.
    pub text: String,
    /// La probabilidad del token (para cálculo de entropía).
    pub probability: f32,
    /// Si este token es un token de parada (EOS).
    pub is_stop: bool,
}

/// Stream asíncrono de tokens.
///
/// Los consumidores pueden iterar sobre este stream para recibir
/// tokens a medida que el modelo los genera. Esto permite mostrar
/// la respuesta progresivamente en una UI.
pub struct TokenStream {
    /// Receptor del channel interno.
    receiver: mpsc::Receiver<Token>,
    /// Si el stream ha terminado.
    done: bool,
}

impl TokenStream {
    /// Crea un nuevo stream de tokens a partir de un channel.
    pub fn new(receiver: mpsc::Receiver<Token>) -> Self {
        Self {
            receiver,
            done: false,
        }
    }

    /// Recolecta todos los tokens restantes del stream.
    ///
    /// Útil cuando no se necesita streaming en tiempo real y
    /// se quiere obtener la respuesta completa de una vez.
    pub async fn collect_all(&mut self) -> Vec<Token> {
        let mut tokens = Vec::new();
        while let Some(token) = self.receiver.recv().await {
            tokens.push(token);
        }
        self.done = true;
        tokens
    }

    /// Recolecta tokens y los une en un solo string.
    pub async fn collect_text(&mut self) -> String {
        let tokens = self.collect_all().await;
        tokens.into_iter().map(|t| t.text).collect()
    }

    /// Recolecta tokens y extrae las probabilidades.
    pub async fn collect_probabilities(&mut self) -> Vec<f32> {
        let tokens = self.collect_all().await;
        tokens.into_iter().map(|t| t.probability).collect()
    }
}

/// Builder para crear un stream de tokens manualmente.
///
/// Útil para testing y para inyectar tokens desde fuentes
/// que no son llama.cpp (ej. respuestas de API cloud).
pub struct TokenStreamBuilder {
    sender: mpsc::Sender<Token>,
    receiver: Option<mpsc::Receiver<Token>>,
}

impl TokenStreamBuilder {
    /// Crea un nuevo builder con capacidad de buffer especificada.
    pub fn new(buffer_size: usize) -> Self {
        let (sender, receiver) = mpsc::channel(buffer_size);
        Self {
            sender,
            receiver: Some(receiver),
        }
    }

    /// Envía un token al stream.
    pub async fn send(&self, token: Token) -> Result<()> {
        self.sender
            .send(token)
            .await
            .map_err(|e| NanoError::Internal {
                message: format!("Failed to send token: {}", e),
            })
    }

    /// Envía un token de texto simple.
    pub async fn send_text(&self, text: &str, probability: f32) -> Result<()> {
        self.send(Token {
            text: text.to_string(),
            probability,
            is_stop: false,
        })
        .await
    }

    /// Señaliza el fin del stream.
    pub fn finish(self) -> TokenStream {
        // Drop sender to close the channel
        drop(self.sender);
        TokenStream::new(self.receiver.unwrap())
    }

    /// Construye el stream sin cerrar el sender (para uso continuo).
    pub fn build(self) -> (Self, TokenStream) {
        let receiver = self.receiver.unwrap();
        let stream = TokenStream::new(receiver);

        // Create new channel for continued use
        let (new_sender, new_receiver) = mpsc::channel(256);

        let new_self = Self {
            sender: new_sender,
            receiver: Some(new_receiver),
        };

        (new_self, stream)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_token_stream_builder() {
        let builder = TokenStreamBuilder::new(10);
        builder.send_text("Hello", 0.9).await.unwrap();
        builder.send_text(" world", 0.85).await.unwrap();
        builder.send_text("!", 0.95).await.unwrap();

        let mut stream = builder.finish();
        let text = stream.collect_text().await;
        assert_eq!(text, "Hello world!");
    }

    #[tokio::test]
    async fn test_collect_probabilities() {
        let builder = TokenStreamBuilder::new(10);
        builder.send_text("A", 0.9).await.unwrap();
        builder.send_text("B", 0.7).await.unwrap();
        builder.send_text("C", 0.5).await.unwrap();

        let mut stream = builder.finish();
        let probs = stream.collect_probabilities().await;
        assert_eq!(probs.len(), 3);
        assert!((probs[0] - 0.9).abs() < 0.01);
        assert!((probs[2] - 0.5).abs() < 0.01);
    }
}
