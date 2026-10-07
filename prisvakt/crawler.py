import gzip
import re
import time
import urllib.request
from collections import deque
from urllib.parse import urlparse

from .extract import extract_links, extract_products, extract_sitemap_urls

UA = "Mozilla/5.0 (compatible; Prisvakt/1.0; personlig prissjekk)"


def fetch(url: str, timeout: int = 20) -> str:
    req = urllib.request.Request(url, headers={
        "User-Agent": UA, "Accept-Encoding": "gzip", "Accept-Language": "nb-NO,nb;q=0.9"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        body = r.read()
        if r.headers.get("Content-Encoding") == "gzip" or body[:2] == b"\x1f\x8b":
            body = gzip.decompress(body)
        return body.decode(r.headers.get_content_charset() or "utf-8", "replace")


def crawl_site(site: dict, fetcher=fetch, sleep=time.sleep):
    """Generator som gir Product for hver vare funnet.

    site: name, start_urls (kategorisider eller sitemap .xml), max_pages,
          delay (sek), link_pattern (regex for lenker som skal følges).
    """
    host = urlparse(site["start_urls"][0]).netloc
    pattern = re.compile(site["link_pattern"]) if site.get("link_pattern") else None
    queue, seen = deque(site["start_urls"]), set(site["start_urls"])
    pages = 0
    while queue and pages < site.get("max_pages", 200):
        url = queue.popleft()
        pages += 1
        try:
            body = fetcher(url)
        except Exception as e:  # blokkert, 404, timeout – gå videre
            print(f"  [{site['name']}] feil {url}: {e}")
            continue
        if url.endswith((".xml", ".xml.gz")) or "<urlset" in body[:500] or "<sitemapindex" in body[:500]:
            pages_, subs = extract_sitemap_urls(body)
            links = subs + [u for u in pages_ if not pattern or pattern.search(u)]
        else:
            yield from extract_products(body, url)
            links = [u for u in extract_links(body, url)
                     if urlparse(u).netloc == host and (not pattern or pattern.search(u))]
        for u in links:
            if u not in seen:
                seen.add(u)
                queue.append(u)
        sleep(site.get("delay", 2))
