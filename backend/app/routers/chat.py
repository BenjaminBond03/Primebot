from fastapi import APIRouter

from app.llm.groq_client import build_context, build_web_context, generate_answer
from app.models.schemas import ChatRequest, ChatResponse, ChatTurn, SourceOut
from app.rag.retriever import RetrievedChunk, Source, dedupe_sources, retrieve
from app.scraper.news import get_latest_news
from app.search.duckduckgo import web_search

router = APIRouter()

# Bound conversation length server-side regardless of what the client sends,
# to keep prompt size/cost predictable.
MAX_HISTORY_TURNS = 10

# Chroma L2 distance for the closest retrieved chunk, above which it's too
# dissimilar to trust. Calibrated against this collection: in-scope UTAS
# queries scored 0.33-0.59, genuinely unrelated ones scored 0.64-0.87. Note
# this is a similarity heuristic, not a topic classifier - a query that's
# topically adjacent but about a different institution (e.g. "admission
# requirements for Harvard") can still score low enough to leak through.
RELEVANCE_DISTANCE_THRESHOLD = 0.60

NEWS_KEYWORDS = {
    "news",
    "announcement",
    "announcements",
    "latest",
    "deadline",
    "event",
    "events",
    "update",
    "updates",
    "today",
}


def is_news_query(message: str) -> bool:
    lowered = message.lower()
    return any(keyword in lowered for keyword in NEWS_KEYWORDS)


def build_retrieval_query(message: str, history: list[ChatTurn]) -> str:
    """Fold the previous user turn into the retrieval query so short follow-ups
    ("what about mature applicants?") still match the right chunks - the
    vector search only sees this string, not the full conversation."""
    prior_user_turns = [turn.content for turn in history if turn.role == "user"]
    if not prior_user_turns:
        return message
    return f"{prior_user_turns[-1]}\n{message}"


def is_in_scope(chunks: list[RetrievedChunk]) -> bool:
    return any(chunk.distance <= RELEVANCE_DISTANCE_THRESHOLD for chunk in chunks)


@router.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest) -> ChatResponse:
    history = request.history[-MAX_HISTORY_TURNS:]
    retrieval_query = build_retrieval_query(request.message, history)

    chunks = retrieve(retrieval_query)
    news_document = get_latest_news() if is_news_query(request.message) else None

    sources: list[Source]
    if news_document is not None or is_in_scope(chunks):
        context = build_context(chunks, news_document)
        sources = dedupe_sources(chunks)
        if news_document is not None and not any(s.url == news_document.url for s in sources):
            sources.append(Source(url=news_document.url, title=news_document.title))
    else:
        web_results = web_search(retrieval_query)
        context = build_web_context(web_results)
        sources = [r.source for r in web_results]

    answer = generate_answer(request.message, context, history)

    return ChatResponse(
        answer=answer,
        sources=[SourceOut(url=s.url, title=s.title) for s in sources],
    )
