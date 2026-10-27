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

async def apply_web_mode(show_list=True):
    uri = get_ws_url()
    async with websockets.connect(uri) as ws:
        js = f"""
        (function() {{
            var vp = document.querySelector('meta[name="viewport"]');
            document.body.classList.remove('nano-view-list', 'nano-view-chat');
            document.documentElement.classList.remove('nano-wa-mobile-shell');
            document.documentElement.classList.add('nano-wa-web-mode');
            if ({'true' if show_list else 'false'}) {{
                document.body.classList.remove('nano-web-chat');
            }} else {{
                document.body.classList.add('nano-web-chat');
            }}
            var s = document.getElementById('nano-wa-responsive-style');
            if (s) s.remove();
            if (!vp) {{
                vp = document.createElement('meta');
                vp.name = 'viewport';
                document.head.appendChild(vp);
            }}
            vp.setAttribute('content', 'width=device-width, initial-scale=0.88, minimum-scale=0.5, maximum-scale=5, user-scalable=yes');

            var bannerStyle = document.getElementById('nano-wa-web-mode-banner-fix');
            if (!bannerStyle) {{
                bannerStyle = document.createElement('style');
                bannerStyle.id = 'nano-wa-web-mode-banner-fix';
                document.head.appendChild(bannerStyle);
            }}
            bannerStyle.textContent = `
                #pane-side ~ div,
                div:has(> a[href*="whatsapp.com/download"]),
                [data-testid="download-windows-banner"] {{
                    display: none !important;
                }}
                html.nano-wa-web-mode,
                html.nano-wa-web-mode body,
                html.nano-wa-web-mode #app,
                html.nano-wa-web-mode .two {{
                    width: 100vw !important;
                    max-width: 100vw !important;
                    min-width: 0 !important;
                    overflow-x: hidden !important;
                }}
                html.nano-wa-web-mode .two > header {{
                    width: 50px !important;
                    min-width: 50px !important;
                    max-width: 50px !important;
                    flex: 0 0 50px !important;
                    z-index: 30 !important;
                }}
                html.nano-wa-web-mode .two > div:has(#side) {{
                    width: calc(100vw - 50px) !important;
                    max-width: calc(100vw - 50px) !important;
                    min-width: 0 !important;
                    flex: 0 0 calc(100vw - 50px) !important;
                }}
                html.nano-wa-web-mode #side {{
                    width: 100% !important;
                    max-width: 100% !important;
                    min-width: 0 !important;
                }}
                html.nano-wa-web-mode body:not(.nano-web-chat) .two > div:has(#main),
                html.nano-wa-web-mode .two > div:has([data-testid="intro-panel"]) {{
                    display: none !important;
                }}
                html.nano-wa-web-mode body.nano-web-chat:has(#main) .two > div:has(#side) {{
                    display: none !important;
                }}
                html.nano-wa-web-mode body.nano-web-chat:has(#main) .two > div:has(#main) {{
                    display: flex !important;
                    width: calc(100vw - 50px) !important;
                    max-width: calc(100vw - 50px) !important;
                    min-width: 0 !important;
                    flex: 0 0 calc(100vw - 50px) !important;
                }}
                html.nano-wa-web-mode #main {{
                    width: 100% !important;
                    max-width: 100% !important;
                    min-width: 0 !important;
                }}
                html.nano-wa-web-mode #main > header button[disabled] {{
                    display: none !important;
                }}
                html.nano-wa-web-mode #pane-side {{
                    -webkit-overflow-scrolling: touch !important;
                    overflow-y: auto !important;
                    touch-action: pan-y !important;
                }}
            `;

            var appEl = document.getElementById('app') || document.body;
            if (window.__nanoWebClickHandler) {{
                appEl.removeEventListener('click', window.__nanoWebClickHandler, true);
            }}
            window.__nanoWebClickHandler = function(ev) {{
                if (!document.documentElement.classList.contains('nano-wa-web-mode')) return;
                if (window.__nanoIsScrolling) return;
                var rail = document.querySelector('.two > header');
                if (rail && rail.contains(ev.target)) {{
                    document.body.classList.remove('nano-web-chat');
                    return;
                }}
                var pane = document.getElementById('pane-side');
                var row = ev.target?.closest?.('[role="listitem"], [role="row"], [data-testid="cell-frame-container"]');
                if (pane && row && pane.contains(row)) {{
                    setTimeout(function() {{
                        if (document.getElementById('main')) {{
                            document.body.classList.add('nano-web-chat');
                        }}
                    }}, 80);
                }}
            }};
            appEl.addEventListener('click', window.__nanoWebClickHandler, true);
            return 'OK';
        }})()
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
    import sys
    show_list = sys.argv[1] != "chat" if len(sys.argv) > 1 else True
    asyncio.run(apply_web_mode(show_list=show_list))
