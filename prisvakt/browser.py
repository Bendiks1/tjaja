"""Henting med ekte nettleser (Playwright/Chromium) for butikker som krever JavaScript
eller blokkerer enkle HTTP-forespørsler. Valgfritt: krever `pip install playwright`
og `playwright install --with-deps chromium`.

Én nettleser kjører i en egen tråd med asyncio; kallere fra flere tråder får hver sin fane.
"""
import asyncio
import os
import threading
import urllib.error
from email.message import Message

from .crawler import UA, fetch

PAGE_TIMEOUT_MS = 45_000


class BrowserFetcher:
    def __init__(self, user_agent: str = UA):
        try:
            from playwright.async_api import async_playwright
        except ImportError as e:
            raise RuntimeError(
                "Playwright mangler. Installer med:\n"
                "  pip install playwright && playwright install --with-deps chromium") from e
        self._loop = asyncio.new_event_loop()
        self._thread = threading.Thread(target=self._loop.run_forever, daemon=True)
        self._thread.start()

        async def start():
            pw = await async_playwright().start()
            browser = await pw.chromium.launch(
                executable_path=os.environ.get("PRISVAKT_CHROMIUM") or None)
            ctx = await browser.new_context(user_agent=user_agent, locale="nb-NO")
            return pw, browser, ctx
        self._pw, self._browser, self._ctx = self._run(start())

    def _run(self, coro):
        return asyncio.run_coroutine_threadsafe(coro, self._loop).result()

    async def _fetch(self, url: str) -> str:
        if url.endswith((".xml", ".xml.gz")):  # sitemaps: rå tekst, ikke nettleserens XML-visning
            resp = await self._ctx.request.get(url, timeout=PAGE_TIMEOUT_MS)
            _raise_for_status(url, resp.status, resp.status_text, resp.headers)
            return await resp.text()
        page = await self._ctx.new_page()
        try:
            resp = await page.goto(url, wait_until="domcontentloaded", timeout=PAGE_TIMEOUT_MS)
            if resp is not None:
                _raise_for_status(url, resp.status, resp.status_text, resp.headers)
            try:  # gi JavaScript tid til å legge inn produktdata
                await page.wait_for_selector('script[type="application/ld+json"]',
                                             state="attached", timeout=8_000)
            except Exception:
                pass
            return await page.content()
        finally:
            await page.close()

    def __call__(self, url: str) -> str:
        if url.endswith((".xml", ".xml.gz")):
            try:  # sitemaps er rå XML; vanlig henting er raskere og blir sjeldnere stoppet
                return fetch(url)
            except Exception:
                pass
        return self._run(self._fetch(url))

    def close(self):
        async def stop():
            await self._ctx.close()
            await self._browser.close()
            await self._pw.stop()
        try:
            self._run(stop())
        finally:
            self._loop.call_soon_threadsafe(self._loop.stop)
            self._thread.join(timeout=10)


def _raise_for_status(url, status, text, headers):
    """Gjør feil om til HTTPError så crawlerens nedbremsing (429/503) virker likt."""
    if status >= 400:
        msg = Message()
        for k, v in (headers or {}).items():
            msg[k] = v
        raise urllib.error.HTTPError(url, status, text, msg, None)
