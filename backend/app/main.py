import asyncio
import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.auth.db import init_db
from app.config import get_settings
from app.rag.indexer import index_is_empty, rebuild_index
from app.routers import admin, auth, chat
from app.scheduler import create_scheduler
from app.scraper.crawler import crawl

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    os.makedirs(settings.chroma_dir, exist_ok=True)
    await asyncio.to_thread(init_db)

    if await asyncio.to_thread(index_is_empty):
        logger.info("Index is empty, running initial crawl (this may take a while)...")
        pages = await asyncio.to_thread(crawl)
        count = await asyncio.to_thread(rebuild_index, pages)
        logger.info("Initial crawl indexed %d pages", count)

    scheduler = create_scheduler()
    scheduler.start()
    app.state.scheduler = scheduler

    yield

    scheduler.shutdown()


app = FastAPI(title="PrimeBot UTAS Assistant", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(chat.router)
app.include_router(admin.router)
app.include_router(auth.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
