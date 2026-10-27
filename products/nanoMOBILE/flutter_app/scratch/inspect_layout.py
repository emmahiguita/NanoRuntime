import json
import asyncio
import websockets

async def inspect_side_layout():
    uri = "ws://127.0.0.1:9222/devtools/page/7C5E0FFFE55B1A278C1F54D87CBBDC95"
    async with websockets.connect(uri) as ws:
        js = """
        (function() {
            var side = document.getElementById('side');
            var two = document.querySelector('.two');
            var rail = document.querySelector('.two > header') || document.querySelector('[role="navigation"]');
            var app = document.getElementById('app');
            var vp = document.querySelector('meta[name="viewport"]');
            return {
                windowWidth: window.innerWidth,
                windowOuterWidth: window.outerWidth,
                viewportContent: vp ? vp.getAttribute('content') : null,
                railWidth: rail ? rail.getBoundingClientRect().width : null,
                sideWidth: side ? side.getBoundingClientRect().width : null,
                sideComputedWidth: side ? window.getComputedStyle(side).width : null,
                sideMinWidth: side ? window.getComputedStyle(side).minWidth : null,
                twoWidth: two ? two.getBoundingClientRect().width : null,
                appWidth: app ? app.getBoundingClientRect().width : null
            };
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
    asyncio.run(inspect_side_layout())
