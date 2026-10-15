"""Forward <LAN_IP>:<port> -> 127.0.0.1:<port> so a phone on Wi-Fi reaches localhost-only emulators.

Usage: python3 mobile/scripts/lan_forward.py 192.168.x.y 8081 9099 9199
"""
import asyncio, sys
LAN = sys.argv[1]; PORTS = [int(p) for p in sys.argv[2:]]
async def pipe(r, w):
    try:
        while (d := await r.read(65536)):
            w.write(d); await w.drain()
    except Exception: pass
    finally: w.close()
async def handle(cr, cw, port):
    try: ur, uw = await asyncio.open_connection("127.0.0.1", port)
    except Exception: cw.close(); return
    await asyncio.gather(pipe(cr, uw), pipe(ur, cw))
async def main():
    for p in PORTS:
        await asyncio.start_server(lambda r, w, p=p: handle(r, w, p), LAN, p)
        print("forwarding", f"{LAN}:{p}", "->", f"127.0.0.1:{p}", flush=True)
    await asyncio.Event().wait()
asyncio.run(main())
