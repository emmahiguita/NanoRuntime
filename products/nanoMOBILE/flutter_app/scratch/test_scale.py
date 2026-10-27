import json
import asyncio
import websockets

async def set_scale(scale_val):
    uri = "ws://127.0.0.1:9222/devtools/page/7C5E0FFFE55B1A278C1F54D87CBBDC95"
    async with websockets.connect(uri) as ws:
        js = f"""
        (function() {{
            var vp = document.querySelector('meta[name="viewport"]');
            if (vp) {{
                vp.setAttribute('content', 'width=device-width, initial-scale={scale_val}, minimum-scale=0.5, maximum-scale=5, user-scalable=yes');
            }}
            var bannerStyle = document.getElementById('nano-wa-web-mode-banner-fix');
            if (!bannerStyle) {{
                bannerStyle = document.createElement('style');
                bannerStyle.id = 'nano-wa-web-mode-banner-fix';
                document.head.appendChild(bannerStyle);
            }}
            bannerStyle.textContent = 'div:has(> a[href*="whatsapp.com/download"]), [data-testid="download-windows-banner"] {{ display: none !important; }} #pane-side {{ -webkit-overflow-scrolling: touch !important; overflow-y: auto !important; touch-action: pan-y !important; }}';
            return 'Scale set to {scale_val}';
        }})()
        """
        msg = {
            "id": 1,
            "method": "Runtime.evaluate",
            "params": {"expression": js, "returnByValue": True}
        }
        await ws.send(json.dumps(msg))
        resp = await ws.recv()
        print("Response:", resp)

if __name__ == "__main__":
    asyncio.run(set_scale(0.85))
