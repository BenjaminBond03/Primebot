from groq import Groq

from app.config import get_settings
from app.models.schemas import ChatTurn
from app.rag.retriever import RetrievedChunk
from app.scraper.parser import PageDocument
from app.search.duckduckgo import WebResult

_client: Groq | None = None


def _get_client() -> Groq:
    global _client
    if _client is None:
        _client = Groq(api_key=get_settings().groq_api_key)
    return _client


SYSTEM_PROMPT = """You are PrimeBot, the AI support assistant for C. K. Tedam University of Technology and Applied Sciences (CKT-UTAS), Navrongo, Ghana - refer to it as "UTAS" or "CKT-UTAS" consistently, never any other name (e.g. not "University of Applied Science" or "UDS").
Answer student questions using ONLY the CONTEXT provided below, which was scraped from the official UTAS website (utas.edu.gh).

Rules:
- Be warm, concise, and conversational - you're talking to a student, not writing a report.
- Every factual claim must be grounded in the CONTEXT. Cite the source inline as a markdown link, e.g. [Admissions Office](https://utas.edu.gh/admissions/).
- If the CONTEXT does not contain the answer, say so honestly and suggest the student check the official UTAS website or contact the relevant office directly. Never invent information.
- Do not mention "the context" explicitly to the user - just answer naturally with the citations woven in.
- Use the earlier turns in this conversation to resolve follow-ups ("what about X", "and for mature applicants?"), but still ground every new factual claim in the CONTEXT given with the latest question - earlier answers are not a substitute for it.
- Never use markdown tables - the chat renders in a narrow mobile bubble where tables get squeezed unreadably. Use short paragraphs, bullet points, or bold labels (e.g. "**Age:** ...") instead of a table's rows/columns.
- If the CONTEXT is marked WEB SEARCH RESULTS instead of the UTAS website, say plainly that this isn't official UTAS information (e.g. "This isn't on the UTAS site, but here's what I found:") before answering, and still cite sources.
"""


def build_context(chunks: list[RetrievedChunk], news_document: PageDocument | None = None) -> str:
    parts = [f"Source: {chunk.source.title} ({chunk.source.url})\n{chunk.text}" for chunk in chunks]

    if news_document is not None:
        parts.append(f"Source: {news_document.title} ({news_document.url})\n{news_document.text[:1500]}")

    return "\n\n---\n\n".join(parts) if parts else "No relevant information was found on the UTAS website."


def build_web_context(results: list[WebResult]) -> str:
    if not results:
        return "No relevant information was found via web search either."

    parts = [f"Source: {r.source.title} ({r.source.url})\n{r.text}" for r in results]
    return "WEB SEARCH RESULTS (not from utas.edu.gh):\n\n" + "\n\n---\n\n".join(parts)


def generate_answer(query: str, context: str, history: list[ChatTurn] | None = None) -> str:
    settings = get_settings()
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    messages.extend({"role": turn.role, "content": turn.content} for turn in history or [])
    messages.append({"role": "user", "content": f"CONTEXT:\n{context}\n\nSTUDENT QUESTION: {query}"})

    completion = _get_client().chat.completions.create(
        model=settings.groq_model,
        messages=messages,
        temperature=0.3,
        max_tokens=450,
    )

    return completion.choices[0].message.content or ""
