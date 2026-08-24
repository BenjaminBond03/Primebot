import sqlite3

import bcrypt

from app.auth.db import get_connection


class UsernameTakenError(Exception):
    pass


class EmailTakenError(Exception):
    pass


class InvalidCredentialsError(Exception):
    pass


class UserNotFoundError(Exception):
    pass


def _hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def _verify_password(password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))


def create_user(username: str, email: str, password: str) -> dict:
    password_hash = _hash_password(password)

    with get_connection() as conn:
        try:
            cursor = conn.execute(
                "INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)",
                (username, email.lower(), password_hash),
            )
        except sqlite3.IntegrityError as exc:
            message = str(exc)
            if "users.username" in message:
                raise UsernameTakenError from exc
            if "users.email" in message:
                raise EmailTakenError from exc
            raise

        return {"id": cursor.lastrowid, "username": username, "email": email.lower()}


def authenticate_user(email: str, password: str) -> dict:
    with get_connection() as conn:
        row = conn.execute(
            "SELECT id, username, email, password_hash FROM users WHERE email = ?",
            (email.lower(),),
        ).fetchone()

    if row is None or not _verify_password(password, row["password_hash"]):
        raise InvalidCredentialsError

    return {"id": row["id"], "username": row["username"], "email": row["email"]}


def update_profile(user_id: int, username: str, email: str) -> dict:
    with get_connection() as conn:
        try:
            cursor = conn.execute(
                "UPDATE users SET username = ?, email = ? WHERE id = ?",
                (username, email.lower(), user_id),
            )
        except sqlite3.IntegrityError as exc:
            message = str(exc)
            if "users.username" in message:
                raise UsernameTakenError from exc
            if "users.email" in message:
                raise EmailTakenError from exc
            raise

        if cursor.rowcount == 0:
            raise UserNotFoundError

        return {"id": user_id, "username": username, "email": email.lower()}


def change_password(user_id: int, current_password: str, new_password: str) -> None:
    with get_connection() as conn:
        row = conn.execute(
            "SELECT password_hash FROM users WHERE id = ?", (user_id,)
        ).fetchone()

        if row is None:
            raise UserNotFoundError
        if not _verify_password(current_password, row["password_hash"]):
            raise InvalidCredentialsError

        conn.execute(
            "UPDATE users SET password_hash = ? WHERE id = ?",
            (_hash_password(new_password), user_id),
        )
