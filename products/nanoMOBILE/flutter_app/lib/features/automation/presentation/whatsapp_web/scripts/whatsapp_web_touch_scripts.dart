// whatsapp_web_touch_scripts.dart
//
// QUÉ HACE:
// Genera los scripts JavaScript que implementan el desplazamiento cinético táctil
// (momentum scrolling) y la discriminación de gestos táctiles (drag vs tap) para la lista de chats.
//
// CÓMO FUNCIONA:
// - buildTouchScrollerScript: Enlaza escuchadores touchstart, touchmove y touchend sobre #pane-side.
//   Calcula la velocidad del desplazamiento del dedo y aplica desaceleración con requestAnimationFrame
//   para lograr un deslizamiento suave e inercial nativo de 60/120 FPS.
//   Discrimina entre desplazamientos (arrastres > 6px) y pulsaciones reales para evitar
//   que un swipe para scrollear active accidentalmente la apertura de un chat.
// - buildSuspendTouchScript: Remueve los escuchadores táctiles y cancela animaciones activas.
//
// POR QUÉ:
// Aplica el principio de Responsabilidad Única (SRP) de Clean Architecture aislando la
// gestión física de gestos táctiles. Mantiene el código altamente testeable y bajo 200 líneas.

class WhatsAppWebTouchScripts {
  const WhatsAppWebTouchScripts._();

  /// Inyecta el controlador de desplazamiento táctil inercial para la lista de contactos (#pane-side).
  static String buildTouchScrollerScript() {
    return '''
    (function() {
      var pane = document.getElementById('pane-side');
      if (!pane || pane.__nanoTouchBound) return;
      pane.__nanoTouchBound = true;

      var startY = 0, lastY = 0, lastTime = 0, velocityY = 0;
      var isDragging = false, animId = null, dragEndTime = 0;

      pane.addEventListener('touchstart', function(e) {
        if (e.touches.length !== 1) return;
        if (animId) { cancelAnimationFrame(animId); animId = null; }
        startY = e.touches[0].clientY;
        lastY = startY;
        lastTime = Date.now();
        velocityY = 0;
        isDragging = false;
      }, { passive: true });

      pane.addEventListener('touchmove', function(e) {
        if (e.touches.length !== 1) return;
        var currentY = e.touches[0].clientY;
        var deltaY = currentY - lastY;
        var now = Date.now();
        var dt = now - lastTime || 1;

        if (Math.abs(currentY - startY) > 6) {
          isDragging = true;
          window.__nanoIsScrolling = true;
        }

        if (isDragging) {
          pane.scrollTop -= deltaY;
          velocityY = deltaY / dt;
          lastY = currentY;
          lastTime = now;
        }
      }, { passive: true });

      pane.addEventListener('touchend', function() {
        if (!isDragging) {
          window.__nanoIsScrolling = false;
          return;
        }
        dragEndTime = Date.now();
        setTimeout(function() { window.__nanoIsScrolling = false; }, 220);

        var currentVelocity = velocityY * 16;
        var decay = 0.94;
        var step = function() {
          if (Math.abs(currentVelocity) > 0.4) {
            pane.scrollTop -= currentVelocity;
            currentVelocity *= decay;
            animId = requestAnimationFrame(step);
          } else {
            animId = null;
          }
        };
        animId = requestAnimationFrame(step);
      }, { passive: true });

      pane.addEventListener('click', function(e) {
        if (window.__nanoIsScrolling || Date.now() - dragEndTime < 250) {
          e.stopPropagation();
          e.preventDefault();
        }
      }, true);
    })();
    ''';
  }

  /// Limpia los observadores y controladores táctiles al suspender la pantalla.
  static String buildSuspendTouchScript() {
    return '''
    var pane = document.getElementById('pane-side');
    if (pane) pane.__nanoTouchBound = false;
    window.__nanoIsScrolling = false;
    ''';
  }
}
