//! Router híbrido entre tiers de inferencia.
//!
//! Decide si una petición se procesa localmente (Tier 1),
//! en LAN (Tier 2) o en la nube (Tier 3), basado en:
//! - Detección de PII (fuerza Tier 1)
//! - Entropía de la respuesta local (baja entropía = alta confianza)

use crate::config::manifest::Config;
use crate::error::Result;
use crate::orchestrator::privacy;

/// Decisión de routing para una petición.
#[derive(Debug, Clone)]
pub enum RoutingDecision {
    /// Procesar localmente en Tier 1.
    Local,
    /// Procesar en servidor LAN (Tier 2).
    Lan(String),
    /// Procesar en la nube con contexto anonimizado.
    Cloud(String),
}

/// Router que decide el tier óptimo para cada petición.
pub struct Router {
    config: Config,
}

impl Router {
    /// Crea un nuevo router con la configuración proporcionada.
    pub fn new(config: Config) -> Self {
        Self { config }
    }

    /// Decide el tier para procesar una petición.
    ///
    /// Orden de preferencia:
    /// 1. PII detectado → siempre Local (nunca enviar PII fuera)
    /// 2. edge_only → siempre Local
    /// 3. Tier 3 habilitado → Cloud (confianza se evalúa post-generación)
    /// 4. Tier 2 habilitado → LAN
    /// 5. Default → Local
    pub async fn route(
        &self,
        prompt: &str,
    ) -> Result<RoutingDecision> {
        // Check PII: force local unconditionally
        if self.config.hybrid_routing.privacy_filter && privacy::contains_pii(prompt) {
            tracing::info!("PII detected — forcing Local (Tier 1)");
            return Ok(RoutingDecision::Local);
        }

        // Edge-only mode: bypass all external tiers
        if self.config.hybrid_routing.edge_only {
            tracing::debug!("Edge-only mode — forcing Local (Tier 1)");
            return Ok(RoutingDecision::Local);
        }

        // Tier 3 (cloud): confidence check happens post-generation in execute_local_with_escalation
        if self.config.hybrid_routing.enabled && self.config.tiers.tier3.enabled {
            tracing::debug!("Tier 3 cloud available — will escalate post-generation if confidence low");
            return Ok(RoutingDecision::Local);
        }

        // Tier 2 (LAN): use when tier3 is off but tier2 is on
        if self.config.hybrid_routing.enabled && self.config.tiers.tier2.enabled {
            let endpoint = self.config.tiers.tier2.endpoint.clone();
            tracing::info!("Routing to LAN tier: {}", endpoint);
            return Ok(RoutingDecision::Lan(endpoint));
        }

        // Default: local
        Ok(RoutingDecision::Local)
    }
}

#[cfg(test)]
#[cfg(feature = "simulated")]
mod tests {
    use super::*;
    use crate::config::manifest::Config;

    fn test_config() -> Config {
        Config::test_config()
    }

    fn test_config_with_cloud() -> Config {
        let mut config = Config::test_config();
        config.tiers.tier3.enabled = true;
        std::env::set_var("NANO_API_KEY", "test-key");
        config
    }

    fn test_config_with_lan() -> Config {
        let mut config = Config::test_config();
        config.tiers.tier2.enabled = true;
        config.tiers.tier2.endpoint = "http://192.168.1.100:11434".to_string();
        config.hybrid_routing.enabled = true;
        config
    }

    #[tokio::test]
    async fn test_route_local_default() {
        let config = test_config();
        let router = Router::new(config);
        let decision = router.route("¿Qué hora es?").await.unwrap();
        assert!(matches!(decision, RoutingDecision::Local));
    }

    #[tokio::test]
    async fn test_route_local_with_pii() {
        let config = test_config_with_cloud();
        let router = Router::new(config);
        let decision = router
            .route("Envía un email a juan@ejemplo.com con mi tarjeta 4111-1111-1111-1111")
            .await
            .unwrap();
        // PII must always force Local, even with cloud available
        assert!(matches!(decision, RoutingDecision::Local));
    }

    #[tokio::test]
    async fn test_route_edge_only_overrides_cloud() {
        let mut config = test_config_with_cloud();
        config.hybrid_routing.edge_only = true;
        let router = Router::new(config);
        let decision = router.route("¿Qué hora es?").await.unwrap();
        assert!(matches!(decision, RoutingDecision::Local));
    }

    #[tokio::test]
    async fn test_route_edge_only_overrides_lan() {
        let mut config = test_config_with_lan();
        config.hybrid_routing.edge_only = true;
        let router = Router::new(config);
        let decision = router.route("¿Qué hora es?").await.unwrap();
        // edge_only must override LAN too
        assert!(matches!(decision, RoutingDecision::Local));
    }

    #[tokio::test]
    async fn test_route_cloud_defers_to_local_first() {
        let config = test_config_with_cloud();
        let router = Router::new(config);
        let decision = router.route("Explica la teoría de la relatividad").await.unwrap();
        // Cloud escalation happens post-generation — router returns Local first
        assert!(matches!(decision, RoutingDecision::Local));
    }

    #[tokio::test]
    async fn test_route_lan_activated_when_tier2_enabled() {
        let config = test_config_with_lan();
        let router = Router::new(config);
        let decision = router.route("¿Qué hora es?").await.unwrap();
        // Should route to LAN when tier2 enabled and tier3 disabled
        assert!(matches!(decision, RoutingDecision::Lan(_)));
        if let RoutingDecision::Lan(ep) = decision {
            assert!(ep.contains("192.168.1.100"), "LAN endpoint should be the configured IP");
        }
    }

    #[tokio::test]
    async fn test_route_lan_pii_still_forces_local() {
        let config = test_config_with_lan();
        let router = Router::new(config);
        // Even with LAN enabled, PII must stay local
        let decision = router
            .route("Mi SSN es 123-45-6789")
            .await
            .unwrap();
        assert!(matches!(decision, RoutingDecision::Local));
    }

    #[tokio::test]
    async fn test_route_tier3_takes_priority_over_tier2() {
        let mut config = test_config_with_lan();
        config.tiers.tier3.enabled = true;
        let router = Router::new(config);
        // When both tier2 and tier3 are enabled, tier3 path takes priority
        // (router returns Local — escalation happens post-generation)
        let decision = router.route("Hola").await.unwrap();
        assert!(matches!(decision, RoutingDecision::Local));
    }
}
