"""Regression tests: real HTTP boundary, mocked inference (no model/credential access)."""
import http.client
import json
import os
from pathlib import Path
import sys
import threading
import unittest
from unittest.mock import patch
import socketserver

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dev_server import ProxyAndStaticHandler
import local_model_routes as routes
from request_access import check_access, validate_bind
from types import SimpleNamespace


class BridgeStub:
    def __init__(self):
        self.calls = []
        self.activated = []
        self.deactivated = 0
    def status(self):
        return {'model_path': 'real.gguf', 'model_loaded': True, 'status': 'running'}
    def activate(self, model_id):
        self.activated.append(model_id)
        return {'selected': {'path': model_id}, 'runtime': {'model_path': model_id, 'model_loaded': True}}
    def deactivate(self):
        self.deactivated += 1
        return {'unloaded': True, 'runtime': {'model_path': None, 'model_loaded': False, 'status': 'offline'}}
    def chat(self, data):
        self.calls.append(data)
        return {'response': 'Respuesta española', 'model': data.get('model', 'real.gguf')}


class QuietHandler(ProxyAndStaticHandler):
    def log_message(self, *args):
        pass


class HttpContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = socketserver.ThreadingTCPServer(('127.0.0.1', 0), QuietHandler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()
    def setUp(self):
        self.bridge = BridgeStub()
        self.stub = patch.object(routes, 'bridge', self.bridge)
        self.stub.start()
    def tearDown(self):
        self.stub.stop()
    def request(self, path, data=None, headers=None, method=None):
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_address[1], timeout=4)
        request_headers = {'Content-Type': 'application/json', **(headers or {})}
        connection.request(method or ('POST' if data is not None else 'GET'), path,
                           json.dumps(data) if data is not None else None, request_headers)
        response = connection.getresponse()
        result = response.status, dict(response.getheaders()), response.read().decode()
        connection.close()
        return result
    def test_mobile_nonstream_no_invented_speed(self):
        status, _, body = self.request('/completion', {'prompt': 'hola', 'request_id': 'r1'})
        self.assertEqual(status, 200)
        self.assertIsNone(json.loads(body)['timings']['predicted_per_second'])
        self.assertEqual(self.bridge.calls[0]['session_id'], 'r1')
    def test_mobile_buffered_sse_and_context(self):
        status, headers, body = self.request('/completion', {'prompt': 'hola', 'session_id': 'a',
            'context': 'Contexto', 'history': [{'role': 'user', 'content': 'antes'}], 'stream': True})
        self.assertEqual(status, 200)
        self.assertIn('text/event-stream', headers['Content-Type'])
        frame = json.loads(body.removeprefix('data: ').strip())
        self.assertTrue(frame['stop'])
        self.assertTrue(frame['buffered'])
        self.assertEqual(self.bridge.calls[0]['context'], 'Contexto')
        self.assertEqual(len(self.bridge.calls[0]['history']), 1)
    def test_mobile_can_select_specific_desktop_model(self):
        status, _, body = self.request('/completion', {
            'prompt': 'usa modelo grande', 'request_id': 'r2', 'model': 'custom-large.gguf'
        })
        self.assertEqual(status, 200)
        self.assertEqual(self.bridge.activated, ['custom-large.gguf'])
        self.assertEqual(json.loads(body)['model'], 'custom-large.gguf')
    def test_mobile_viability_assessment(self):
        status, _, body = self.request('/api/viability', {'model_size_bytes': 1_100_000_000})
        self.assertEqual(status, 200)
        payload = json.loads(body)
        self.assertIn(payload['tier'], ('OPTIMAL', 'VIABLE', 'TIGHT', 'INSUFFICIENT', 'UNKNOWN'))
        self.assertIsInstance(payload['can_run'], bool)
        self.assertIsInstance(payload['should_run_interactive'], bool)
        self.assertEqual(self.request('/api/viability', {'model_size_bytes': -1})[0], 422)
    def test_openai_v1_models_and_chat_completions(self):
        with patch.object(routes, 'installed_models', return_value=[{
            'id': 'qwen', 'name': 'qwen.gguf', 'path': 'real.gguf', 'size_mb': 1024, 'size_bytes': 1073741824
        }]):
            status, _, body = self.request('/v1/models')
            self.assertEqual(status, 200)
            models = json.loads(body)['data']
            self.assertEqual(len(models), 1)
            self.assertTrue(models[0]['selected'])
        status, _, body = self.request('/v1/chat/completions', {
            'model': 'real.gguf',
            'messages': [
                {'role': 'system', 'content': 'Sé preciso'},
                {'role': 'user', 'content': 'Hola desde Mobile'},
            ],
            'max_tokens': 128,
            'temperature': 0.5,
        })
        self.assertEqual(status, 200)
        data = json.loads(body)
        self.assertEqual(data['object'], 'chat.completion')
        self.assertEqual(data['choices'][0]['message']['content'], 'Respuesta española')
        self.assertEqual(self.bridge.calls[0]['context'], 'Sé preciso')
    def test_compatible_requests_without_session_are_isolated(self):
        for _ in range(2):
            status, _, _ = self.request('/v1/chat/completions', {
                'model': 'real.gguf', 'user': 'same-person',
                'messages': [{'role': 'user', 'content': 'Hola'}]})
            self.assertEqual(status, 200)
        self.assertNotEqual(self.bridge.calls[0]['session_id'], self.bridge.calls[1]['session_id'])

    def test_invalid_inputs_never_infer(self):
        for extra in [{'n_predict': True}, {'n_predict': '512'}, {'n_predict': 5000},
                      {'history': 'bad'}, {'prompt': []}, {'temperature': float('nan')},
                      {'stream': 'true'}, {'session_id': 123}, {'context': []}]:
            with self.subTest(extra=extra):
                status, _, _ = self.request('/completion', {'prompt': 'hola', 'session_id': 'a', **extra})
                self.assertEqual(status, 422)
        self.assertFalse(self.bridge.calls)
    def test_requires_conversation_identity(self):
        self.assertEqual(self.request('/completion', {'prompt': 'hola'})[0], 422)
    def test_cancel_does_not_claim_success(self):
        status, _, body = self.request('/cancel', {'request_id': 'a'})
        self.assertEqual(status, 501)
        self.assertFalse(json.loads(body)['cancelled'])
    def test_health_reports_limits(self):
        status, _, body = self.request('/health')
        self.assertEqual(status, 200)
        self.assertIn('"status":"ok"', body)
        caps = json.loads(body)['capabilities']
        self.assertFalse(caps['cancellation'])
        self.assertTrue(caps['viability'])
        self.assertTrue(caps['openai_v1'])
    def test_external_browser_cannot_use_any_route(self):
        for path in ['/health', '/', '/api/other', '/completion']:
            self.assertEqual(self.request(path, headers={'Origin': 'https://evil.example'})[0], 403)
        self.assertEqual(self.request('/health', headers={'Host': 'evil.example:3001'})[0], 403)
    def test_same_origin_allowed_cross_port_denied(self):
        port = self.server.server_address[1]
        self.assertEqual(self.request('/health', headers={'Origin': f'http://127.0.0.1:{port}'})[0], 200)
        self.assertEqual(self.request('/health', headers={'Origin': 'http://127.0.0.1:9999'})[0], 403)
    def test_status_does_not_scan_disk(self):
        with patch.object(routes, 'installed_models', side_effect=AssertionError('unneeded scan')):
            self.assertEqual(self.request('/api/status')[0], 200)
    def test_deactivate_model_endpoint(self):
        status, _, body = self.request('/api/local-models/deactivate', {})
        self.assertEqual(status, 200)
        self.assertTrue(json.loads(body)['unloaded'])
        self.assertEqual(self.bridge.deactivated, 1)


class LanBoundary(unittest.TestCase):
    def handler(self, headers):
        return SimpleNamespace(headers={'Host': '192.168.1.2:3001', **headers},
            client_address=('192.168.1.3', 1234), server=SimpleNamespace(server_address=('0.0.0.0', 3001)))
    def test_lan_requires_key(self):
        with patch.dict(os.environ, {'NANO_API_KEY': 'x' * 32}):
            self.assertEqual(check_access(self.handler({})), 401)
            self.assertEqual(check_access(self.handler({'Authorization': 'Bearer wrong'})), 401)
            self.assertIsNone(check_access(self.handler({'Authorization': 'Bearer ' + 'x' * 32})))
            self.assertIsNone(check_access(self.handler({'X-Nano-API-Key': 'x' * 32})))
    def test_lan_bind_fails_closed(self):
        with patch.dict(os.environ, {'NANO_API_KEY': ''}):
            with self.assertRaises(ValueError):
                validate_bind('0.0.0.0')
            validate_bind('127.0.0.1')


if __name__ == '__main__':
    unittest.main()
