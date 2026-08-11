//! Motor vectorial — almacenamiento en memoria con embeddings.
//!
//! Almacena documentos con vectores de embedding opcionales.
//! Búsqueda por similitud coseno cuando hay embeddings,
//! fallback a keyword search si no.
//!
//! NOTA: LanceDB está agregado como dependencia para futura
//! integración persistente. Actualmente usamos almacenamiento
//! en memoria con serialización JSON.

use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};

use crate::config::manifest::Config;
use crate::error::Result;
use crate::SourceDocument;

/// Documento indexado con embedding opcional.
#[derive(Debug, Clone)]
struct IndexedDoc {
    content: String,
    metadata: serde_json::Value,
    embedding: Option<Vec<f32>>,
}

/// Motor vectorial en memoria con embeddings y persistencia en disco.
pub struct VectorEngine {
    docs: tokio::sync::RwLock<Vec<IndexedDoc>>,
    embed_dim: tokio::sync::RwLock<Option<usize>>,
    /// Ruta al archivo de persistencia JSON.
    persist_path: tokio::sync::RwLock<Option<std::path::PathBuf>>,
    /// Flag para guardar en lotes: true = hay cambios sin persistir.
    dirty: AtomicBool,
}

impl VectorEngine {
    pub async fn new(_config: &Config) -> Result<Self> {
        let persist_path =
            std::path::Path::new(&_config.memory.vector_db_path).with_extension("json");
        let engine = Self {
            docs: tokio::sync::RwLock::new(Vec::new()),
            embed_dim: tokio::sync::RwLock::new(None),
            persist_path: tokio::sync::RwLock::new(Some(persist_path)),
            dirty: AtomicBool::new(false),
        };
        // Load persisted data on startup
        engine.load_from_disk().await;
        Ok(engine)
    }

    pub async fn index_document(
        &self,
        content: &str,
        metadata: serde_json::Value,
        embedding: Option<Vec<f32>>,
    ) -> Result<()> {
        if content.trim().is_empty() {
            return Ok(());
        }
        if let Some(ref emb) = embedding {
            *self.embed_dim.write().await = Some(emb.len());
        }
        self.docs.write().await.push(IndexedDoc {
            content: content.to_string(),
            metadata,
            embedding,
        });
        // Mark dirty — actual save deferred to flush() (batched, O(1) per doc)
        self.dirty.store(true, Ordering::Release);
        Ok(())
    }

