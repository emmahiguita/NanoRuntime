"""Curated GGUF packages. Downloads are pinned, resumable and hash verified."""
from pathlib import Path
import concurrent.futures
import copy
import hashlib
import json
import os
import re
import shutil
import struct
import threading
from urllib.request import Request, urlopen
from urllib.parse import quote
from local_model_catalog import PROJECT_ROOT


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


class ModelLibrary:
    def __init__(self, root=None, manifest=None, opener=None):
        self.root = Path(root or PROJECT_ROOT / 'models').resolve()
        self.data = manifest or json.loads(Path(__file__).with_name('model_library.json').read_text(encoding='utf8'))
        self.opener = opener or urlopen
        self.lock = threading.RLock()
        self.jobs = {}
        self.pool = concurrent.futures.ThreadPoolExecutor(max_workers=1, thread_name_prefix='nano-download')

    def model(self, identifier):
        return next((m for m in self.data['models'] if m['id'] == identifier), None)

    def destination(self, model, file):
        name = file['filename']
        if name.startswith('/') or '..' in Path(name).parts or '\\' in name or not name.endswith('.gguf'):
            raise ValueError('Ruta de paquete inválida')
        relative = Path(name).name if file['role'] == 'model' else Path('.nano-model-assets') / model['id'] / name
        dest = (self.root / relative).resolve()
        if not dest.is_relative_to(self.root):
            raise ValueError('La ruta sale de la carpeta de modelos')
        return dest

    def receipt(self, model):
        return self.root / '.nano-model-assets' / model['id'] / 'verified.json'

    def snapshot(self):
        with self.lock:
            rows = copy.deepcopy(self.data['models'])
            for row in rows:
                receipt = self.receipt(row)
                try:
                    verified = json.loads(receipt.read_text())
                    installed = verified.get('revision') == row['revision'] and all(
                        self.destination(row, f).stat().st_size == f['size']
                        and self.destination(row, f).stat().st_mtime_ns == verified['files'][f['filename']]['mtime_ns']
                        for f in row['files'])
                except (OSError, KeyError, ValueError):
                    installed = False
                row['installed'] = installed
                job = self.jobs.get(row['id'])
                row['download'] = {k:v for k,v in job.items() if k != 'stop'} if job else {'state':'installed' if installed else 'available','bytes':0}
                row['total_bytes'] = sum(f['size'] for f in row['files'])
            return {'checked_at':self.data['checked_at'],'models':rows}

    def update(self, identifier, **values):
        with self.lock:
            self.jobs[identifier].update(values)

    def start(self, identifier):
        with self.lock:
            model = self.model(identifier)
            if not model:
                raise ValueError('Modelo fuera del catálogo autorizado')
            old = self.jobs.get(identifier, {})
            if old.get('state') in ('queued','downloading','verifying','stopping'):
                return
            job = {'state':'queued','bytes':0,'error':'','file':'','stop':threading.Event()}
            self.jobs[identifier] = job
            self.pool.submit(self.run, copy.deepcopy(model), job['stop'])

    def pause(self, identifier):
        with self.lock:
            job = self.jobs.get(identifier)
            if job and job['state'] in ('queued','downloading','verifying'):
                job['stop'].set()
                job['state'] = 'stopping'

    def run(self, model, stop):
        identifier = model['id']
        done = 0
        try:
            self.root.mkdir(parents=True, exist_ok=True)
            if shutil.disk_usage(self.root).free < sum(f['size'] for f in model['files']) + 512 * 1024**2:
                raise ValueError('Espacio libre insuficiente para el paquete y el margen de instalación')
            for file in model['files']:
                if stop.is_set():
                    raise InterruptedError()
                dest = self.destination(model, file)
                dest.parent.mkdir(parents=True, exist_ok=True)
                part = dest.with_suffix('.gguf.part')
                self.update(identifier, state='downloading', file=file['filename'], bytes=done)
                if dest.exists():
                    self.update(identifier,state='verifying')
                    if dest.stat().st_size != file['size'] or sha256(dest) != file['sha256']:
                        raise ValueError('Ya existe un archivo distinto; se conservó sin sobrescribir: ' + dest.name)
                else:
                    offset = part.stat().st_size if part.exists() else 0
                    if offset > file['size']:
                        raise ValueError('El archivo parcial supera el tamaño publicado')
                    if offset < file['size']:
                        url = f"https://huggingface.co/{model['repo']}/resolve/{model['revision']}/{quote(file['filename'])}"
                        request = Request(url, headers={'User-Agent':'NanoDesktop/0.1', **({'Range':f'bytes={offset}-'} if offset else {})})
                        with self.opener(request, timeout=30) as response:
                            if offset and (response.status != 206 or not response.headers.get('Content-Range','').startswith(f'bytes {offset}-')):
                                # Server ignored Range: restart this partial, never append full bytes.
                                offset = 0
                                if response.status != 200:
                                    raise ValueError('El servidor no confirmó el rango solicitado')
                            with part.open('ab' if offset else 'wb') as output:
                                while True:
                                    if stop.is_set():
                                        raise InterruptedError()
                                    chunk = response.read(4 * 1024 * 1024)
                                    if not chunk:
                                        break
                                    offset += len(chunk)
                                    if offset > file['size']:
                                        raise ValueError('La descarga excede el tamaño publicado')
                                    output.write(chunk)
                                    self.update(identifier,bytes=done+offset)
                    self.update(identifier,state='verifying')
                    if part.stat().st_size != file['size'] or sha256(part) != file['sha256']:
                        # Retain damaged bytes separately so Retry can start cleanly.
                        os.replace(part, part.with_suffix('.invalid'))
                        raise ValueError('La integridad SHA-256 no coincide; no se instaló el archivo')
                    with part.open('rb') as stream:
                        magic,version,tensors,metadata=struct.unpack('<4sIQQ',stream.read(24))
                    if magic != b'GGUF' or version not in (2,3) or not tensors or not metadata:
                        raise ValueError('El archivo no tiene una cabecera GGUF válida')
                    if stop.is_set():
                        raise InterruptedError()
                    os.replace(part,dest)
                done += file['size']
                self.update(identifier,bytes=done)
            if stop.is_set():
                raise InterruptedError()
            receipt = self.receipt(model)
            receipt.parent.mkdir(parents=True,exist_ok=True)
            payload={'revision':model['revision'],'repo':model['repo'],'files':{f['filename']:{'sha256':f['sha256'],'mtime_ns':self.destination(model,f).stat().st_mtime_ns} for f in model['files']}}
            temporary=receipt.with_suffix('.tmp');temporary.write_text(json.dumps(payload));os.replace(temporary,receipt)
            self.update(identifier,state='installed',bytes=done,file='')
        except InterruptedError:
            self.update(identifier,state='paused',error='Descarga detenida. Puedes reanudarla.')
        except Exception as error:
            self.update(identifier,state='error',error=str(error))

    def refresh(self):
        with self.lock:
            if any(j['state'] in ('queued','downloading','verifying','stopping') for j in self.jobs.values()):
                raise ValueError('Espera a que terminen las descargas antes de sincronizar fuentes')
            updated=copy.deepcopy(self.data)
            for model in updated['models']:
                request=Request(f"https://huggingface.co/api/models/{model['repo']}?blobs=true",headers={'User-Agent':'NanoDesktop/0.1'})
                with self.opener(request,timeout=20) as response:
                    data=json.loads(response.read(4*1024*1024))
                revision=data.get('sha','')
                if not re.fullmatch('[0-9a-f]{40}',revision):
                    raise ValueError('Revisión remota inválida')
                for file in model['files']:
                    source=next((f for f in data['siblings'] if f['rfilename']==file['filename']),None)
                    digest=(source or {}).get('lfs',{}).get('sha256','')
                    size=(source or {}).get('size',0)
                    if not re.fullmatch('[0-9a-f]{64}',digest) or not isinstance(size,int) or not 0<size<40*1024**3:
                        raise ValueError('La fuente no publica tamaño o hash válido')
                    file.update(size=size,sha256=digest)
                model['revision']=revision
            from datetime import datetime,timezone
            updated['checked_at']=datetime.now(timezone.utc).isoformat()
            self.data=updated
            self.jobs={}
        return self.snapshot()


library = ModelLibrary()
