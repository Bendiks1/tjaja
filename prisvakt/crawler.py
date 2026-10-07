import gzip
import re
import threading
import time
import urllib.error
import urllib.request
from collections import deque
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
from urllib.parse import urlparse

from .extract import extract_links, extract_products, extract_sitemap_urls

UA = "Mozilla/5.0 (compatible; Prisvakt/1.0; personlig prissjekk)"
MAX_DELAY = 60  # sek, øvre grense ved nedbremsing
MAX_RETRIES = 3  # per URL ved 429/503
GIVE_UP_AFTER = 25  # avbryt butikken etter så mange feil på rad (trolig blokkert)


def fetch(url: str, timeout: int = 20) -> str:
    req = urllib.request.Request(url, headers={
        "User-Agent": UA, "Accept-Encoding": "gzip", "Accept-Language": "nb-NO,nb;q=0.9"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        body = r.read()
        if r.headers.get("Content-Encoding") == "gzip" or body[:2] == b"\x1f\x8b":
            body = gzip.decompress(body)
        return body.decode(r.headers.get_content_charset() or "utf-8", "replace")


class Throttle:
    """Minste tid mellom hver forespørsel mot én butikk, delt mellom trådene.

    Ved 429/503 dobles pausen (og Retry-After respekteres); ved suksess
    går den gradvis tilbake mot det konfigurerte nivået.
    """

    def __init__(self, delay: float, sleep=time.sleep, clock=time.monotonic):
        self.base = self.delay = delay
        self._sleep, self._clock = sleep, clock
        self._lock = threading.Lock()
        self._next = 0.0

    def wait(self):
        with self._lock:
            now = self._clock()
            start = max(now, self._next)
            self._next = start + self.delay
        if start > now:
            self._sleep(start - now)

    def slow_down(self, retry_after: float = 0):
        with self._lock:
            self.delay = min(MAX_DELAY, max(self.delay * 2, 0.5, retry_after))
            self._next = self._clock() + max(self.delay, retry_after)
            return self.delay

    def ok(self):
        with self._lock:
            self.delay = max(self.base, self.delay * 0.95)


def _retry_after(e: urllib.error.HTTPError) -> float:
    try:
        return float(e.headers.get("Retry-After", 0))
    except (TypeError, ValueError):
        return 0


def crawl_site(site: dict, fetcher=fetch, sleep=time.sleep):
    """Generator som gir Product for hver vare funnet.

    site: name, start_urls (kategorisider eller sitemap .xml), max_pages (0 = alle),
          concurrency (samtidige forespørsler), delay (minste sek mellom forespørsler),
          link_pattern (regex for lenker som skal følges).
    """
    name = site["name"]
    host = urlparse(site["start_urls"][0]).netloc
    pattern = re.compile(site["link_pattern"]) if site.get("link_pattern") else None
    throttle = Throttle(site.get("delay", 0.5), sleep)
    queue, seen = deque(site["start_urls"]), set(site["start_urls"])
    retries: dict[str, int] = {}
    pages, limit = 0, site.get("max_pages", 200)  # 0 = ingen grense
    failures = 0
    started = time.monotonic()

    def get(url):
        throttle.wait()
        try:
            return fetcher(url), None
        except Exception as e:
            return None, e

    workers = max(1, site.get("concurrency", 4))
    with ThreadPoolExecutor(workers) as pool:
        running = {}
        while queue or running:
            while queue and len(running) < workers and (not limit or pages < limit):
                url = queue.popleft()
                pages += 1
                running[pool.submit(get, url)] = url
            if not running:
                break
            done, _ = wait(running, return_when=FIRST_COMPLETED)
            for fut in done:
                url = running.pop(fut)
                body, err = fut.result()
                if err is not None:
                    code = getattr(err, "code", None)
                    if code not in (404, 410):  # fjernet vare er ikke tegn på blokkering
                        failures += 1
                    if code in (429, 503) and retries.get(url, 0) < MAX_RETRIES:
                        retries[url] = retries.get(url, 0) + 1
                        delay = throttle.slow_down(_retry_after(err))
                        print(f"  [{name}] {code} – butikken ber oss roe ned, pause nå {delay:.1f}s")
                        queue.appendleft(url)
                        pages -= 1
                    else:
                        print(f"  [{name}] feil {url}: {err}")
                    if failures >= GIVE_UP_AFTER:
                        print(f"  [{name}] {failures} feil på rad – trolig blokkert, avbryter denne butikken")
                        for f in running:
                            f.cancel()
                        return
                    continue
                failures = 0
                throttle.ok()
                if url.endswith((".xml", ".xml.gz")) or "<urlset" in body[:500] or "<sitemapindex" in body[:500]:
                    page_urls, subs = extract_sitemap_urls(body)
                    links = subs + [u for u in page_urls if not pattern or pattern.search(u)]
                else:
                    yield from extract_products(body, url)
                    links = [u for u in extract_links(body, url)
                             if urlparse(u).netloc == host and (not pattern or pattern.search(u))]
                for u in links:
                    if u not in seen:
                        seen.add(u)
                        queue.append(u)
    secs = time.monotonic() - started
    print(f"  [{name}] {pages} sider på {secs:.0f}s ({pages / max(secs, 1e-9):.1f} sider/s)")
