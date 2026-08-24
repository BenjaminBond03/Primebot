from dataclasses import dataclass
from urllib.parse import urljoin, urlparse

from bs4 import BeautifulSoup

STRIP_TAGS = ["script", "style", "nav", "header", "footer", "aside", "form", "noscript"]


@dataclass
class PageDocument:
    url: str
    title: str
    text: str


def parse_html(html: str, url: str) -> PageDocument:
    soup = BeautifulSoup(html, "lxml")

    title_tag = soup.find("title")
    title = title_tag.get_text(strip=True) if title_tag else url

    for tag in soup.find_all(STRIP_TAGS):
        tag.decompose()

    main = soup.find("main") or soup.find(attrs={"role": "main"}) or soup.body or soup
    text = main.get_text(separator="\n", strip=True)
    text = "\n".join(line for line in text.splitlines() if line.strip())

    return PageDocument(url=url, title=title, text=text)


def extract_links(html: str, base_url: str) -> list[str]:
    soup = BeautifulSoup(html, "lxml")
    domain = urlparse(base_url).netloc
    links: set[str] = set()

    for a in soup.find_all("a", href=True):
        absolute = urljoin(base_url, a["href"]).split("#")[0]
        parsed = urlparse(absolute)
        if parsed.netloc == domain and parsed.scheme in ("http", "https"):
            links.add(absolute.rstrip("/"))

    return list(links)
