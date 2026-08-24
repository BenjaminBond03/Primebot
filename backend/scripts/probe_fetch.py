"""Standalone probe: check whether utas.edu.gh can be fetched with a plain HTTP client
before building the full crawler. Run with: python scripts/probe_fetch.py
"""
import httpx

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}

URLS = [
    "https://utas.edu.gh/",
    "https://utas.edu.gh/robots.txt",
    "https://utas.edu.gh/sitemap_index.xml",
]

for url in URLS:
    try:
        resp = httpx.get(url, headers=HEADERS, timeout=15, follow_redirects=True)
        print(f"{url} -> {resp.status_code} ({len(resp.text)} bytes)")
        if resp.status_code != 200:
            print(f"  body preview: {resp.text[:300]!r}")
    except Exception as e:
        print(f"{url} -> ERROR: {e}")
