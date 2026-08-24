import time

import httpx

from app.config import get_settings
from app.scraper.crawler import can_fetch, fetch_page
from app.scraper.parser import PageDocument, parse_html

_cache: dict[str, tuple[float, PageDocument]] = {}


def get_latest_news(force_refresh: bool = False) -> PageDocument | None:
    settings = get_settings()
    url = settings.news_url
    now = time.time()

    cached = _cache.get(url)
    if cached and not force_refresh and (now - cached[0]) < settings.news_cache_ttl_seconds:
        return cached[1]

    if not can_fetch(url):
        return cached[1] if cached else None

    with httpx.Client() as client:
        resp = fetch_page(client, url)

    if resp is None:
        return cached[1] if cached else None

    document = parse_html(resp.text, url)
    _cache[url] = (now, document)
    return document
