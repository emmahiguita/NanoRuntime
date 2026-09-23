import 'dart:io';
import 'package:path_provider/path_provider.dart';

// business_gamification_service.dart
//
// QUÉ HACE:
// Genera y administra la micro-web HTML5 del mini-juego de Ruleta de Descuentos
// para promociones comerciales gamificadas dentro del In-App Browser de WhatsApp.
//
// CÓMO FUNCIONA:
// - Genera un documento HTML5/CSS/JS autónomo (< 15 KB, sin librerías pesadas).
// - Al ganar un premio, el botón "Canjear en WhatsApp" invoca wa.me con el código de descuento.
// - Guarda el archivo localmente para ser servido o desplegado.
//
// POR QUÉ:
// Permite a cualquier negocio ofrecer experiencias interactivas gamificadas en WhatsApp,
// incrementando la conversión de ventas sin necesidad de desarrollo web externo (< 200 líneas).

class BusinessGamificationService {
  /// Genera el texto del mensaje comercial con invitación al mini-juego.
  static String buildInviteMessage({
    required String businessName,
    required String gameUrl,
  }) {
    return '🎉 *¡Ruleta de la Suerte en $businessName!* 🎁\n\n'
        'Gira nuestra ruleta y gana descuentos exclusivos o envíos gratis para tu pedido de hoy.\n\n'
        '👉 *Toca aquí para jugar:* $gameUrl\n\n'
        '_Válido para compras hoy. ¡Mucha suerte!_';
  }

  /// Genera y guarda el archivo HTML5 standalone de la ruleta de descuentos.
  static Future<File> generateGameHtmlFile({
    required String businessName,
    required String whatsappNumber,
  }) async {
    final cleanPhone = whatsappNumber.replaceAll(RegExp(r'[^\d]'), '');
    final html = _buildHtmlTemplate(businessName, cleanPhone);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ruleta_descuentos.html');
    await file.writeAsString(html, flush: true);
    return file;
  }

  static String _buildHtmlTemplate(String businessName, String phone) {
    return '''<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Ruleta de Descuentos - $businessName</title>
<style>
body { font-family: -apple-system, sans-serif; background: #0b141a; color: #e9edef; display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 16px; box-sizing: border-box; }
h1 { font-size: 20px; color: #25d366; margin-bottom: 6px; text-align: center; }
p { font-size: 13px; color: #8696a0; margin-bottom: 20px; text-align: center; }
.wheel-box { position: relative; width: 280px; height: 280px; margin-bottom: 24px; }
canvas { width: 100%; height: 100%; border-radius: 50%; box-shadow: 0 4px 20px rgba(0,0,0,0.5); }
.pointer { position: absolute; top: -10px; left: 50%; transform: translateX(-50%); width: 0; height: 0; border-left: 14px solid transparent; border-right: 14px solid transparent; border-top: 24px solid #ff3b30; z-index: 10; }
button { background: #25d366; color: #0b141a; font-weight: bold; border: none; padding: 14px 28px; border-radius: 24px; font-size: 15px; cursor: pointer; transition: transform 0.2s; }
button:active { transform: scale(0.96); }
.modal { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.8); align-items: center; justify-content: center; z-index: 100; }
.modal-content { background: #1f2c34; padding: 24px; border-radius: 16px; text-align: center; max-width: 290px; }
.claim-btn { display: inline-block; background: #25d366; color: #0b141a; text-decoration: none; padding: 12px 20px; border-radius: 20px; font-weight: bold; margin-top: 14px; }
</style>
</head>
<body>
<h1>$businessName</h1>
<p>Gira la ruleta y reclama tu premio en WhatsApp</p>
<div class="wheel-box"><div class="pointer"></div><canvas id="w" width="500" height="500"></canvas></div>
<button id="spinBtn" onclick="spin()">¡GIRAR RULETA!</button>
<div id="m" class="modal"><div class="modal-content">
<h2>🎉 ¡FELICIDADES! 🎉</h2>
<p id="prizeText" style="font-size: 16px; color: #fff;"></p>
<a id="claimLink" class="claim-btn" href="#">Canjear en WhatsApp</a>
</div></div>
<script>
const prizes = ["5% DCTO", "ENVÍO GRATIS", "10% DCTO", "REGALO SORPRESA", "15% DCTO", "CUPÓN VIP"];
const colors = ["#00a884", "#128c7e", "#25d366", "#075e54", "#202c33", "#2a3942"];
const c = document.getElementById("w"), ctx = c.getContext("2d");
let angle = 0, spinning = false;
function draw() {
  const arc = (2 * Math.PI) / prizes.length;
  for(let i=0; i<prizes.length; i++) {
    ctx.beginPath(); ctx.fillStyle = colors[i];
    ctx.moveTo(250, 250); ctx.arc(250, 250, 240, i*arc, (i+1)*arc); ctx.fill();
    ctx.save(); ctx.translate(250, 250); ctx.rotate((i + 0.5) * arc);
    ctx.fillStyle = "#fff"; ctx.font = "bold 20px sans-serif"; ctx.textAlign = "right";
    ctx.fillText(prizes[i], 220, 8); ctx.restore();
  }
}
draw();
function spin() {
  if (spinning) return;
  spinning = true; document.getElementById("spinBtn").disabled = true;
  const turns = 5 + Math.random() * 5;
  const totalRot = turns * 2 * Math.PI;
  const start = performance.now();
  function animate(now) {
    const p = Math.min((now - start) / 4000, 1);
    const ease = 1 - Math.pow(1 - p, 3);
    const cur = totalRot * ease;
    ctx.save(); ctx.clearRect(0,0,500,500); ctx.translate(250,250); ctx.rotate(cur); ctx.translate(-250,-250); draw(); ctx.restore();
    if (p < 1) requestAnimationFrame(animate);
    else {
      const actual = (cur + (Math.PI / 2)) % (2 * Math.PI);
      const arc = (2 * Math.PI) / prizes.length;
      const idx = Math.floor((2 * Math.PI - actual) / arc) % prizes.length;
      const won = prizes[idx];
      document.getElementById("prizeText").innerText = "Ganaste: " + won;
      const text = encodeURIComponent("¡Hola! Acabo de girar la ruleta y gané: " + won + ". Deseo aplicarlo a mi compra.");
      document.getElementById("claimLink").href = "https://wa.me/$phone?text=" + text;
      document.getElementById("m").style.display = "flex";
    }
  }
  requestAnimationFrame(animate);
}
</script></body></html>''';
  }
}
