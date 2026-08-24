import os

# The embedding model is downloaded once and cached locally; skip the Hugging Face
# Hub "check for updates" network call on every startup (it's a common source of
# flaky/closed-connection errors and isn't needed once the model is cached).
os.environ.setdefault("HF_HUB_OFFLINE", "1")
os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")

import chromadb
from chromadb.utils import embedding_functions

from app.config import get_settings
from app.scraper.parser import PageDocument

COLLECTION_NAME = "utas_pages"
EMBEDDING_MODEL_NAME = "all-MiniLM-L6-v2"

_client: chromadb.ClientAPI | None = None
_collection = None


def _get_client() -> chromadb.ClientAPI:
    global _client
    if _client is None:
        settings = get_settings()
        _client = chromadb.PersistentClient(path=settings.chroma_dir)
    return _client


def _embedding_function():
    return embedding_functions.SentenceTransformerEmbeddingFunction(model_name=EMBEDDING_MODEL_NAME)


def get_collection():
    global _collection
    if _collection is None:
        _collection = _get_client().get_or_create_collection(
            name=COLLECTION_NAME, embedding_function=_embedding_function()
        )
    return _collection


def index_is_empty() -> bool:
    return get_collection().count() == 0


def chunk_text(text: str, chunk_size: int = 800, overlap: int = 100) -> list[str]:
    paragraphs = [p.strip() for p in text.split("\n") if p.strip()]
    chunks: list[str] = []
    current = ""

    for para in paragraphs:
        if current and len(current) + len(para) + 1 > chunk_size:
            chunks.append(current)
            current = current[-overlap:] + "\n" + para if overlap else para
        else:
            current = f"{current}\n{para}" if current else para

    if current:
        chunks.append(current)

    return chunks


def rebuild_index(pages: list[PageDocument]) -> int:
    client = _get_client()

    try:
        client.delete_collection(COLLECTION_NAME)
    except Exception:
        pass

    global _collection
    _collection = client.get_or_create_collection(
        name=COLLECTION_NAME, embedding_function=_embedding_function()
    )

    documents: list[str] = []
    metadatas: list[dict[str, str]] = []
    ids: list[str] = []

    for page in pages:
        if not page.text.strip():
            continue
        for i, chunk in enumerate(chunk_text(page.text)):
            documents.append(chunk)
            metadatas.append({"url": page.url, "title": page.title})
            ids.append(f"{page.url}::{i}")

    batch_size = 100
    for start in range(0, len(documents), batch_size):
        _collection.add(
            documents=documents[start : start + batch_size],
            metadatas=metadatas[start : start + batch_size],
            ids=ids[start : start + batch_size],
        )

    return len(pages)
