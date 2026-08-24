import logging
from dataclasses import dataclass

from ddgs import DDGS
from ddgs.exceptions import DDGSException

from app.rag.retriever import Source

logger = logging.getLogger(__name__)


@dataclass
class WebResult:
    text: str
    source: Source


def web_search(query: str, max_results: int = 4) -> list[WebResult]:
    """Live DuckDuckGo search used as a fallback when the UTAS site has
    nothing relevant. Network calls to a third party, so failures (rate
    limits, connectivity) are swallowed - the chat should degrade to an
    honest "I don't know", not a 500."""
    try:
        results = DDGS().text(query, max_results=max_results)
    except DDGSException:
        logger.warning("DuckDuckGo search failed for query: %s", query, exc_info=True)
        return []

    return [
        WebResult(text=r["body"], source=Source(url=r["href"], title=r["title"]))
        for r in results
        if r.get("body") and r.get("href") and r.get("title")
    ]
