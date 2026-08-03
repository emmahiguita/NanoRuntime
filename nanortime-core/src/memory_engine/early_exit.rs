//! Early Exiting Controller
//! Módulo que controla el mecanismo de salida temprana (Early Exiting)
//! analizando la entropía y la confianza de las predicciones intermedias.

#[derive(Debug, Clone)]
pub struct EarlyExitController {
    /// Umbral mínimo de confianza (0.0 - 1.0) para permitir la salida temprana.
    pub confidence_threshold: f32,
    /// Capa mínima requerida antes de considerar una salida temprana.
    pub min_layer: usize,
    /// Penalización para salir muy temprano.
    pub layer_penalty_factor: f32,
}

impl Default for EarlyExitController {
    fn default() -> Self {
        Self {
            confidence_threshold: 0.95, // Por defecto, requerir alta confianza.
            min_layer: 8,               // Al menos evaluar el 25% del modelo (si n_layers=32).
            layer_penalty_factor: 0.02, // Penalizar salidas muy tempranas.
        }
    }
}

impl EarlyExitController {
    pub fn new(confidence_threshold: f32, min_layer: usize) -> Self {
        Self {
            confidence_threshold,
            min_layer,
            layer_penalty_factor: 0.02,
        }
    }

    /// Evalúa si el modelo debería abortar las capas restantes.
    ///
    /// `intermediate_logits`: Logits generados en la capa actual.
    /// `current_layer`: Índice de la capa actual (0-indexed).
    /// `total_layers`: Número total de capas del modelo.
    ///
    /// Retorna `true` si la confianza supera el umbral dinámico ajustado por capa.
    pub fn should_exit_early(
        &self,
        intermediate_logits: &[f32],
        current_layer: usize,
        total_layers: usize,
    ) -> bool {
        // No permitir salir antes de la capa mínima.
        if current_layer < self.min_layer {
            return false;
        }

        // Si ya estamos en la última capa, no tiene sentido "salir temprano"
        if current_layer >= total_layers - 1 {
            return false;
        }

        let confidence = Self::calculate_confidence(intermediate_logits);
        
        // Ajuste dinámico: requerimos mayor confianza en las primeras capas.
        // Penalty = factor * (capas restantes)
        let layers_remaining = total_layers - current_layer - 1;
        let dynamic_threshold = self.confidence_threshold + (layers_remaining as f32 * self.layer_penalty_factor);
        
        let dynamic_threshold = dynamic_threshold.min(0.99); // Cap

        confidence > dynamic_threshold
    }

    /// Simulación heurística de la confianza basada en los logits.
    /// Extrae la probabilidad de softmax del top-1 respecto al top-2.
    pub fn calculate_confidence(logits: &[f32]) -> f32 {
        if logits.is_empty() {
            return 0.0;
        }

        let mut max1 = f32::NEG_INFINITY;
        let mut max2 = f32::NEG_INFINITY;

        for &l in logits {
            if l > max1 {
                max2 = max1;
                max1 = l;
            } else if l > max2 {
                max2 = l;
            }
        }

        if max1 == f32::NEG_INFINITY {
            return 0.0;
        }
        
        if max2 == f32::NEG_INFINITY {
            return 1.0;
        }

        // Softmax-like difference
        let diff = max1 - max2;
        // Logistic function para mapear diferencia a [0, 1]
        1.0 / (1.0 + (-diff).exp())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_early_exit_low_layer() {
        let controller = EarlyExitController::new(0.90, 16);
        let logits = vec![10.0, 0.1, 0.2]; // Alta confianza
        // No debería salir porque capa actual < min_layer
        assert!(!controller.should_exit_early(&logits, 10, 32));
    }

    #[test]
    fn test_early_exit_high_confidence() {
        let controller = EarlyExitController::new(0.90, 8);
        let logits = vec![15.0, 0.1, -2.0]; // Diferencia muy alta = alta confianza
        // Está más allá de min_layer (8), así que evalúa la confianza.
        assert!(controller.should_exit_early(&logits, 20, 32));
    }

    #[test]
    fn test_early_exit_low_confidence() {
        let controller = EarlyExitController::new(0.90, 8);
        let logits = vec![5.1, 5.0, 4.9]; // Diferencia muy baja = baja confianza
        assert!(!controller.should_exit_early(&logits, 20, 32));
    }

    #[test]
    fn test_calculate_confidence() {
        let conf_high = EarlyExitController::calculate_confidence(&[10.0, 1.0, 0.5]);
        let conf_low = EarlyExitController::calculate_confidence(&[5.1, 5.0, 4.9]);
        
        assert!(conf_high > 0.9);
        assert!(conf_low < 0.6);
    }
}
