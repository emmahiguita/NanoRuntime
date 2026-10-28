import test from 'node:test';
import assert from 'node:assert/strict';
import { AgentService, agentService } from '../ui/js/features/automation/agent_service.js';
import { registerTool } from '../ui/js/features/automation/tool_registry.js';
import { renderTask, renderHistory } from '../ui/js/features/automation/automation_presenter.js';
import { validateAgentInput } from '../ui/js/features/automation/automation_modals.js';
agentService.stopDaemon();
const memory=new Map();
globalThis.localStorage={getItem:key=>memory.get(key)??null,setItem:(key,value)=>memory.set(key,value)};
const services=[];
function service(){memory.clear();const s=new AgentService();s.stopDaemon();services.push(s);return s;}
function task(s,options={}){return s.createAgent({name:'Task',role:'Read a value',tools:['Audit Read'],governance:'approval',...options});}
let executions=0;
registerTool('Audit Read',{type:'READ_ONLY',execute:async()=>{executions++;return {summary:'Read',output:'Measured result'};}});

test('new schedule is paused and has no invented execution',()=>{
  const s=service(); const a=task(s,{trigger:'Cada 1 minuto'});
  assert.equal(a.status,'paused');assert.equal(a.executions,0);assert.equal(s.logs[0].status,'configured');
});
test('request and reject approval never call a tool',async()=>{
  const s=service(),a=task(s);const before=executions;
  const log=await s.executeAgent(a.id,true);assert.equal(log.status,'pending');assert.equal(executions,before);
  s.rejectAction(log.id);assert.equal(log.status,'cancelled');assert.equal(a.executions,0);assert.equal(executions,before);
});
test('double approval starts a single execution with a visible running record',async()=>{
  let finish; let calls=0;
  registerTool('Audit Deferred',{type:'READ_ONLY',execute:()=>{calls++;return new Promise(resolve=>{finish=resolve;});}});
  const s=service(),a=task(s,{tools:['Audit Deferred']});
  const log=await s.executeAgent(a.id);const execution=s.approveAction(log.id);
  assert.equal(s.running.has(a.id),true);assert.equal(log.status,'approving');
  await s.approveAction(log.id);assert.equal(calls,1);
  s.clearLogs();assert.ok(s.logs.includes(log));
  finish({summary:'Read',output:'Real tool output'});await execution;
  assert.equal(log.status,'ok');assert.equal(a.successCount,1);assert.equal(s.running.size,0);
  assert.ok(log.finishedAt>=log.startedAt);assert.equal(log.output,'Real tool output');
});
test('direct execution is recorded before a slow tool completes',async()=>{
  let finish;
  registerTool('Audit Slow',{execute:()=>new Promise(resolve=>{finish=resolve;})});
  const s=service(),a=task(s,{tools:['Audit Slow'],governance:'autonomous'});
  const execution=s.executeAgent(a.id);assert.equal(s.logs[0].status,'running');
  const output=renderTask(a,s);assert.ok(output.includes('activity-spinner'));assert.ok(output.includes('Cancelar espera'));
  finish({summary:'Done',output:'value'});await execution;assert.equal(s.logs[0].status,'ok');
});
test('cancellation is recorded without claiming native inference stopped',async()=>{
  let finish;
  registerTool('Audit Cancellable',{execute:()=>new Promise(resolve=>{finish=resolve;})});
  const s=service(),a=task(s,{tools:['Audit Cancellable'],governance:'autonomous'});
  const execution=s.executeAgent(a.id);assert.equal(s.cancelExecution(a.id),true);
  assert.ok(renderTask(a,s).includes('Cancelando espera'));
  finish({summary:'Read',output:'value'});const log=await execution;
  assert.equal(log.status,'cancelled');assert.equal(a.successCount,0);assert.equal(a.cancelledCount,1);
});
test('unavailable tools are rejected before an approval or execution is created',async()=>{
  const s=service();assert.throws(()=>task(s,{tools:['Terminal Sandbox']}),/Sin conexión/);
  const legacy=s._normalizeAgent({id:'legacy',name:'Old',role:'Old task',tools:['Unknown Tool'],status:'paused'});s.agents.push(legacy);
  const count=s.logs.length;await assert.rejects(s.executeAgent('legacy'),/Sin conexión/);assert.equal(s.logs.length,count);
  assert.ok(renderTask(legacy,s).includes('Requiere configuración'));
});
test('failed durable start cannot invoke any tools',async()=>{
  const s=service(),a=task(s,{governance:'autonomous'});const before=executions;
  s._saveLogs=()=>false;await assert.rejects(s.executeAgent(a.id),/no se ejecutó/);
  assert.equal(executions,before);assert.equal(s.running.size,0);
});
test('failed status persistence rolls back activation',()=>{
  const s=service(),a=task(s,{trigger:'Cada 5 minutos'});s._saveAgents=()=>false;
  assert.throws(()=>s.toggleAgentStatus(a.id),/No se pudo guardar/);assert.equal(a.status,'paused');
});
test('editing cancels stale plans and retains execution counters',async()=>{
  const s=service(),a=task(s);a.executions=4;a.successCount=3;a.errorCount=1;
  const log=await s.executeAgent(a.id);
  const edited=s.updateAgent(a.id,{name:'Changed',role:'New goal',tools:['Audit Read'],trigger:'Cada 5 minutos',governance:'approval'});
  assert.equal(edited.executions,4);assert.equal(edited.status,'paused');assert.equal(log.status,'cancelled');
  assert.equal(await s.approveAction(log.id),null);
});
test('archive and restore are reversible and block archived execution',async()=>{
  const s=service(),a=task(s);s.archiveAgent(a.id);assert.equal(a.status,'archived');
  await assert.rejects(s.executeAgent(a.id),/Restaura/);
  s.archiveAgent(a.id,false);assert.equal(a.status,'paused');assert.equal(s.agents.length,1);
});
test('rendering escapes task text and exposes results as text',()=>{
  const s=service(),a=task(s,{name:'<img src=x>',role:'<script>alert(1)</script>'});
  assert.ok(!renderTask(a,s).includes('<img src=x>'));assert.ok(renderTask(a,s).includes('&lt;img'));
  const html=renderHistory({id:'r',status:'ok',agentName:'Task',timestamp:Date.now(),output:'<script>bad</script>',duration:'12ms'});
  assert.ok(html.includes('&lt;script&gt;'));assert.ok(html.includes('Ver resultado'));assert.ok(!html.includes('activity-spinner'));
});
test('non-string input validation returns errors rather than crashing',()=>{
  assert.equal(validateAgentInput({name:42,role:[]}).isValid,false);
});
test.after(()=>services.forEach(s=>s.stopDaemon()));
import { runAgentTools } from '../ui/js/features/automation/agent_executor.js';
test('model synthesis receives the observations from earlier tools',async()=>{
  let prompt='';
  const result=await runAgentTools({name:'Summarize',role:'Explain observed memory',tools:['Hardware Watcher','LLM Fallback'],model:'fixture.gguf'},{
    getSystemStatus:async()=>({used_ram_mb:2048,total_ram_mb:8192}),
    generateText:async options=>{prompt=options.prompt;return {text:'Observed summary'};},
  });
  assert.ok(prompt.includes('RAM medida: 2048 MB de 8192 MB'));
  assert.ok(prompt.includes('Explain observed memory'));
  assert.equal(result.status,'ok');
});
test('scheduler runs only active interval tasks and respects pause',async()=>{
  const s=service(),a=task(s,{trigger:'Cada 1 minuto',governance:'autonomous'});
  let tick;const original=globalThis.setInterval;
  globalThis.setInterval=(callback,ms)=>{tick=callback;return original(()=>{},ms);};
  try{s.startDaemon();}finally{globalThis.setInterval=original;}
  const before=executions;
  await tick();assert.equal(executions,before);
  s.toggleAgentStatus(a.id);await tick();assert.equal(executions,before+1);
  assert.equal(s.logs[0].status,'ok');
  s.toggleAgentStatus(a.id);a.lastRunTimestamp=0;await tick();assert.equal(executions,before+1);
  s.stopDaemon();
});
