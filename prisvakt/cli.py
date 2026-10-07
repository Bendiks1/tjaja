import argparse
import json
import queue
import threading
import time

from .crawler import crawl_site
from .db import Store
from .notify import send_alarm


def check_drop(price: float, prev_max: float | None, was_price: float | None,
               threshold: float) -> tuple[float, float] | None:
    """(referansepris, nedgang som brøk) hvis fallet >= terskel, ellers None."""
    ref = max(x for x in (prev_max, was_price, price) if x)
    if price <= 0 or ref <= price:
        return None
    drop = 1 - price / ref
    return (ref, drop) if drop >= threshold else None


def _crawl_into(site: dict, crawl, out: queue.Queue):
    try:
        for p in crawl(site):
            out.put((site, p))
    except Exception as e:
        print(f"  [{site['name']}] krasjet: {e}")
    finally:
        out.put((site, None))  # ferdig-signal


def run_once(cfg: dict, store: Store, crawl=crawl_site) -> int:
    """Crawler alle butikker parallelt; lagring og alarmer skjer i denne tråden."""
    threshold = cfg.get("threshold", 0.90)
    alarms = 0
    out: queue.Queue = queue.Queue(maxsize=1000)
    sites = cfg["sites"]
    for site in sites:
        print(f"Sjekker {site['name']} ...")
        threading.Thread(target=_crawl_into, args=(site, crawl, out), daemon=True).start()
    counts = {s["name"]: 0 for s in sites}
    remaining = len(sites)
    while remaining:
        site, p = out.get()
        if p is None:
            remaining -= 1
            print(f"  {site['name']}: {counts[site['name']]} varer sjekket")
            continue
        counts[site["name"]] += 1
        prev_max = store.record(site["name"], p)
        hit = check_drop(p.price, prev_max, p.was_price, threshold)
        if hit and not store.already_alerted(p.url, p.price):
            ref, drop = hit
            send_alarm(f"{site['name']}: {p.name}\n"
                       f"{ref:.0f} → {p.price:.0f} {p.currency} (-{drop:.0%})\n{p.url}",
                       cfg.get("notify", {}))
            store.mark_alerted(p.url, p.price)
            alarms += 1
    return alarms


def main():
    ap = argparse.ArgumentParser(prog="prisvakt")
    ap.add_argument("-c", "--config", default="config.json")
    ap.add_argument("--every", type=float, metavar="MINUTTER",
                    help="kjør i løkke med dette intervallet (ellers én gang)")
    args = ap.parse_args()
    cfg = json.load(open(args.config))
    store = Store(cfg.get("database", "prisvakt.db"))
    while True:
        run_once(cfg, store)
        if not args.every:
            break
        time.sleep(args.every * 60)
