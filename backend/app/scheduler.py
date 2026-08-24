import asyncio
import logging

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger

from app.rag.indexer import rebuild_index
from app.scraper.crawler import crawl

logger = logging.getLogger(__name__)


async def full_reindex_job() -> None:
    try:
        pages = await asyncio.to_thread(crawl)
        count = await asyncio.to_thread(rebuild_index, pages)
        logger.info("Scheduled re-crawl indexed %d pages", count)
    except Exception:
        logger.exception("Scheduled re-crawl failed")


def create_scheduler() -> AsyncIOScheduler:
    scheduler = AsyncIOScheduler()
    scheduler.add_job(full_reindex_job, IntervalTrigger(days=1), id="daily_full_reindex")
    return scheduler
