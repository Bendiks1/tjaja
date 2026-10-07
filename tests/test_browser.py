"""Integrasjonstest for nettleser-modus. Hoppes over hvis Playwright ikke er installert.
Bruk PRISVAKT_CHROMIUM=/sti/til/chrome hvis Chromium ikke er installert via `playwright install`."""
import http.server
import importlib.util
import os
import sys
import threading
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from prisvakt.crawler import crawl_site

# Pris og JSON-LD legges inn av JavaScript – usynlig for vanlig HTTP-henting.
JS_PAGE = b"""<html><body><script>
const ld = document.createElement('script'); ld.type = 'application/ld+json';
ld.textContent = JSON.stringify({"@type": "Product", "name": "JS-TV",
  "offers": {"@type": "Offer", "price": "4990", "priceCurrency": "NOK"}});
document.head.appendChild(ld);
</script></body></html>"""


class _Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(JS_PAGE)

    def log_message(self, *a):
        pass


@unittest.skipUnless(importlib.util.find_spec("playwright"), "playwright ikke installert")
class BrowserTest(unittest.TestCase):
    def test_reads_price_rendered_by_javascript(self):
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), _Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        url = f"http://127.0.0.1:{server.server_address[1]}/product/1"
        try:
            plain = list(crawl_site({"name": "T", "start_urls": [url], "delay": 0}))
            browser = list(crawl_site({"name": "T", "start_urls": [url], "delay": 0, "browser": True}))
        finally:
            server.shutdown()
        self.assertEqual(plain, [])  # vanlig henting ser ikke prisen
        self.assertEqual([(p.name, p.price) for p in browser], [("JS-TV", 4990.0)])


if __name__ == "__main__":
    unittest.main()
