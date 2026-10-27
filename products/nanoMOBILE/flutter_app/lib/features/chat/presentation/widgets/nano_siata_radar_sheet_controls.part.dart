part of 'nano_siata_radar_sheet.dart';

extension _NanoSiataRadarSheetControls on _NanoSiataRadarSheetState {
  Widget _buildHeader(BuildContext context, bool isDark, dynamic colors) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.radar_rounded, color: Color(0xFF38BDF8), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Radar SIATA · Visor Meteorológico',
                    style: TextStyle(
                      color: isDark ? Colors.white : colors.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _locationShared
                        ? 'GPS activo · Selección de capas'
                        : 'Estilo iOS · Zoom libre y capas 360°',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : colors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: 'Ventana Flotante iOS',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.picture_in_picture_alt_rounded),
                iconSize: 20,
                onPressed: _detachToFloatingWindow,
              ),
            ),
            Semantics(
              label: 'Recargar',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded),
                iconSize: 20,
                onPressed: () => _controller?.reload(),
              ),
            ),
          ],
        ),
      );

  Widget _buildLayerSelector(bool isDark) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Row(
      children: SiataLayer.values.map((l) {
        final active = _selectedLayer == l;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () => _selectLayer(l),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.25)
                    : (isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? const Color(0xFF38BDF8) : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.icon, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Text(
                    l.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? const Color(0xFF38BDF8)
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );

  Widget _buildFloatingZoomHud(bool isDark, dynamic colors) => Positioned(
    bottom: 16,
    right: 14,
    child: Container(
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(
          alpha: 0.78,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'Acercar',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.add_rounded, size: 20),
              onPressed: _zoomIn,
            ),
          ),
          Container(
            width: 24,
            height: 1,
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
          Semantics(
            label: 'Alejar',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.remove_rounded, size: 20),
              onPressed: _zoomOut,
            ),
          ),
          Container(
            width: 24,
            height: 1,
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
          Semantics(
            label: 'Mi Ubicación',
            button: true,
            child: IconButton(
              icon: Icon(
                Icons.my_location_rounded,
                size: 18,
                color: _locationShared ? const Color(0xFF38BDF8) : null,
              ),
              onPressed: _locateUser,
            ),
          ),
        ],
      ),
    ),
  );
}
