part of 'whatsapp_qr_scanner_dialog.dart';

extension _WhatsAppQrScannerDialogView on _WhatsAppQrScannerDialogState {
  Widget _buildQrScannerContent(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_scanner, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vinculación en Mismo Teléfono',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _fetchNativeScreenshot,
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<WhatsAppWebSessionInfo>(
            stream: whatsAppWebBridgeController.sessionStream,
            initialData: whatsAppWebBridgeController.currentSession,
            builder: (context, snapshot) {
              final qrUrl = snapshot.data?.qrDataUrl;
              final bytes = (qrUrl != null && qrUrl.contains(','))
                  ? base64Decode(qrUrl.split(',').last)
                  : (_domQrBytes ?? _screenshotBytes);
              if (bytes != null && bytes.isNotEmpty) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.green.shade400,
                        width: 2,
                      ),
                    ),
                    child: Image.memory(
                      bytes,
                      width: 180,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              }
              return Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    Text(
                      _isCapturing ? 'Escaneando…' : 'Cargando QR…',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_decodedQrText != null && _decodedQrText!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'QR: $_decodedQrText',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copiar Código de 8 Dígitos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: _copyPairingCode,
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            icon: const Icon(Icons.center_focus_strong, color: Colors.blue),
            label: const Text('Escanear QR con Google Lens'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: _openGoogleLens,
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Compartir QR a Galería'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: _shareQrImage,
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            icon: const Icon(Icons.launch),
            label: const Text('Abrir WhatsApp para Vincular'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: _openWhatsAppLinkedDevices,
          ),
        ],
      ),
    );
  }
}
