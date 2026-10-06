/// Puente idempotente entre HTMLMediaElement y los controles Android.
/// Escucha eventos reales y limita timeupdate; no crea intervalos por carga.
abstract final class BrowserMediaScript {
  static const sync = r'''
  (() => {
    if (window.__nanoMediaBridge) return;
    let current = null, lastUpdate = 0;
    const ids = new WeakMap();
    let nextId = 0;
    const button = action => Array.from(document.querySelectorAll(
      action === 'next' ? '.ytp-next-button' : '.ytp-prev-button'
    )).find(b => !b.disabled && b.getAttribute('aria-disabled') !== 'true'
      && b.getClientRects().length);
    // Prefiere el medio que suena; conserva el pausado para reanudarlo.
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
    // Actúa solo sobre el elemento observado, sin arrancar todos los videos.
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
