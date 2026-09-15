import { transport } from '../../core/transport.js';
import { appState } from '../../core/state.js';

export class SystemService {
  async refreshTelemetry() {
    try {
      const telemetry = await transport.getSystemStatus();
      appState.setState({ telemetry });
    } catch (err) {
      console.error('Error obteniendo telemetría:', err);
    }
  }

  async loadModels() {
    try {
      const models = await transport.listModels();
      appState.setState({ models });
    } catch (err) {
      console.error('Error cargando modelos:', err);
    }
  }
}

export const systemService = new SystemService();
