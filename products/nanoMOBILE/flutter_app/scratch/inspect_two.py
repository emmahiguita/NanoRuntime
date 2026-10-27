import json
import asyncio
import websockets

async def inspect_two():
    uri = "ws://127.0.0.1:9222/devtools/page/7C5E0FFFE55B1A278C1F54D87CBBDC95"
    async with websockets.connect(uri) as ws:
        js = """
        (function() {
            var two = document.querySelector('.two');
            if (!two) return 'no .two';
            var children = Array.from(two.children);
            return children.map((c, i) => ({
                index: i,
                tag: c.tagName,
                id: c.id,
                className: c.className,
                rect: c.getBoundingClientRect(),
                styleWidth: window.getComputedStyle(c).width,
                styleFlex: window.getComputedStyle(c).flex,
                hasSide: !!c.querySelector('#side'),
                hasMain: !!c.querySelector('#main')
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
    asyncio.run(inspect_two())
