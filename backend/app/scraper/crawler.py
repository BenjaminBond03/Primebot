import time
import urllib.robotparser as robotparser
from urllib.parse import urljoin, urlparse
from xml.etree import ElementTree

import httpx

from app.config import get_settings
from app.scraper.parser import PageDocument, extract_links, parse_html

_ROBOTS_CACHE: robotparser.RobotFileParser | None = None
_SITEMAP_NS = "{http://www.sitemaps.org/schemas/sitemap/0.9}"


def _headers() -> dict[str, str]:
    settings = get_settings()
    return {
        "User-Agent": f"PrimeBot-UTAS-Assistant/1.0 (+contact: {settings.contact_email})",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
    }


def get_robot_parser() -> robotparser.RobotFileParser:
    global _ROBOTS_CACHE
    if _ROBOTS_CACHE is None:
        settings = get_settings()
        rp = robotparser.RobotFileParser()
        rp.set_url(urljoin(settings.site_base_url, "/robots.txt"))
        rp.read()
        _ROBOTS_CACHE = rp
    return _ROBOTS_CACHE


def can_fetch(url: str) -> bool:
    return get_robot_parser().can_fetch("*", url)


def _get(client: httpx.Client, url: str) -> httpx.Response | None:
    try:
        resp = client.get(url, headers=_headers(), timeout=15, follow_redirects=True)
        if resp.status_code == 200:
            return resp
    except httpx.HTTPError:
        return None
    return None


def fetch_page(client: httpx.Client, url: str) -> httpx.Response | None:
    resp = _get(client, url)
    if resp is not None and "html" in resp.headers.get("content-type", ""):
        return resp
    return None


def _fetch_xml_locs(client: httpx.Client, url: str) -> list[str]:
    resp = _get(client, url)
    if resp is None:
        return []
    try:
        root = ElementTree.fromstring(resp.text)
    except ElementTree.ParseError:
        return []
    return [loc.text.strip() for loc in root.iter(f"{_SITEMAP_NS}loc") if loc.text]


def discover_urls_from_sitemap(client: httpx.Client) -> list[str]:
    settings = get_settings()
    sitemap_index = urljoin(settings.site_base_url, "/sitemap_index.xml")
    sub_sitemaps = _fetch_xml_locs(client, sitemap_index)
    if not sub_sitemaps:
        return []

    urls: list[str] = []
    seen: set[str] = set()
    for sub_sitemap in sub_sitemaps:
        if "category-sitemap" in sub_sitemap:
            continue  # category archive pages add little unique content over the posts themselves
        for loc in _fetch_xml_locs(client, sub_sitemap):
            clean = loc.rstrip("/")
            if clean not in seen:
                seen.add(clean)
                urls.append(clean)

    return urls


def _bfs_discover(client: httpx.Client, seed_url: str, max_depth: int) -> list[str]:
    settings = get_settings()
    domain = urlparse(seed_url).netloc
    visited: set[str] = set()
    queue: list[tuple[str, int]] = [(seed_url.rstrip("/"), 0)]
    ordered: list[str] = []

    while queue and len(ordered) < settings.crawl_max_pages:
        url, depth = queue.pop(0)
        if url in visited or depth > max_depth or not can_fetch(url):
            continue
        visited.add(url)

        resp = fetch_page(client, url)
        time.sleep(settings.crawl_delay_seconds)
        if resp is None:
            continue

        ordered.append(url)
        if depth < max_depth:
            for link in extract_links(resp.text, url):
                if urlparse(link).netloc == domain and link not in visited:
                    queue.append((link, depth + 1))

    return ordered


def crawl() -> list[PageDocument]:
    settings = get_settings()
    documents: list[PageDocument] = []

    with httpx.Client() as client:
        urls = discover_urls_from_sitemap(client)
        if not urls:
            urls = _bfs_discover(client, settings.site_base_url, settings.crawl_max_depth)

        for url in urls[: settings.crawl_max_pages]:
            if not can_fetch(url):
                continue
            resp = fetch_page(client, url)
            if resp is not None:
                documents.append(parse_html(resp.text, url))
            time.sleep(settings.crawl_delay_seconds)

    return documents
