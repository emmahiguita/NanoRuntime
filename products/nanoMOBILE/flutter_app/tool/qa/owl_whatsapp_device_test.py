"""Prueba real de Búho: requiere WhatsApp abierto en el chat propio verificado.

Ejecutar con el Python de ARTEMIS y --send-self para autorizar un único mensaje.
Usa su helper de accesibilidad, nunca UiAutomation que desconecta a Nano.
"""
import argparse
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

sys.path.insert(0, os.environ.get('ARTEMIS_ROOT', str(Path.home() / 'artemis')))
from artemis.clients.accessibility_client import AccessibilityClient

ADB = str(Path.home() / 'AppData/Local/Android/sdk/platform-tools/adb.exe')
ROOT = Path(__file__).resolve().parents[2]


def caption(node):
    """Flutter publica etiquetas en content-desc; Android puede usar text."""
    return node.get('text') or node.get('content-desc') or ''


class OwlDeviceTest:
    """Posee observación y pasos de una sola prueba; no reintenta envíos."""
    def __init__(self, serial, message):
        self.serial, self.message = serial, message
        self.helper = AccessibilityClient(serial, provision_on_connect=False)
        self.helper.connect()
        self.steps = []

    def adb(self, *args):
        """Invoca argumentos literales, sin shell ni interpolación de mensajes."""
        return subprocess.run([ADB, '-s', self.serial, *args], check=True,
                              capture_output=True, timeout=20).stdout

    def nodes(self):
        """Obtiene el árbol del helper sin suprimir servicios de accesibilidad."""
        return list(ET.fromstring(self.helper.get_hierarchy()).iter('node'))

    def wait(self, predicate, seconds=15):
        """Espera una condición observable con límite; el tiempo no acredita éxito."""
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            value = predicate()
            if value:
                return value
            time.sleep(.25)
        raise AssertionError('No se observó la condición esperada antes del límite')

    def own_chat(self):
        """Exige la indicación explícita de número propio, no un nombre de contacto."""
        return any(n.get('package') == 'com.whatsapp' and
                   'Envía mensajes a este mismo número' in
                   (n.get('text', '') + n.get('content-desc', '')) for n in self.nodes())

    def tap(self, label, fallback=None):
        """Busca etiqueta exacta; solo usa coordenadas exploradas si no hay nodo."""
        last, since, hits = None, time.monotonic(), []
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            hits = [n for n in self.nodes() if label in
                    (n.get('text', ''), n.get('content-desc', ''))]
            current = hits[-1].get('bounds') if hits else None
            if current != last:
                last, since = current, time.monotonic()
            elif current and time.monotonic() - since >= .6:
                break
            time.sleep(.15)
        if hits:
            values = list(map(int, re.findall(r'\d+', hits[-1].get('bounds', ''))))
            if len(values) != 4:
                raise AssertionError('Control sin límites válidos')
            x, y = (values[0] + values[2]) // 2, (values[1] + values[3]) // 2
        elif fallback:
            size = re.findall(rb'(\d+)x(\d+)', self.adb('shell', 'wm', 'size'))[-1]
            x = int(fallback[0] * int(size[0]) / 1080)
            y = int(fallback[1] * int(size[1]) / 2400)
        else:
            raise AssertionError('No se encontró el control: ' + label)
        self.adb('shell', 'input', 'tap', str(x), str(y))
        self.steps.append('tap:' + label)

    def panel(self):
        """Abre el mismo botón flotante; admite un panel ya abierto sin perder texto."""
        if not any(n.get('package') == 'dev.nanoai.mobile' and
                   'EditText' in n.get('class', '') for n in self.nodes()):
            self.wait(lambda: any(caption(n) == 'Asistente Nano sobre otras apps' for n in self.nodes()))
            self.tap('Asistente Nano sobre otras apps', (129, 751))
        self.wait(lambda: any(caption(n) == 'Búho AI' for n in self.nodes()))
        if any(caption(n) == 'Conversar' for n in self.nodes()):
            self.tap('Conversar')
            self.wait(lambda: any(caption(n) == 'WhatsApp' for n in self.nodes()))
            self.tap('WhatsApp')

    def command(self, text):
        """Escribe únicamente en el editor de Nano; no escribe ni envía por WhatsApp."""
        def ready_fields():
            candidates = [n for n in self.nodes() if n.get('package') == 'dev.nanoai.mobile'
                          and 'EditText' in n.get('class', '')]
            return candidates if len(candidates) == 1 else None
        fields = self.wait(ready_fields)
        old = fields[0].get('text', '')
        assert old in ('', 'Confirmar acción') or old.startswith('Responde a este chat: PRUEBA NANO'), 'Borrador ajeno en Nano'
        bounds = list(map(int, re.findall(r'\d+', fields[0].get('bounds', ''))))
        assert len(bounds) == 4
        self.adb('shell', 'input', 'tap', str((bounds[0] + bounds[2]) // 2),
                 str((bounds[1] + bounds[3]) // 2))
        if old:
            self.adb('shell', 'input', 'keycombination', '113', '29')
            self.adb('shell', 'input', 'keyevent', '67')
            self.wait(lambda: any(n.get('package') == 'dev.nanoai.mobile' and
                      'EditText' in n.get('class', '') and not n.get('text') for n in self.nodes()))
        assert self.helper.send_text(text), 'No se introdujo la orden en Nano'
        self.wait(lambda: any(n.get('text') == text for n in self.nodes()))
        self.tap('Ejecutar')

    def outcome(self, after):
        """Lee solo la bitácora de acciones; jamás interpreta el cierre como envío."""
        db = sqlite3.connect(':memory:')
        try:
            db.deserialize(self.adb('exec-out', 'run-as', 'dev.nanoai.mobile',
                                    'cat', 'databases/nano_automation_store.db'))
            row = db.execute('select data from store_sections where section_key=?',
                             ('automation_action_history_v1',)).fetchone()
            events = json.loads(row[0]) if row else []
            return next((e for e in reversed(events) if e.get('atMs', 0) >= after and
                         e.get('state') not in ('call', 'running')), None)
        except sqlite3.DatabaseError:
            return None  # Una copia durante escritura no es un resultado de la acción.
        finally:
            db.close()

    def run(self):
        """Un envío mediante Búho, confirmación si corresponde y eco local exacto."""
        assert self.own_chat(), 'Abre primero el chat de tu propio número'
        assert not any(n.get('text') == self.message for n in self.nodes()), 'Marcador ya existente'
        self.panel()
        start = int(time.time() * 1000)
        self.command('Responde a este chat: ' + self.message)
        result = self.wait(lambda: self.outcome(start), 25)
        if result['state'] == 'paused':
            assert self.own_chat(), 'Cambió el destino antes de confirmar'
            self.panel()
            # Reemplaza únicamente la orden de prueba ya introducida por este script.
            fields = [n for n in self.nodes() if n.get('package') == 'dev.nanoai.mobile'
                      and 'EditText' in n.get('class', '')]
            assert len(fields) == 1
            self.tap(fields[0].get('text') or 'Abre el chat de Emm…', (465, 1548))
            self.adb('shell', 'input', 'keycombination', '113', '29')
            self.adb('shell', 'input', 'keyevent', '67')
            self.wait(lambda: any(n.get('package') == 'dev.nanoai.mobile' and
                      'EditText' in n.get('class', '') and not n.get('text') for n in self.nodes()))
            assert self.helper.send_text('Confirmar acción')
            self.wait(lambda: any(n.get('text') == 'Confirmar acción' for n in self.nodes()))
            start = int(time.time() * 1000)
            self.tap('Ejecutar')
            result = self.wait(lambda: self.outcome(start), 30)
        assert result['state'] in ('completed', 'completedUnverified'), result.get('detail')
        self.adb('shell', 'monkey', '-p', 'com.whatsapp', '-c', 'android.intent.category.LAUNCHER', '1')
        self.wait(self.own_chat)
        self.wait(lambda: sum(n.get('text') == self.message for n in self.nodes()) == 1)
        return {'passed': True, 'state': result['state'], 'localEchoCount': 1,
                'steps': self.steps, 'deliveryConfirmed': False}


def main():
    """Requiere consentimiento por ejecución; guarda evidencia incluso si falla."""
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--serial', required=True)
    p.add_argument('--message', required=True)
    p.add_argument('--send-self', action='store_true')
    args = p.parse_args()
    assert args.send_self and args.message.startswith('PRUEBA NANO'), 'Autoriza un mensaje de prueba propio'
    report = ROOT / 'build/owl-whatsapp-e2e-result.json'
    test = OwlDeviceTest(args.serial, args.message)
    try:
        result = test.run()
    except Exception as error:
        result = {'passed': False, 'reason': str(error), 'steps': test.steps,
                  'retrySend': False}
    report.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding='utf8')
    print(json.dumps(result, ensure_ascii=True))
    raise SystemExit(0 if result['passed'] else 1)


if __name__ == '__main__':
    main()
