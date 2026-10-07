"""Henter produkter og lenker ut fra HTML (schema.org JSON-LD, med meta-tag fallback)."""
import json
import re
from dataclasses import dataclass
from html.parser import HTMLParser
from urllib.parse import urljoin, urldefrag


@dataclass
class Product:
    url: str
    name: str
    price: float
    currency: str = "NOK"
    was_price: float | None = None  # "før-pris" hvis siden oppgir den


class _Parser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.jsonld: list[str] = []
        self.links: list[str] = []
        self.meta: dict[str, str] = {}
        self._in_jsonld = False
        self._buf: list[str] = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "script" and (a.get("type") or "").lower() == "application/ld+json":
            self._in_jsonld, self._buf = True, []
        elif tag == "a" and a.get("href"):
            self.links.append(a["href"])
        elif tag == "meta":
            key = a.get("property") or a.get("name") or a.get("itemprop")
            if key and a.get("content") is not None:
                self.meta[key] = a["content"]

    def handle_data(self, data):
        if self._in_jsonld:
            self._buf.append(data)

    def handle_endtag(self, tag):
        if tag == "script" and self._in_jsonld:
            self.jsonld.append("".join(self._buf))
            self._in_jsonld = False


def parse_price(value) -> float | None:
    """Tåler 1299, '1 299,-', '1.299,00', '1299.90'."""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    s = re.sub(r"[^\d,.]", "", str(value))
    if not s:
        return None
    if "," in s and "." in s:
        # Siste skilletegn er desimal.
        dec = "," if s.rfind(",") > s.rfind(".") else "."
        s = s.replace("," if dec == "." else ".", "").replace(dec, ".")
    elif "," in s:
        head, _, tail = s.rpartition(",")
        s = head.replace(",", "") + ("." + tail if len(tail) != 3 else tail)
    elif s.count(".") > 1 or re.fullmatch(r"\d{1,3}\.\d{3}", s):
        s = s.replace(".", "")
    try:
        return float(s)
    except ValueError:
        return None


def _walk(node):
    if isinstance(node, list):
        for n in node:
            yield from _walk(n)
    elif isinstance(node, dict):
        yield node
        for v in node.values():
            if isinstance(v, (dict, list)):
                yield from _walk(v)


def _types(node: dict) -> list[str]:
    t = node.get("@type", [])
    return [t] if isinstance(t, str) else list(t)


def _offers(offers):
    """Flater ut Offer/AggregateOffer til enkelt-tilbud (uten å gå inn i priceSpecification)."""
    for o in offers if isinstance(offers, list) else [offers]:
        if isinstance(o, dict):
            if "offers" in o:
                yield from _offers(o["offers"])
            yield o


def _is_consumer_offer(o: dict) -> bool:
    """Hopper over bedriftspriser / priser uten mva (f.eks. Elkjøp 'Business Price')."""
    ect = o.get("eligibleCustomerType")
    ect_id = ect.get("@id", "") if isinstance(ect, dict) else str(ect or "")
    if ect_id.rstrip("/").lower().endswith("business") or "excl" in str(o.get("name", "")).lower():
        return False
    specs = o.get("priceSpecification")
    specs = specs if isinstance(specs, list) else [specs] if specs else []
    if any(isinstance(sp, dict) and sp.get("valueAddedTaxIncluded") is False
           and parse_price(sp.get("price")) == parse_price(o.get("price")) for sp in specs):
        return False
    return True


def _offer_prices(offers) -> tuple[float | None, float | None, str]:
    """Returnerer (laveste forbrukerpris, høyeste oppgitte før-pris, valuta)."""
    prices, was, cur = [], [], "NOK"
    for o in _offers(offers):
        if not _is_consumer_offer(o):
            continue
        p = parse_price(o.get("price", o.get("lowPrice")))
        if p is not None and p > 0:
            prices.append(p)
            cur = o.get("priceCurrency") or cur
        specs = o.get("priceSpecification")
        for sp in _walk(specs) if specs else []:
            sp_price = parse_price(sp.get("price"))
            kind = str(sp.get("priceType", "")).lower()
            if sp_price and ("list" in kind or "strikethrough" in kind or "msrp" in kind):
                was.append(sp_price)
    return (min(prices) if prices else None), (max(was) if was else None), cur


def extract_products(html: str, page_url: str) -> list[Product]:
    parser = _Parser()
    parser.feed(html)
    found: dict[str, Product] = {}
    for raw in parser.jsonld:
        try:
            data = json.loads(raw)
        except ValueError:
            continue
        for node in _walk(data):
            if "Product" not in _types(node) or "offers" not in node:
                continue
            price, was, cur = _offer_prices(node["offers"])
            name = node.get("name")
            if price is None or not name:
                continue
            url = urldefrag(urljoin(page_url, node.get("url") or page_url))[0]
            found[url] = Product(url, str(name).strip(), price, cur, was)
    if not found:  # Open Graph / itemprop fallback
        m = parser.meta
        price = parse_price(m.get("product:price:amount") or m.get("price"))
        name = m.get("og:title")
        if price and name:
            url = m.get("og:url") or page_url
            found[url] = Product(url, name.strip(), price,
                                 m.get("product:price:currency", "NOK"))
    return list(found.values())


def extract_links(html: str, page_url: str) -> list[str]:
    parser = _Parser()
    parser.feed(html)
    return [urldefrag(urljoin(page_url, h))[0] for h in parser.links
            if not h.startswith(("mailto:", "javascript:", "tel:"))]


def extract_sitemap_urls(xml: str) -> tuple[list[str], list[str]]:
    """Returnerer (sidelenker, under-sitemaps)."""
    is_index = "<sitemapindex" in xml
    locs = [u.strip() for u in re.findall(r"<loc>\s*(.*?)\s*</loc>", xml, re.S)]
    return ([], locs) if is_index else (locs, [])
