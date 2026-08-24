import os
import sqlite3

from app.config import get_settings


def get_connection() -> sqlite3.Connection:
    settings = get_settings()
    os.makedirs(os.path.dirname(settings.auth_db_path) or ".", exist_ok=True)
    conn = sqlite3.connect(settings.auth_db_path)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with get_connection() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL UNIQUE,
                email TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
