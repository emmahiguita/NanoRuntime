//! Streaming Output — Real-time token delivery with auto-completion.
//!
//! Provides stop-sequence detection, truncation recovery, and a
//! lightweight event stream for WebSocket/CLI/TUI clients.
//!
//! ## Integration
//! Hook this into the inference loop: after each `llama_decode`, push
//! the token through `StreamingOutput::push_token()`. The module handles
//! stop detection, truncation recovery, and formats output for clients.

/// Configuration for streaming generation.
#[derive(Debug, Clone)]
pub struct StreamingConfig {
    /// Maximum tokens before forced stop.
    pub max_tokens: usize,
    /// Sequences that trigger natural stop.
    pub stop_sequences: Vec<String>,
    /// Minimum confidence to continue generating.
    pub min_confidence: f32,
    /// Whether to auto-complete truncated responses.
    pub auto_complete: bool,
}

impl Default for StreamingConfig {
    fn default() -> Self {
        Self {
            max_tokens: 256,
            stop_sequences: vec![
                "\n\n".into(),
                "###".into(),
                "USER:".into(),
                "<|endoftext|>".into(),
                "<|im_end|>".into(),
            ],
            min_confidence: 0.5,
            auto_complete: true,
        }
    }
}

/// A single streaming event sent to the client.
#[derive(Debug, Clone)]
pub enum StreamEvent {
    /// A new token was generated.
    Token {
        text: String,
        confidence: f32,
    },
    /// Generation stopped naturally (stop sequence matched).
    Stopped {
        reason: String,
    },
    /// Generation truncated by token limit.
    Truncated {
        tokens_generated: usize,
    },
    /// Generation completed successfully.
    Completed {
        tokens_generated: usize,
        total_confidence: f32,
    },
}

/// Streaming output manager.
pub struct StreamingOutput {
    config: StreamingConfig,
    buffer: String,
    tokens_generated: usize,
    total_confidence: f32,
    stopped: bool,
}

impl StreamingOutput {
    /// Create a new streaming output manager.
    pub fn new(config: StreamingConfig) -> Self {
        Self {
            config,
            buffer: String::with_capacity(4096),
            tokens_generated: 0,
            total_confidence: 0.0,
            stopped: false,
        }
    }

    /// Push a token into the stream.
    ///
    /// Returns `Some(StreamEvent)` if the client should be notified,
    /// or `None` if generation should continue silently.
    pub fn push_token(
        &mut self,
        token_text: &str,
        confidence: f32,
    ) -> Option<StreamEvent> {
        if self.stopped {
            return None;
        }

        self.buffer.push_str(token_text);
        self.tokens_generated += 1;
        self.total_confidence += confidence;

        // Confidence check
        if self.tokens_generated > 5 && confidence < self.config.min_confidence {
            self.stopped = true;
            return Some(StreamEvent::Stopped {
                reason: format!("low confidence ({:.2})", confidence),
            });
        }

        // Stop sequence detection
        for seq in &self.config.stop_sequences {
            if self.buffer.ends_with(seq) {
                // Remove the stop sequence from output
                let trim_len = seq.len();
                self.buffer.truncate(self.buffer.len() - trim_len);
                self.stopped = true;
                return Some(StreamEvent::Stopped {
                    reason: format!("stop sequence: {:?}", seq),
                });
            }
        }

        // Token limit
        if self.tokens_generated >= self.config.max_tokens {
            self.stopped = true;

            // Auto-complete truncated responses
            if self.config.auto_complete && !self.is_sentence_complete() {
                self.buffer.push_str("...");
            }

            return Some(StreamEvent::Truncated {
                tokens_generated: self.tokens_generated,
            });
        }

        // Normal token — send to client
        Some(StreamEvent::Token {
            text: token_text.to_string(),
            confidence,
        })
    }

    /// Finalize generation. Call after the inference loop ends.
    pub fn finalize(&mut self) -> StreamEvent {
        if !self.stopped {
            // Auto-complete if needed
            if self.config.auto_complete && !self.is_sentence_complete() {
                self.buffer.push_str("...");
            }
        }

        let avg_conf = if self.tokens_generated > 0 {
            self.total_confidence / self.tokens_generated as f32
        } else {
            0.0
        };

        StreamEvent::Completed {
            tokens_generated: self.tokens_generated,
            total_confidence: avg_conf,
        }
    }

    /// Get the complete generated text.
    pub fn text(&self) -> &str {
        self.buffer.trim()
    }

    /// Number of tokens generated so far.
    pub fn token_count(&self) -> usize {
        self.tokens_generated
    }

    /// Whether generation has stopped.
    pub fn is_stopped(&self) -> bool {
        self.stopped
    }

    /// Format output for display, with optional status prefix.
    pub fn display(&self, status: Option<&str>) -> String {
        match status {
            Some(s) if !s.is_empty() => format!("[{}] {}", s, self.text()),
            _ => self.text().to_string(),
        }
    }

    /// Check if the last character completes a sentence.
    fn is_sentence_complete(&self) -> bool {
        self.buffer
            .trim_end()
            .chars()
            .last()
            .map(|c| c == '.' || c == '!' || c == '?' || c == '\n')
            .unwrap_or(true)
    }
}

/// Render a stream event as a user-facing string.
pub fn format_event(event: &StreamEvent, _so: &StreamingOutput) -> String {
    match event {
        StreamEvent::Token { text, .. } => text.clone(),
        StreamEvent::Stopped { reason } =>
            format!("\n[Generation stopped: {}]\n", reason),
        StreamEvent::Truncated { tokens_generated } =>
            format!("\n[Truncated at {} tokens — context optimized]\n", tokens_generated),
        StreamEvent::Completed { tokens_generated, total_confidence } =>
            format!("\n\n[Done: {} tokens, avg confidence {:.2}]\n", tokens_generated, total_confidence),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_simple_streaming() {
        let mut so = StreamingOutput::new(StreamingConfig::default());
        let tokens = ["Hello", ",", " ", "world", "."];
        for t in &tokens {
            so.push_token(t, 0.9);
        }
        assert_eq!(so.text(), "Hello, world.");
        assert_eq!(so.token_count(), 5);
    }

    #[test]
    fn test_stop_sequence() {
        let mut so = StreamingOutput::new(StreamingConfig::default());
        let tokens = ["Hi", ".", "\n", "\n", "extra"];
        for t in &tokens {
            let event = so.push_token(t, 0.9);
            if so.is_stopped() { break; }
        }
        // Should have stopped at "\n\n"
        assert!(so.is_stopped());
        assert_eq!(so.text(), "Hi.");
    }

    #[test]
    fn test_truncation_auto_complete() {
        let mut so = StreamingOutput::new(StreamingConfig {
            max_tokens: 3,
            auto_complete: true,
            ..Default::default()
        });
        so.push_token("Incomplete", 0.9);
        so.push_token(" ", 0.9);
        let ev = so.push_token("sentence", 0.9).unwrap();
        assert!(matches!(ev, StreamEvent::Truncated { .. }));
        assert!(so.text().ends_with("..."));
    }

    #[test]
    fn test_low_confidence_stop() {
        let mut so = StreamingOutput::new(StreamingConfig {
            min_confidence: 0.8,
            ..Default::default()
        });
        // Generate 6 high-confidence tokens first
        for _ in 0..6 { so.push_token("x", 0.9); }
        // Then a low-confidence one should stop
        let ev = so.push_token("y", 0.3);
        assert!(so.is_stopped());
    }
}
