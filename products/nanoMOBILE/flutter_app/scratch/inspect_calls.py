import json
import asyncio
import websockets

async def inspect_calls():
    uri = "ws://127.0.0.1:9222/devtools/page/7C5E0FFFE55B1A278C1F54D87CBBDC95"
    async with websockets.connect(uri) as ws:
        js = """
        (function() {
            var header = document.querySelector('#main header');
            if (!header) return 'No header';
            var btns = Array.from(header.querySelectorAll('button, [role="button"]'));
            return btns.map(b => ({
                ariaLabel: b.getAttribute('aria-label'),
                title: b.getAttribute('title'),
                disabled: b.disabled,
                html: b.outerHTML.slice(0, 200)
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
    asyncio.run(inspect_calls())
