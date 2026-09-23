/**
 * @file owl_physics.js
 * @description Motor de físicas procedimentales y animación 3D por resorte (Spring-Damper).
 * 
 * Qué hace: Calcula cinemática inversa, respiración orgánica y seguimiento tridimensional del cursor.
 * Cómo funciona: Usa integración Euler semiexplícita con resortes amortiguados en un bucle RAF limpio.
 * Por qué: Garantiza movimiento orgánico no lineal, libre de procesos zombi mediante control de ciclo de vida.
 */

import { OWL_PHYSICS_CONFIG as CFG } from './owl_config.js';

export class OwlPhysicsEngine {
  constructor(domElements) {
    this.els = domElements;
    this.rafId = null;
    this.lastTime = 0;

    // Coordenadas normalizadas (-1.0 a +1.0)
    this.mouse = { x: 0, y: 0, targetX: 0, targetY: 0 };
    
    // Rotaciones angulares con velocidad para física de resorte
    this.rotX = { current: 0, target: 0, vel: 0 };
    this.rotY = { current: 0, target: 0, vel: 0 };
    this.rotZ = { current: 0, target: 0, vel: 0 };

    // Micro-sacadas oculares
    this.eye = { x: 0, y: 0, saccadeX: 0, saccadeY: 0 };

    // Modificadores de estado
    this.isSleeping = false;
    this.isThinking = false;
    this.isHovered = false;
  }

  start() {
    this.stop();
    this.lastTime = performance.now();
    const tick = (now) => {
      this.update(now);
      this.rafId = requestAnimationFrame(tick);
    };
    this.rafId = requestAnimationFrame(tick);
  }

  stop() {
    if (this.rafId) {
      cancelAnimationFrame(this.rafId);
      this.rafId = null;
    }
  }

  updateMouse(normX, normY) {
    this.mouse.targetX = Math.max(-1.1, Math.min(1.1, normX));
    this.mouse.targetY = Math.max(-1.1, Math.min(1.1, normY));
  }

  resetMouse() {
    this.mouse.targetX = 0;
    this.mouse.targetY = 0;
    this.isHovered = false;
  }

  update(now) {
    if (!this.els.stage) return;
    const dt = Math.min((now - this.lastTime) / 1000, 0.05);
    this.lastTime = now;
    const t = now * 0.001;

    // 1. Interpolación suave del cursor (LERP)
    this.mouse.x += (this.mouse.targetX - this.mouse.x) * CFG.mouseLerp;
    this.mouse.y += (this.mouse.targetY - this.mouse.y) * CFG.mouseLerp;

    // 2. Curva de respiración orgánica (Squash & Stretch)
    const bSpeed = this.isSleeping ? CFG.sleepBreathSpeed : (this.isThinking ? 2.2 : CFG.breathSpeed);
    const bAmp = this.isSleeping ? CFG.sleepBreathAmp : CFG.breathAmp;
    const breathPhase = Math.sin(t * bSpeed);
    const breathCurve = breathPhase * 0.7 + Math.sin(t * bSpeed * 2) * 0.3;
    const squashX = 1.0 - breathCurve * (bAmp * 0.6);
    const stretchY = 1.0 + breathCurve * bAmp;
    const liftY = -breathCurve * (this.isSleeping ? 1.2 : 2.4);

    // 3. Balanceo natural de apoyo (pie a pie)
    const swayAngle = Math.sin(t * 0.45) * (this.isSleeping ? 0.5 : 1.4);
    const swayX = Math.sin(t * 0.45) * 1.2;

    // 4. Integración de resortes angulares (Spring-Damper)
    const targetY = this.mouse.x * (this.isSleeping ? 3 : (this.isThinking ? 10 : CFG.maxYaw));
    const targetX = -this.mouse.y * (this.isSleeping ? 2 : (this.isThinking ? 7 : CFG.maxPitch));
    const targetZ = swayAngle - (targetY - this.rotY.current) * 0.16;

    const fX = (targetX - this.rotX.current) * CFG.springK - this.rotX.vel * CFG.damper;
    const fY = (targetY - this.rotY.current) * CFG.springK - this.rotY.vel * CFG.damper;
    const fZ = (targetZ - this.rotZ.current) * CFG.springK - this.rotZ.vel * CFG.damper;

    this.rotX.vel += fX * dt;
    this.rotY.vel += fY * dt;
    this.rotZ.vel += fZ * dt;

    this.rotX.current += this.rotX.vel * dt;
    this.rotY.current += this.rotY.vel * dt;
    this.rotZ.current += this.rotZ.vel * dt;

    // 5. Aplicar transformaciones al stage interno
    const hoverOffset = this.isHovered ? -4 : 0;
    this.els.stage.style.transform = `
      translate3d(${swayX.toFixed(2)}px, ${(liftY + hoverOffset).toFixed(2)}px, ${this.isHovered ? 12 : 0}px)
      rotateX(${this.rotX.current.toFixed(2)}deg)
      rotateY(${this.rotY.current.toFixed(2)}deg)
      rotateZ(${this.rotZ.current.toFixed(2)}deg)
      scale3d(${squashX.toFixed(3)}, ${stretchY.toFixed(3)}, 1)
    `;

    // 6. Sombra de contacto
    if (this.els.shadow) {
      const shadowX = -this.rotY.current * 1.35;
      const sScale = (1.0 + breathCurve * 0.04) * (this.isHovered ? 0.90 : 1.0);
      const sOpacity = this.isSleeping ? 0.42 : (0.34 - breathCurve * 0.06);
      this.els.shadow.style.transform = `translateX(calc(-50% + ${shadowX.toFixed(1)}px)) rotateX(75deg) scale(${sScale.toFixed(2)})`;
      this.els.shadow.style.opacity = sOpacity.toFixed(2);
    }

    // 7. Reflejos pupilares galácticos
    if (this.els.eyesGleam) {
      this.eye.x += ((this.mouse.x * 6.5 + this.eye.saccadeX) - this.eye.x) * 0.12;
      this.eye.y += ((this.mouse.y * 4.8 + this.eye.saccadeY) - this.eye.y) * 0.12;
      this.els.eyesGleam.style.transform = `translate3d(${this.eye.x.toFixed(1)}px, ${this.eye.y.toFixed(1)}px, 28px)`;
      this.els.eyesGleam.style.opacity = this.isSleeping ? '0' : '1';
    }

    // 8. Luz especular volumétrica
    if (this.els.rimLight) {
      const lx = 50 + this.mouse.x * 38;
      const ly = 38 + this.mouse.y * 38;
      const intensity = this.isHovered ? 0.52 : 0.38;
      this.els.rimLight.style.background = `radial-gradient(circle at ${lx.toFixed(1)}% ${ly.toFixed(1)}%, rgba(255, 255, 255, ${intensity}) 0%, rgba(129, 140, 248, ${(intensity * 0.45).toFixed(2)}) 32%, transparent 66%)`;
    }

    // 9. Polvo cósmico y halo
    if (this.els.stardust) {
      this.els.stardust.style.transform = `translate3d(${(-this.mouse.x * 10).toFixed(1)}px, ${(-this.mouse.y * 8).toFixed(1)}px, 10px)`;
    }
    if (this.els.halo) {
      this.els.halo.style.transform = `translate(calc(-50% + ${(-this.mouse.x * 14).toFixed(1)}px), calc(-50% + ${(-this.mouse.y * 12).toFixed(1)}px)) translateZ(-45px)`;
    }
  }
}
