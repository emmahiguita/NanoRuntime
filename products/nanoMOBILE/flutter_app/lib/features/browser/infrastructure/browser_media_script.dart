/// QUÉ HACE:
/// Puente idempotente entre HTMLMediaElement, la Page Visibility API y los controles Android.
///
/// CÓMO FUNCIONA:
/// Simula que el documento siempre está visible (`document.hidden = false`, `visibilityState = 'visible'`)
/// e intercepta `visibilitychange` y `blur` para que reproductores como YouTube o Spotify Web
/// continúen reproduciéndose en segundo plano o con la pantalla apagada fuera de Nano.
/// Sincroniza metadatos reales y maneja comandos nativos de audio (`play`, `pause`, `seek`, `next`).
///
/// POR QUÉ:
/// Permite escuchar música web en segundo plano sin cortes y mantiene el archivo < 120 líneas (SOLID).
abstract final class BrowserMediaScript {
  static const sync = r'''
  (() => {
    if (window.__nanoMediaBridge) return;

    // 1. Simulación de visibilidad: impide que YouTube pause al salir de la app
    try {
      Object.defineProperty(document, 'hidden', { get: () => false, configurable: true });
      Object.defineProperty(document, 'visibilityState', { get: () => 'visible', configurable: true });
      Object.defineProperty(document, 'webkitVisibilityState', { get: () => 'visible', configurable: true });
    } catch (_) {}

    const stopVis = e => { if (e) { e.stopImmediatePropagation(); } };
    window.addEventListener('visibilitychange', stopVis, true);
    document.addEventListener('visibilitychange', stopVis, true);
    window.addEventListener('webkitvisibilitychange', stopVis, true);
    document.addEventListener('webkitvisibilitychange', stopVis, true);
    window.addEventListener('blur', stopVis, true);

    let current = null, lastUpdate = 0;
    const ids = new WeakMap();
    let nextId = 0;
    const button = action => Array.from(document.querySelectorAll(
      action === 'next' ? '.ytp-next-button' : '.ytp-prev-button'
    )).find(b => !b.disabled && b.getAttribute('aria-disabled') !== 'true'
      && b.getClientRects().length);

    function selected() {
      const all = Array.from(document.querySelectorAll('video,audio'));
      return all.find(m => !m.paused && !m.ended && !m.muted)
        || (current?.isConnected ? current : null);
    }

    function report() {
      const m = selected();
      current = m;
      if (!window.flutter_inappwebview?.callHandler) return;
      const metadata = navigator.mediaSession?.metadata;
      if (m && !ids.has(m)) ids.set(m, ++nextId);
      window.flutter_inappwebview.callHandler('audioState', {
        present: !!m, ended: !!m?.ended, mediaId: m ? ids.get(m) : '',
        playing: !!m && !m.paused && !m.ended,
        buffering: !!m && m.readyState < 3,
        title: metadata?.title || document.title,
        artist: metadata?.artist || location.hostname,
        artwork: metadata?.artwork?.[0]?.src || null,
        duration: Number.isFinite(m?.duration) ? m.duration : 0,
        position: Number.isFinite(m?.currentTime) ? m.currentTime : 0,
        speed: m?.playbackRate || 1,
        next: !!button('next'), previous: !!button('previous')
      }).catch(() => {});
    }

    async function command(action, position) {
      const m = selected();
      if (!m) { report(); return false; }
      try {
        if (action === 'play') await m.play();
        else if (action === 'pause') m.pause();
        else if (action === 'seek' && Number.isFinite(m.duration))
          m.currentTime = Math.max(0, Math.min(position, m.duration));
        else if (action === 'next' || action === 'previous') button(action)?.click();
        report();
        return true;
      } catch (_) { report(); return false; }
    }

    if (navigator.mediaSession) {
      try {
        navigator.mediaSession.setActionHandler('play', () => command('play'));
        navigator.mediaSession.setActionHandler('pause', () => command('pause'));
        navigator.mediaSession.setActionHandler('seekto', d => command('seek', d.seekTime));
        navigator.mediaSession.setActionHandler('previoustrack', () => command('previous'));
        navigator.mediaSession.setActionHandler('nexttrack', () => command('next'));
      } catch (_) {}
    }

    window.__nanoMediaBridge = {command, report};
    const events = ['play', 'playing', 'pause', 'ended', 'emptied', 'waiting',
      'loadedmetadata', 'durationchange', 'seeked', 'ratechange', 'volumechange'];
    for (const event of events) document.addEventListener(event, e => {
      if (!(e.target instanceof HTMLMediaElement)) return;
      if (event === 'play') current = e.target;
      report();
    }, true);
    document.addEventListener('timeupdate', () => {
      if (Date.now() - lastUpdate < 5000) return;
      lastUpdate = Date.now();
      report();
    }, true);
    window.addEventListener('flutterInAppWebViewPlatformReady', report);
    document.addEventListener('DOMContentLoaded', report, {once:true});
  })();
  ''';
}
