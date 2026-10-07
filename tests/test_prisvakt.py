import json
import os
import sys
import tempfile
import threading
import time
import unittest
import urllib.error

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from prisvakt import cli
from prisvakt.crawler import Throttle, crawl_site
from prisvakt.db import Store
from prisvakt.extract import extract_products, parse_price


def page(name, price, url="https://shop.no/product/1"):
    ld = {"@context": "https://schema.org", "@type": "Product", "name": name, "url": url,
          "offers": {"@type": "Offer", "price": price, "priceCurrency": "NOK"}}
    return f'<html><script type="application/ld+json">{json.dumps(ld)}</script></html>'


class T(unittest.TestCase):
    def test_parse_price(self):
        for raw, want in [("1 299,-", 1299), ("1.299,00", 1299), ("1299.90", 1299.9),
                          ("12,50", 12.5), ("1,299.00", 1299), (499, 499), ("1.299", 1299)]:
            self.assertEqual(parse_price(raw), want, raw)

    def test_extract_jsonld(self):
        [p] = extract_products(page("TV", "4990"), "https://shop.no/x")
        self.assertEqual((p.name, p.price), ("TV", 4990.0))

    def test_ignores_business_ex_vat_offer(self):  # struktur som på elkjop.no
        ld = {"@type": "Product", "name": "LED", "offers": [
            {"@type": "Offer", "name": "Standard Price", "price": "998", "priceCurrency": "NOK",
             "eligibleCustomerType": {"@type": "BusinessEntityType", "@id": "https://schema.org/Public"},
             "priceSpecification": [{"@type": "UnitPriceSpecification", "price": "798.4",
                                     "valueAddedTaxIncluded": False}]},
            {"@type": "Offer", "name": "Business Price (Excl. VAT)", "price": "798.4",
             "eligibleCustomerType": {"@type": "BusinessEntityType", "@id": "https://schema.org/Business"}}]}
        html = f'<script type="application/ld+json">{json.dumps(ld)}</script>'
        [p] = extract_products(html, "https://www.elkjop.no/product/x/1")
        self.assertEqual(p.price, 998.0)

    def test_check_drop(self):
        self.assertIsNotNone(cli.check_drop(99, 1000, None, 0.9))
        self.assertIsNone(cli.check_drop(101, 1000, None, 0.9))
        self.assertIsNotNone(cli.check_drop(50, None, 1000, 0.9))  # før-pris på siden
        self.assertIsNone(cli.check_drop(50, None, None, 0.9))

    def test_end_to_end_alarm_once(self):
        prices = iter(["1000", "50", "50"])
        site = {"name": "T", "start_urls": ["https://shop.no/list"], "delay": 0}
        crawl = lambda s: crawl_site(s, fetcher=lambda u: page("TV", next(prices)), sleep=lambda _: None)
        with tempfile.TemporaryDirectory() as d:
            store = Store(os.path.join(d, "t.db"))
            cfg = {"sites": [site], "threshold": 0.9}
            counts = [cli.run_once(cfg, store, crawl) for _ in range(3)]
        self.assertEqual(counts, [0, 1, 0])  # alarm én gang, ikke gjentatt


    def test_backoff_on_429_and_retry(self):
        calls = []

        def fetcher(u):
            calls.append(u)
            if len(calls) == 1:
                raise urllib.error.HTTPError(u, 429, "Too Many", {"Retry-After": "0"}, None)
            return page("TV", "100")
        site = {"name": "T", "start_urls": ["https://shop.no/p"], "delay": 0, "concurrency": 2}
        found = list(crawl_site(site, fetcher=fetcher, sleep=lambda _: None))
        self.assertEqual(len(calls), 2)  # prøvde på nytt
        self.assertEqual(len(found), 1)

    def test_exclude_pattern_skips_categories(self):
        sitemap = ('<urlset><url><loc>https://shop.no/product/hvitevarer/1</loc></url>'
                   '<url><loc>https://shop.no/product/gaming/2</loc></url></urlset>')
        fetched = []

        def fetcher(u):
            fetched.append(u)
            return sitemap if u.endswith(".xml") else page("X", "10", url=u)
        site = {"name": "T", "start_urls": ["https://shop.no/s.xml"], "delay": 0,
                "exclude_pattern": "/product/hvitevarer/"}
        list(crawl_site(site, fetcher=fetcher))
        self.assertEqual(sorted(fetched), ["https://shop.no/product/gaming/2", "https://shop.no/s.xml"])

    def test_throttle_doubles_and_recovers(self):
        th = Throttle(0.25, sleep=lambda _: None)
        self.assertEqual(th.slow_down(), 0.5)
        self.assertEqual(th.slow_down(), 1.0)
        for _ in range(200):
            th.ok()
        self.assertEqual(th.delay, 0.25)

    def test_runs_requests_concurrently(self):
        active, peak, lock = [0], [0], threading.Lock()
        urls = [f"https://shop.no/product/{i}" for i in range(8)]

        def fetcher(u):
            with lock:
                active[0] += 1
                peak[0] = max(peak[0], active[0])
            time.sleep(0.05)
            with lock:
                active[0] -= 1
            return page("X", "10", url=u)
        site = {"name": "T", "start_urls": urls, "delay": 0, "concurrency": 4}
        self.assertEqual(len(list(crawl_site(site, fetcher=fetcher))), 8)
        self.assertGreater(peak[0], 1)


if __name__ == "__main__":
    unittest.main()
