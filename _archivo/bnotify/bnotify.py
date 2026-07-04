#!/usr/bin/env python3
"""
bnotify — SBOS Notifier Daemon v1.0
===================================
Sistema de notificaciones universales del ecosistema SBOS.

Stack:
  Apprise (100+ providers: email, SMS, push, Slack, Telegram, Signal...)
  Centrifugo (WebSocket real-time push via HTTP API)
  JSON-RPC 2.0 (ADR-020 compliant)

Transporte: Unix socket /run/bos/bnotify.sock (permisos 0660 grupo bosagent)
Puertos ClusterIP: 28200 (API), 28201 (Push WS), 28202 (MFA), 28203 (Webhook)

Metodos JSON-RPC:
  bnotify.health.check
  bnotify.message.send    — email, SMS, chat (Apprise)
  bnotify.push.send       — WebSocket push (Centrifugo)
  bnotify.mfa.challenge   — MFA push challenge (RFC 9470 Step-Up)
  bnotify.providers.list  — listar providers Apprise disponibles
"""

import json, os, sys, socket, uuid, threading, time, struct
from pathlib import Path

# ── Config ────────────────────────────────────────────────────
SOCKET_PATH = "/run/bos/bnotify.sock"
SOCKET_PERMS = 0o660
SOCKET_GROUP = "bosagent"
MAX_REQUEST_BYTES = 65536  # 64KB

# Centrifugo (S10 commsserver)
CENTRIFUGO_URL = "http://localhost:8650/api"
CENTRIFUGO_API_KEY = os.environ.get("CENTRIFUGO_API_KEY", "sbos-dev-key")

# Apprise (se carga lazy)
apprise = None
APPRISE_CONFIG = os.environ.get("APPRISE_CONFIG", "/etc/bos/apprise.yml")

# ── JSON-RPC 2.0 ──────────────────────────────────────────────

def jsonrpc_error(id, code, message):
    return {"jsonrpc": "2.0", "error": {"code": code, "message": message}, "id": id}

def jsonrpc_result(id, result):
    return {"jsonrpc": "2.0", "result": result, "id": id}

# ── Apprise Init (lazy) ────────────────────────────────────────

def get_apprise():
    global apprise
    if apprise is None:
        import apprise as ap
        apprise = ap.Apprise()
        if Path(APPRISE_CONFIG).exists():
            cfg = ap.AppriseConfig()
            cfg.add(APPRISE_CONFIG)
            apprise.add(cfg)
        else:
            # Sin config: solo providers explicitos via URL
            pass
    return apprise

# ── Handlers ───────────────────────────────────────────────────

def handle_health(params, id):
    return jsonrpc_result(id, {
        "status": "operativo",
        "version": "1.0.0",
        "socket": SOCKET_PATH,
        "providers_loaded": len(get_apprise()),
        "centrifugo": CENTRIFUGO_URL,
    })

def handle_message_send(params, id):
    """bnotify.message.send — Enviar notificacion via Apprise.
    params: { channel, recipient, template?, subject, body, priority? }
    channel: email | sms | telegram | slack | discord | whatsapp | signal | ...
    """
    channel = params.get("channel", "email")
    recipient = params.get("recipient", "")
    subject = params.get("subject", "SBOS Notification")
    body = params.get("body", "")
    priority = params.get("priority", "normal")
    template = params.get("template", "")

    if not recipient:
        return jsonrpc_error(id, -32602, "recipient requerido")

    ap = get_apprise()
    title = subject

    try:
        # Construir URL Apprise segun canal
        url = build_apprise_url(channel, recipient)
        if not url:
            return jsonrpc_error(id, -32602, f"canal '{channel}' no soportado")

        ap2 = apprise.Apprise()
        ap2.add(url)
        ap2.notify(title=title, body=body)
        return jsonrpc_result(id, {
            "sent": True,
            "channel": channel,
            "recipient": recipient,
            "message_id": str(uuid.uuid4()),
        })
    except Exception as e:
        return jsonrpc_error(id, -32000, f"envio fallido: {e}")

def build_apprise_url(channel, recipient):
    """Construye URL Apprise segun canal."""
    urls = {
        "email":     f"mailto://{recipient}",
        "smtp":      f"mailto://{recipient}",
        "slack":     f"slack://{recipient}",
        "discord":   f"discord://{recipient}",
        "telegram":  f"tgram://{recipient}",
        "signal":    f"signal://{recipient}",
        "whatsapp":  f"whatsapp://{recipient}",
        "matrix":    f"matrix://{recipient}",
        "mattermost": f"mmost://{recipient}",
        "rocketchat": f"rocket://{recipient}",
        "pushover":  f"pover://{recipient}",
        "pushbullet": f"pbul://{recipient}",
        "ntfy":      f"ntfy://{recipient}",
        "fcm":       f"fcm://{recipient}",
        "sms":       f"twilio://{recipient}",
        "twilio":    f"twilio://{recipient}",
    }
    return urls.get(channel, urls.get(channel.lower(), ""))

