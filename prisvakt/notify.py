import json
import urllib.request


def send_alarm(text: str, cfg: dict):
    print(f"\n🚨 PRISALARM 🚨\n{text}\n", flush=True)
    if cfg.get("ntfy_topic"):  # https://ntfy.sh – gratis push til mobil
        req = urllib.request.Request(
            f"{cfg.get('ntfy_server', 'https://ntfy.sh')}/{cfg['ntfy_topic']}",
            data=text.encode(), headers={"Title": "Prisalarm", "Priority": "urgent"})
        urllib.request.urlopen(req, timeout=15)
    if cfg.get("webhook_url"):  # Discord ('content') / Slack ('text')
        req = urllib.request.Request(
            cfg["webhook_url"], data=json.dumps({"content": text, "text": text}).encode(),
            headers={"Content-Type": "application/json"})
        urllib.request.urlopen(req, timeout=15)
