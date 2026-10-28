import { escapeHtml as esc } from '../../core/utils.js';
const labels={available:'Disponible',queued:'En cola',downloading:'Descargando',verifying:'Verificando integridad',stopping:'Deteniendo',paused:'Detenida',error:'Error',installed:'Descargado · sin prueba en Nano'};
const gb=n=>(n/1e9).toFixed(2)+' GB';
export function renderLibrary(data) {
  return data.models.map(m=>{
    const d=m.download, active=['queued','downloading','verifying','stopping'].includes(d.state);
    const main=m.files.find(f=>f.role==='model');
    return `<article class="library-row"><div><h4>${esc(m.title)}</h4><p>${esc(m.use)}</p>
      <p class="library-specs">${esc(m.parameters)} · ${esc(m.quantization)} · ${gb(main.size)} pesos · ${gb(m.total_bytes)} paquete</p>
      <p class="library-support">${esc(m.capability_note)}</p>
      <details><summary>Fuente y archivos</summary><p>Origen: <a href="https://huggingface.co/${esc(m.origin)}" target="_blank" rel="noopener noreferrer">${esc(m.origin)}</a> · GGUF: <a href="https://huggingface.co/${esc(m.repo)}" target="_blank" rel="noopener noreferrer">${esc(m.repo)}</a></p><p>Licencia: ${esc(m.license)} · Revisión: ${esc(m.revision.slice(0,12))}</p><ul>${m.files.map(f=>`<li>${esc(f.filename)} · ${gb(f.size)}</li>`).join('')}</ul><p>Descarga fijada a esta revisión y verificada con SHA-256. Los auxiliares no aparecen como modelos de chat.</p></details>
      ${active || d.state==='paused' ? `<progress max="${m.total_bytes}" value="${d.bytes}" aria-label="Descarga ${esc(m.title)}"></progress><p class="library-specs">${gb(d.bytes)} de ${gb(m.total_bytes)}${d.file ? ' · '+esc(d.file) : ''}</p>`:''}
      ${d.error ? `<p class="library-error" role="alert">${esc(d.error)}</p>`:''}
      </div><div class="library-actions"><span role="status">${esc(labels[d.state] || d.state)}</span>
      ${active ? `<button type="button" data-library="pause" data-id="${esc(m.id)}" ${d.state==='stopping'?'disabled':''}>Detener descarga</button>` : m.installed ? '' : `<button type="button" data-library="start" data-id="${esc(m.id)}">${['paused','error'].includes(d.state)?'Reanudar descarga':'Descargar paquete'}</button>`}
      </div></article>`;
  }).join('');
}

export class ModelLibraryView {
  constructor(container,onInstalled=()=>{}) {
    this.container=container;this.onInstalled=onInstalled;this.completed=new Set();this.abort=new AbortController();
    container.innerHTML=`<div class="library-header"><div><h3>Catálogo 2026</h3><p>Pesos y auxiliares de los cuatro modelos seleccionados. Descargar no habilita automáticamente la multimodalidad.</p></div><button type="button" data-library="refresh">Actualizar fuentes</button></div><p class="library-feedback" role="status"></p><div class="library-list">Consultando catálogo…</div>`;
    container.addEventListener('click',async e=>{
      const button=e.target.closest('button[data-library]');if(!button || this.busy)return;
      this.busy=true;button.disabled=true;
      const feedback=container.querySelector('.library-feedback');feedback.textContent=button.dataset.library==='refresh'?'Consultando repositorios de origen…':'';
      try {const data=await this.request('/'+button.dataset.library,{id:button.dataset.id});if(!this.destroyed){feedback.textContent=button.dataset.library==='refresh'?'Fuentes actualizadas. Los archivos instalados no se reemplazan automáticamente.':'';this.render(data);}}
      catch(error){if(!this.destroyed)feedback.textContent=error.message;}
      finally{this.busy=false;if(!this.destroyed)button.disabled=false;}
    },{signal:this.abort.signal});
    this.refresh();this.timer=setInterval(()=>{if(!document.hidden && container.getClientRects().length)this.refresh();},2000);
  }
  async request(path='',body) {
    const response=await fetch('/api/model-library'+path,{method:body?'POST':'GET',headers:body?{'Content-Type':'application/json'}:undefined,body:body?JSON.stringify(body):undefined,signal:AbortSignal.any([this.abort.signal,AbortSignal.timeout(path==='/refresh'?90000:10000)])});
    if(!response.headers.get('content-type')?.includes('application/json'))throw Error('El servidor debe reiniciarse para habilitar el catálogo de descargas.');
    const data=await response.json();if(!response.ok)throw Error(data.error || 'No se pudo consultar el catálogo.');return data;
  }
  async refresh(){if(this.loading || this.busy || this.destroyed)return;this.loading=true;try{this.render(await this.request());}catch(error){if(!this.destroyed)this.container.querySelector('.library-feedback').textContent=error.message;}finally{this.loading=false;}}
  render(data){
    if(this.destroyed)return;
    const signature=JSON.stringify(data);if(signature===this.signature)return;this.signature=signature;
    this.container.querySelector('.library-list').innerHTML=renderLibrary(data);
    for(const m of data.models)if(m.installed && !this.completed.has(m.id)){this.completed.add(m.id);this.onInstalled();}
  }
  destroy(){this.destroyed=true;clearInterval(this.timer);this.abort.abort();}
}
