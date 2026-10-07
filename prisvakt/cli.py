import argparse
import json
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


def run_once(cfg: dict, store: Store, crawl=crawl_site) -> int:
    threshold = cfg.get("threshold", 0.90)
    alarms = 0
    for site in cfg["sites"]:
        n = 0
        print(f"Sjekker {site['name']} ...")
        for p in crawl(site):
            n += 1
            prev_max = store.record(site["name"], p)
            hit = check_drop(p.price, prev_max, p.was_price, threshold)
            if hit and not store.already_alerted(p.url, p.price):
                ref, drop = hit
                send_alarm(f"{site['name']}: {p.name}\n"
                           f"{ref:.0f} → {p.price:.0f} {p.currency} (-{drop:.0%})\n{p.url}",
                           cfg.get("notify", {}))
                store.mark_alerted(p.url, p.price)
                alarms += 1
        print(f"  {n} varer sjekket")
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
