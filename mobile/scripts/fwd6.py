#!/usr/bin/env python3
"""Forward [::1]:<port> -> 127.0.0.1:<port> for the Firebase emulators.

`adb reverse` connects to the Mac over IPv6 (::1) but the emulators listen on
IPv4 only. Ports already accepting on ::1 are skipped (idempotent).
Usage: fwd6.py 8081 9099 9199   (runs until killed)
"""
import socket
import sys
import threading


def answers(port):
    try:
        with socket.create_connection(("::1", port), timeout=0.5):
            return True
    except OSError:
        return False


def pump(src, dst):
    try:
        while data := src.recv(65536):
            dst.sendall(data)
    except OSError:
        pass
    finally:
        for s in (src, dst):
            try:
                s.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass


def handle(client, port):
    try:
        upstream = socket.create_connection(("127.0.0.1", port), timeout=5)
    except OSError:
        client.close()
        return
    threading.Thread(target=pump, args=(client, upstream), daemon=True).start()
    pump(upstream, client)
    client.close()
    upstream.close()


def serve(port):
    srv = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
    srv.bind(("::1", port))
    srv.listen(64)
    while True:
        c, _ = srv.accept()
        threading.Thread(target=handle, args=(c, port), daemon=True).start()


def main():
    started = []
    for port in map(int, sys.argv[1:]):
        if answers(port):
            print(f"[::1]:{port} already answers, skipping", flush=True)
            continue
        threading.Thread(target=serve, args=(port,), daemon=True).start()
        started.append(port)
    if not started:
        return
    print(f"forwarding [::1] -> 127.0.0.1 for {started}", flush=True)
    threading.Event().wait()


if __name__ == "__main__":
    main()
