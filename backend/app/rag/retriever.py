from dataclasses import dataclass

from app.rag.indexer import get_collection


@dataclass
class Source:
    url: str
    title: str


@dataclass
class RetrievedChunk:
    text: str
    source: Source
    distance: float


def retrieve(query: str, k: int = 5) -> list[RetrievedChunk]:
    collection = get_collection()
    count = collection.count()
    if count == 0:
        return []

    results = collection.query(query_texts=[query], n_results=min(k, count))

    documents = results.get("documents") or [[]]
    metadatas = results.get("metadatas") or [[]]
    distances = results.get("distances") or [[]]

    chunks: list[RetrievedChunk] = []
    for doc, meta, dist in zip(documents[0], metadatas[0], distances[0]):
        chunks.append(
            RetrievedChunk(text=doc, source=Source(url=meta["url"], title=meta["title"]), distance=dist)
        )

    return chunks


def dedupe_sources(chunks: list[RetrievedChunk]) -> list[Source]:
    seen: set[str] = set()
    sources: list[Source] = []

    for chunk in chunks:
        if chunk.source.url not in seen:
            seen.add(chunk.source.url)
            sources.append(chunk.source)

    return sources