def handle_push_send(params, id):
    """bnotify.push.send — Enviar push WebSocket via Centrifugo.
    params: { channel, data, user_ids? }
    """
    channel = params.get("channel", "sbos:broadcast")
    data = params.get("data", {})
    user_ids = params.get("user_ids", [])

    try:
        import urllib.request
        payload = json.dumps({
            "method": "publish",
            "params": {
                "channel": channel,
                "data": data,
            }
        }).encode()

        req = urllib.request.Request(
            CENTRIFUGO_URL,
            data=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": CENTRIFUGO_API_KEY,
            }
        )
        urllib.request.urlopen(req, timeout=5)
        return jsonrpc_result(id, {
            "sent": True,
            "channel": channel,
            "user_ids": user_ids,
        })
    except Exception as e:
        return jsonrpc_error(id, -32000, f"Centrifugo: {e}")

def handle_mfa_challenge(params, id):
    """bnotify.mfa.challenge — MFA Step-Up challenge (RFC 9470).
    params: { user_id, challenge_type, number, nonce, ttl_seconds, message }
    """
    user_id = params.get("user_id", "")
    number = params.get("number", 0)
    nonce = params.get("nonce", "")
    ttl = params.get("ttl_seconds", 300)
    msg = params.get("message", f"Ingrese {number} para confirmar")

    # 1. Push via Centrifugo al canal del usuario
    import urllib.request
    try:
        payload = json.dumps({
            "method": "publish",
            "params": {
                "channel": f"bauth:mfa:{user_id}",
                "data": {
                    "type": "mfa_challenge",
                    "number": number,
                    "nonce": nonce,
                    "ttl_seconds": ttl,
                    "message": msg,
                }
            }
        }).encode()
        req = urllib.request.Request(
            CENTRIFUGO_URL, data=payload,
            headers={"Content-Type": "application/json", "X-API-Key": CENTRIFUGO_API_KEY}
        )
        urllib.request.urlopen(req, timeout=5)
    except Exception as e:
        return jsonrpc_error(id, -32000, f"MFA push: {e}")

    return jsonrpc_result(id, {
        "challenged": True,
        "user_id": user_id,
        "challenge_type": "number_matching",
        "ttl_seconds": ttl,
    })

def handle_providers_list(params, id):
    """bnotify.providers.list — Listar providers Apprise disponibles."""
    ap = get_apprise()
    plugins = sorted(ap.details().get("schemas", []) if hasattr(ap, 'details') else [])
    return jsonrpc_result(id, {
        "count": len(plugins),
        "providers": plugins[:20],  # primeros 20
        "note": "100+ providers disponibles via Apprise",
    })

# ── Dispatcher ─────────────────────────────────────────────────

METHODS = {
    "bnotify.health.check":     handle_health,
    "bnotify.message.send":     handle_message_send,
    "bnotify.push.send":        handle_push_send,
    "bnotify.mfa.challenge":    handle_mfa_challenge,
    "bnotify.providers.list":   handle_providers_list,
}

def dispatch(request_str):
    try:
        req = json.loads(request_str)
    except json.JSONDecodeError:
        return json.dumps(jsonrpc_error(None, -32700, "parse error"))

    method = req.get("method", "")
    params = req.get("params", {})
    rid = req.get("id", None)

    if method not in METHODS:
        return json.dumps(jsonrpc_error(rid, -32601, f"metodo no encontrado: {method}"))

    try:
        result = METHODS[method](params, rid)
        return json.dumps(result)
    except Exception as e:
        return json.dumps(jsonrpc_error(rid, -32000, str(e)))

# ── Unix Socket Server ─────────────────────────────────────────

def handle_client(conn, addr):
    """Maneja una conexion JSON-RPC sobre Unix socket."""
    try:
        conn.settimeout(30)
        data = b""
        while True:
            try:
                chunk = conn.recv(4096)
                if not chunk:
                    break
                data += chunk
                if len(data) > MAX_REQUEST_BYTES:
                    break
                if b"\n" in data:
                    break
            except socket.timeout:
                break

        if data:
            request_str = data.decode("utf-8", errors="replace").strip()
            # Extraer primer objeto JSON valido
            for line in request_str.split("\n"):
                line = line.strip()
                if line.startswith("{"):
                    response = dispatch(line)
                    conn.sendall(response.encode() + b"\n")
                    break
    except Exception as e:
        print(f"[bnotify] error: {e}", file=sys.stderr)
    finally:
        try:
            conn.close()
        except:
            pass

def create_socket():
    """Crea el socket Unix con permisos correctos."""
    if os.path.exists(SOCKET_PATH):
        os.unlink(SOCKET_PATH)

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.bind(SOCKET_PATH)
    os.chmod(SOCKET_PATH, SOCKET_PERMS)

    # Cambiar grupo
    try:
        import grp
        gid = grp.getgrnam(SOCKET_GROUP).gr_gid
        os.chown(SOCKET_PATH, -1, gid)
    except Exception:
        pass

    sock.listen(128)
    return sock

def main():
    print(f"[bnotify] iniciando en {SOCKET_PATH}")
    sock = create_socket()
    print(f"[bnotify] escuchando...")

    while True:
        try:
            conn, addr = sock.accept()
            t = threading.Thread(target=handle_client, args=(conn, addr), daemon=True)
            t.start()
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"[bnotify] accept error: {e}", file=sys.stderr)

    sock.close()
    if os.path.exists(SOCKET_PATH):
        os.unlink(SOCKET_PATH)
    print("[bnotify] detenido")

if __name__ == "__main__":
    main()