    pub async fn search(
        &self,
        query: &str,
        top_k: usize,
        query_embedding: Option<&[f32]>,
    ) -> Result<Vec<SourceDocument>> {
        if query.trim().is_empty() {
            return Ok(vec![]);
        }
        let docs = self.docs.read().await;
        if docs.is_empty() {
            return Ok(vec![]);
        }

        let mut scored: Vec<(f32, &IndexedDoc)> = if let Some(q_emb) = query_embedding {
            // Semantic search via cosine similarity
            docs.iter()
                .filter_map(|d| {
                    d.embedding.as_ref().map(|d_emb| {
                        let sim = cosine_similarity(q_emb, d_emb);
                        (sim, d)
                    })
                })
                .filter(|(s, _)| *s > 0.0)
                .collect()
        } else {
            // Keyword fallback
            let query_lower = query.to_lowercase();
            let terms: Vec<&str> = query_lower.split_whitespace().collect();
            docs.iter()
                .map(|d| {
                    let cl = d.content.to_lowercase();
                    let s = terms.iter().filter(|t| cl.contains(*t)).count() as f32
                        / terms.len().max(1) as f32;
                    (s, d)
                })
                .filter(|(s, _)| *s > 0.0)
                .collect()
        };

        scored.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap_or(std::cmp::Ordering::Equal));
        Ok(scored
            .into_iter()
            .take(top_k)
            .map(|(s, d)| SourceDocument {
                content: d.content.clone(),
                metadata: d.metadata.clone(),
                similarity: s,
            })
            .collect())
    }

    pub async fn index_directory(&self, path: &str) -> Result<usize> {
        let mut expanded_path = path.to_string();
        if expanded_path.starts_with("~/") || expanded_path.starts_with("~\\") {
            if let Ok(home) = std::env::var("HOME").or_else(|_| std::env::var("USERPROFILE")) {
                expanded_path = expanded_path.replacen("~", &home, 1);
            }
        }
        let dir = Path::new(&expanded_path);
        if !dir.exists() {
            tracing::warn!("Dir not found: {}", expanded_path);
            return Ok(0);
        }
        let exts = [
            "txt", "md", "rs", "py", "js", "ts", "json", "toml", "yaml", "yml", "html", "css",
            "java", "kt", "go", "rb", "php", "c", "cpp", "h", "hpp", "sql", "sh", "ps1", "bat",
            "r", "swift", "dart", "scala", "lua",
        ];
        const MAX_SIZE: u64 = 1024 * 1024; // 1MB

        // Collect file paths first (sync traversal)
        let mut files: Vec<std::path::PathBuf> = Vec::new();
        fn collect(
            dir: &Path,
            exts: &[&str],
            files: &mut Vec<std::path::PathBuf>,
        ) -> std::io::Result<()> {
            if dir.is_dir() {
                for e in std::fs::read_dir(dir)? {
                    let p = e?.path();
                    if p.is_dir() {
                        let n = p.file_name().unwrap_or_default().to_string_lossy();
                        if n.starts_with('.')
                            || [
                                "node_modules",
                                "target",
                                "build",
                                "dist",
                                ".git",
                                "vendor",
                                "cache",
                            ]
                            .contains(&n.as_ref())
                        {
                            continue;
                        }
                        collect(&p, exts, files)?;
                    } else if let Some(ext) = p.extension() {
                        if exts.contains(&ext.to_string_lossy().to_lowercase().as_str())
                            && p.metadata().map(|m| m.len() <= MAX_SIZE).unwrap_or(false)
                        {
                            files.push(p);
                        }
                    }
                }
            }
            Ok(())
        }
        collect(dir, &exts, &mut files)?;

        // Read and index each file asynchronously
        let mut indexed = 0usize;
        for fpath in &files {
            if let Ok(content) = tokio::fs::read_to_string(fpath).await {
                let trimmed = content.trim();
                if trimmed.is_empty() || trimmed.len() < 20 {
                    continue;
                }
                let meta = serde_json::json!({
                    "path": fpath.to_string_lossy(),
                    "ext": fpath.extension().map(|e| e.to_string_lossy()).unwrap_or_default(),
                });
                self.index_document(trimmed, meta, None).await?;
                indexed += 1;
            }
        }

        tracing::info!(
            "Indexed {} files from {} (found {})",
            indexed,
            path,
            files.len()
        );
        Ok(indexed)
    }

    /// Flush dirty state to disk. Call after batch indexing or before shutdown.
    /// No-op if nothing has changed since the last flush.
    pub async fn flush(&self) -> Result<()> {
        if self.dirty.swap(false, Ordering::AcqRel) {
            self.save_to_disk().await;
        }
        Ok(())
    }

    pub async fn document_count(&self) -> usize {
        self.docs.read().await.len()
    }

    pub async fn clear(&self) -> Result<()> {
        self.docs.write().await.clear();
        *self.embed_dim.write().await = None;
        // Delete persisted file
        let path_guard = self.persist_path.read().await;
        if let Some(ref path) = *path_guard {
            let _ = std::fs::remove_file(path);
        }
        Ok(())
    }

    pub async fn embedding_dimension(&self) -> Option<usize> {
        *self.embed_dim.read().await
    }

    /// Guarda todos los documentos en disco (JSON).
    ///
    /// Se llama automáticamente después de indexar documentos.
    pub async fn save_to_disk(&self) {
        let path_guard = self.persist_path.read().await;
        let Some(ref path) = *path_guard else { return };
        match self.export_json().await {
            Ok(json) => {
                if let Some(parent) = path.parent() {
                    let _ = std::fs::create_dir_all(parent);
                }
                if let Err(e) = std::fs::write(path, json) {
                    tracing::warn!("Failed to save vector engine to disk: {}", e);
                } else {
                    tracing::debug!("Vector engine saved to {}", path.display());
                }
            }
            Err(e) => tracing::warn!("Failed to serialize vector engine: {}", e),
        }
    }

    /// Carga documentos desde disco.
    ///
    /// Se llama automáticamente al iniciar el VectorEngine.
    async fn load_from_disk(&self) {
        let path_guard = self.persist_path.read().await;
        let Some(ref path) = *path_guard else { return };
        if !path.exists() {
            tracing::debug!("No vector engine file at {}", path.display());
            return;
        }
        // Only load if the parent directory exists (avoids loading stale data in tests)
        if let Some(parent) = path.parent() {
            if !parent.exists() {
                tracing::debug!(
                    "Vector engine directory {} does not exist, skipping load",
                    parent.display()
                );
                return;
            }
        }
        match std::fs::read_to_string(path) {
            Ok(json) => match self.import_json(&json).await {
                Ok(count) => tracing::info!("Loaded {} documents from {}", count, path.display()),
                Err(e) => tracing::warn!("Failed to load vector engine: {}", e),
            },
            Err(e) => tracing::warn!("Failed to read vector engine file: {}", e),
        }
    }

    /// Exporta todos los documentos a JSON para persistencia.
    pub async fn export_json(&self) -> Result<String> {
        let docs = self.docs.read().await;
        let entries: Vec<serde_json::Value> = docs
            .iter()
            .map(|d| {
                serde_json::json!({
                    "content": d.content,
                    "metadata": d.metadata,
                    "embedding": d.embedding,
                })
            })
            .collect();
        serde_json::to_string_pretty(&entries).map_err(|e| crate::error::NanoError::Internal {
            message: e.to_string(),
        })
    }

    /// Importa documentos desde JSON.
    pub async fn import_json(&self, json: &str) -> Result<usize> {
        let entries: Vec<serde_json::Value> =
            serde_json::from_str(json).map_err(|e| crate::error::NanoError::Internal {
                message: e.to_string(),
            })?;
        let mut docs = self.docs.write().await;
        for entry in &entries {
            let content = entry["content"].as_str().unwrap_or("").to_string();
            let metadata = entry["metadata"].clone();
            let embedding: Option<Vec<f32>> = entry["embedding"].as_array().map(|a| {
                a.iter()
                    .filter_map(|v| v.as_f64().map(|f| f as f32))
                    .collect()
            });
            if let Some(ref emb) = embedding {
                *self.embed_dim.write().await = Some(emb.len());
            }
            docs.push(IndexedDoc {
                content,
                metadata,
                embedding,
            });
        }
        Ok(entries.len())
    }
}

