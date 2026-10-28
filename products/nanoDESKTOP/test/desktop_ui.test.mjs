import test from 'node:test';
import assert from 'node:assert/strict';
import { renderLogRow } from '../ui/js/features/automation/automation_log_row.js';
import { ChatComposer } from '../ui/js/features/chat/chat_composer.js';
import { ChatView } from '../ui/js/features/chat/chat_view.js';
import { readPreferences, savePreferences } from '../ui/js/core/preferences.js';
import { ensureActiveLocalModel, deactivateLocalModel } from '../ui/js/core/local_model_api.js';
import { buildFunctionalPrompt } from '../ui/js/features/chat/chat_intent_router.js';

const memory = new Map();
test('cancelled and running agent logs are not presented as errors or emojis', () => {
  for (const [status, label] of [['cancelled', 'Cancelada'], ['approving', 'En curso']]) {
    const html = renderLogRow({id:'x',status,action:'run',time:'now',agentName:'a'});
    assert.ok(html.includes(label));
    assert.ok(html.includes('<svg'));
    assert.ok(!html.includes('badge-error'));
  }
});
globalThis.localStorage = { getItem: (key) => memory.get(key) ?? null, setItem: (key, value) => memory.set(key, value) };

test('preferences validate and persist chat output limit', () => {
  assert.equal(readPreferences().maxTokens, 512);
  savePreferences({ maxTokens: 2048 });
  assert.equal(readPreferences().maxTokens, 2048);
  assert.throws(() => savePreferences({ maxTokens: 99999 }));
});

test('composer does not steal focus on telemetry or token updates', () => {
  let focus = 0;
  const composer = { input: { disabled: false, focus() { focus++; } }, submitBtn: { disabled: false } };
  ChatComposer.prototype.setDisabled.call(composer, false);
  assert.equal(focus, 0);
  ChatComposer.prototype.setDisabled.call(composer, true);
  assert.equal(composer.submitBtn.disabled, true);
  ChatComposer.prototype.setDisabled.call(composer, false);
  assert.equal(focus, 1);
});

class Node {
  constructor() { this.style = {}; this.children = []; this.writes = 0; this.clientHeight = 400; this.scrollHeight = 500; this.scrollTop = 100; }
  set innerHTML(value) { this.html = value; this.writes++; }
  querySelectorAll() { return []; }
  appendChild(node) { this.children.push(node); }
  replaceChildren() { this.children = []; }
  remove() {}
}

test('chat preserves old message nodes and rerenders only changed tokens', () => {
  globalThis.document = { createElement: () => new Node() };
  const view = Object.create(ChatView.prototype);
  view.messagesEl = new Node(); view.isHomeMode = false;
  view.composer = { setDisabled() {} };
  const messages = [{ id: 'u', role: 'user', text: 'Pregunta' }, { id: 'a', role: 'assistant', text: 'Respuesta', meta: { isStreaming: true } }];
  const state = { currentSessionId: 's', messages, isGenerating: true };
  view.render(state);
  const user = view.renderedMessages.get('u').node;
  const assistant = view.renderedMessages.get('a').node;
  view.render({ ...state, telemetry: { used_ram_mb: 4 } });
  assert.equal(user.writes, 1);
  assert.equal(assistant.writes, 1);
  messages[1].text += ' adicional';
  view.render(state);
  assert.equal(user.writes, 1);
  assert.equal(assistant.writes, 2);
  assert.equal(view.messagesEl.children.length, 2);
});

test('invalid saved messages are preserved without overwriting storage', async () => {
  globalThis.window = { localStorage };
  const corrupt = '[{"id":"s","title":"x","messages":[{"role":"user","text":{}}]}]';
  localStorage.setItem('nano_desktop_sessions_v2', corrupt);
  const { readSessions, writeSessions } = await import('../ui/js/core/session_persistence.js?isolated-audit');
  assert.deepEqual(readSessions(), []);
  writeSessions([]);
  assert.equal(localStorage.getItem('nano_desktop_sessions_v2'), corrupt);
});

test('chat view pauses and resumes hero avatar when switching views', () => {
  let paused = 0;
  let resumed = 0;
  const view = Object.create(ChatView.prototype);
  view.heroView = { owlAvatar: { pause() { paused++; }, resume() { resumed++; } } };
  view.setVisible(false);
  assert.equal(paused, 1);
  assert.equal(resumed, 0);
  view.setVisible(true);
  assert.equal(paused, 1);
  assert.equal(resumed, 1);
});

test('ensureActiveLocalModel auto-selects and activates first GGUF model and deactivateLocalModel unloads it', async () => {
  let activatedPath = '';
  let deactivated = false;
  globalThis.window = {
    localStorage,
    __TAURI__: {
      core: {
        invoke: async (cmd, args) => {
          if (cmd === 'nano_activate_model') { activatedPath = args.model; return { status: 'loaded' }; }
          if (cmd === 'nano_deactivate_model') { deactivated = true; return { status: 'unloaded' }; }
          return [];
        },
      },
    },
  };
  const client = {
    isTauri: true,
    selectedModelPath: '',
    listModels: async () => [{ name: 'qwen.gguf', path: 'C:/models/qwen.gguf', is_loaded: false }],
  };
  const resolved = await ensureActiveLocalModel(client);
  assert.equal(resolved, 'C:/models/qwen.gguf');
  assert.equal(activatedPath, 'C:/models/qwen.gguf');
  assert.equal(client.selectedModelPath, 'C:/models/qwen.gguf');

  await deactivateLocalModel(client);
  assert.equal(deactivated, true);
  assert.equal(client.selectedModelPath, '');

  const enriched = buildFunctionalPrompt('¿Cuáles son tus funciones en Nano?');
  assert.match(enriched, /Contexto verificado de NanoAI Studio Desktop/);
  const { agentService } = await import('../ui/js/features/automation/agent_service.js');
  agentService.stopDaemon();
});
