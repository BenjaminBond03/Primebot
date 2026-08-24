import asyncio

from fastapi import APIRouter, Header, HTTPException

from app.config import get_settings
from app.models.schemas import RefreshResponse
from app.rag.indexer import rebuild_index
from app.scraper.crawler import crawl

router = APIRouter()


@router.post("/admin/refresh-index", response_model=RefreshResponse)
async def refresh_index(x_admin_token: str = Header(default="")) -> RefreshResponse:
    settings = get_settings()
    if x_admin_token != settings.admin_token:
        raise HTTPException(status_code=401, detail="Invalid admin token")

    pages = await asyncio.to_thread(crawl)
    count = await asyncio.to_thread(rebuild_index, pages)
    return RefreshResponse(pages_indexed=count)