/// Similitud coseno entre dos vectores.
pub fn cosine_similarity(a: &[f32], b: &[f32]) -> f32 {
    if a.len() != b.len() || a.is_empty() {
        return 0.0;
    }
    let dot: f32 = a.iter().zip(b.iter()).map(|(x, y)| x * y).sum();
    let na: f32 = a.iter().map(|x| x * x).sum();
    let nb: f32 = b.iter().map(|x| x * x).sum();
    let d = (na * nb).sqrt();
    if d == 0.0 {
        0.0
    } else {
        (dot / d).clamp(0.0, 1.0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::manifest::Config;

    /// Cleans up the persisted file to avoid cross-test contamination.
    fn clean_persist(cfg: &Config) {
        let path = std::path::Path::new(&cfg.memory.vector_db_path).with_extension("json");
        let _ = std::fs::remove_file(&path);
    }

    #[tokio::test]
    async fn test_keyword_search() {
        let cfg = Config::test_config();
        clean_persist(&cfg);
        let e = VectorEngine::new(&cfg).await.unwrap();
        e.index_document("NanoAI hybrid Rust", serde_json::json!({}), None)
            .await
            .unwrap();
        let r = e.search("NanoAI Rust", 5, None).await.unwrap();
        assert!(!r.is_empty());
    }

    #[tokio::test]
    async fn test_semantic_search() {
        let cfg = Config::test_config();
        clean_persist(&cfg);
        let e = VectorEngine::new(&cfg).await.unwrap();
        e.index_document(
            "Rust language",
            serde_json::json!({"s":"r"}),
            Some(vec![1.0, 0.0, 0.0]),
        )
        .await
        .unwrap();
        e.index_document(
            "Python language",
            serde_json::json!({"s":"p"}),
            Some(vec![0.0, 1.0, 0.0]),
        )
        .await
        .unwrap();
        let r = e.search("Rust", 5, Some(&[0.9, 0.1, 0.0])).await.unwrap();
        assert!(!r.is_empty());
        assert!(r[0].similarity > 0.9);
    }

    #[tokio::test]
    async fn test_export_import() {
        let cfg = Config::test_config();
        clean_persist(&cfg);
        let e = VectorEngine::new(&cfg).await.unwrap();
        e.index_document("test", serde_json::json!({"k":"v"}), Some(vec![1.0, 2.0]))
            .await
            .unwrap();
        let json = e.export_json().await.unwrap();

        clean_persist(&cfg); // Clean persist so new instance is empty
        let e2 = VectorEngine::new(&cfg).await.unwrap();
        let count = e2.import_json(&json).await.unwrap();
        assert_eq!(count, 1);
        assert_eq!(e2.document_count().await, 1);
    }

    #[tokio::test]
    async fn test_clear() {
        let cfg = Config::test_config();
        clean_persist(&cfg);
        let e = VectorEngine::new(&cfg).await.unwrap();
        e.index_document("test", serde_json::json!({}), None)
            .await
            .unwrap();
        assert_eq!(e.document_count().await, 1);
        e.clear().await.unwrap();
        assert_eq!(e.document_count().await, 0);
    }

    #[test]
    fn test_cosine_similarity() {
        assert!((cosine_similarity(&[1.0, 0.0], &[1.0, 0.0]) - 1.0).abs() < 0.001);
        assert!((cosine_similarity(&[1.0, 0.0], &[0.0, 1.0]) - 0.0).abs() < 0.001);
    }

    #[tokio::test]
    async fn test_persistence() {
        // Use a unique temp dir to avoid race conditions with parallel tests
        let dir = tempfile::tempdir().unwrap();
        let persist_path = dir.path().join("vectors.json");
        let mut cfg = Config::test_config();
        cfg.memory.vector_db_path = persist_path.to_string_lossy().to_string();

        let e = VectorEngine::new(&cfg).await.unwrap();
        e.index_document("persist test", serde_json::json!({"k":"v"}), None)
            .await
            .unwrap();
        e.flush().await.unwrap(); // ensure save happens before checking disk
        assert!(
            persist_path.exists(),
            "Persist file should exist after flush"
        );

        let e2 = VectorEngine::new(&cfg).await.unwrap();
        assert_eq!(e2.document_count().await, 1, "Should load 1 doc from disk");
    }
}
