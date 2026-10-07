import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from prisvakt import cli
from prisvakt.crawler import crawl_site
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


if __name__ == "__main__":
    unittest.main()
