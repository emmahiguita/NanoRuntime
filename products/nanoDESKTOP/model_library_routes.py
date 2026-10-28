"""HTTP boundary; inherits Desktop Host/Origin/auth checks before dispatch."""
import json
from urllib.parse import urlsplit
from model_library import library


def handle_library_route(handler,method):
    path=urlsplit(handler.path).path
    if path != '/api/model-library' and path not in ('/api/model-library/start','/api/model-library/pause','/api/model-library/refresh'):
        return False
    status=200
    try:
        if path == '/api/model-library' and method == 'GET':
            payload=library.snapshot()
        elif method == 'POST' and path != '/api/model-library':
            size=int(handler.headers.get('Content-Length','0'))
            if handler.headers.get('Content-Type','').split(';')[0] != 'application/json' or not 0<size<=1024:
                raise ValueError('Petición JSON inválida')
            data=json.loads(handler.rfile.read(size))
            if not isinstance(data,dict):
                raise ValueError('Petición inválida')
            if path.endswith('/refresh'):
                library.refresh()
            elif path.endswith('/start'):
                library.start(data.get('id'))
            else:
                library.pause(data.get('id'))
            payload=library.snapshot()
        else:
            status=405;payload={'error':'Método no admitido'}
    except (ValueError,TypeError) as error:
        status=422;payload={'error':str(error)}
    except Exception:
        status=503;payload={'error':'No se pudo consultar la fuente de modelos. Se conserva el catálogo anterior.'}
    body=json.dumps(payload,ensure_ascii=False).encode('utf8')
    handler.send_response(status)
    handler.send_header('Content-Type','application/json; charset=utf-8')
    handler.send_header('Content-Length',str(len(body)))
    handler.end_headers();handler.wfile.write(body)
    return True
