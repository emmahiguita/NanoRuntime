import json
import urllib.request
import asyncio
import websockets

def get_ws_url():
    with urllib.request.urlopen("http://127.0.0.1:9222/json") as resp:
        pages = json.loads(resp.read().decode())
        for p in pages:
            if p.get("type") == "page" and "whatsapp.com" in p.get("url", ""):
                return p["webSocketDebuggerUrl"]
    raise RuntimeError("No WhatsApp page found")

async def find_banner():
    uri = get_ws_url()
    async with websockets.connect(uri) as ws:
        js = """
        (function() {
            var side = document.getElementById('side');
            if (!side) return 'no side';
            var children = Array.from(side.children);
            return children.map((c, i) => ({
                i: i,
                tag: c.tagName,
                id: c.id,
                text: c.innerText.slice(0, 80),
                rect: c.getBoundingClientRect()
            }));
        })()
        """
        msg = {
            "id": 1,
            "method": "Runtime.evaluate",
            "params": {"expression": js, "returnByValue": True}
        }
        await ws.send(json.dumps(msg))
        resp = await ws.recv()
        print(resp)

if __name__ == "__main__":
    asyncio.run(find_banner())
