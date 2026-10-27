import json
import asyncio
import websockets

async def test_web_fit():
    uri = "ws://127.0.0.1:9222/devtools/page/7C5E0FFFE55B1A278C1F54D87CBBDC95"
    async with websockets.connect(uri) as ws:
        js = """
        (function() {
            var vp = document.querySelector('meta[name="viewport"]');
            if (vp) {
                vp.setAttribute('content', 'width=device-width, initial-scale=0.9, minimum-scale=0.5, maximum-scale=5, user-scalable=yes');
            }
            var bannerStyle = document.getElementById('nano-wa-web-mode-banner-fix');
            if (!bannerStyle) {
                bannerStyle = document.createElement('style');
                bannerStyle.id = 'nano-wa-web-mode-banner-fix';
                document.head.appendChild(bannerStyle);
            }
            bannerStyle.textContent = `
                div:has(> a[href*="whatsapp.com/download"]),
                [data-testid="download-windows-banner"] {
                    display: none !important;
                }
                .two > header {
                    width: 52px !important;
                    min-width: 52px !important;
                    max-width: 52px !important;
                    flex: 0 0 52px !important;
                }
                .two > div:has(#side) {
                    width: calc(100vw - 52px) !important;
                    max-width: calc(100vw - 52px) !important;
                    min-width: 0 !important;
                    flex: 0 0 calc(100vw - 52px) !important;
                }
                #side {
                    width: 100% !important;
                    max-width: 100% !important;
                    min-width: 0 !important;
                }
                #pane-side {
                    -webkit-overflow-scrolling: touch !important;
                    overflow-y: auto !important;
                    touch-action: pan-y !important;
                }
            `;
            window.scrollTo(0, 0);
            document.documentElement.scrollLeft = 0;
            document.body.scrollLeft = 0;
            var two = document.querySelector('.two');
            if (two) two.scrollLeft = 0;
            return {
                winW: window.innerWidth,
                railW: document.querySelector('.two > header')?.getBoundingClientRect().width,
                sideW: document.getElementById('side')?.getBoundingClientRect().width,
                sideRight: document.getElementById('side')?.getBoundingClientRect().right
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
    asyncio.run(test_web_fit())
