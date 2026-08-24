from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    groq_api_key: str
    groq_model: str = "openai/gpt-oss-120b"

    contact_email: str = "oforikutin@gmail.com"
    site_base_url: str = "https://utas.edu.gh"

    crawl_max_depth: int = 3
    crawl_max_pages: int = 300
    crawl_delay_seconds: float = 1.0

    news_url: str = "https://utas.edu.gh/category/news/"
    news_cache_ttl_seconds: int = 900

    chroma_dir: str = "./data/chroma"
    admin_token: str = "changeme"

    auth_db_path: str = "./data/app.db"


@lru_cache
def get_settings() -> Settings:
    return Settings()
