from typing import Literal

from pydantic import BaseModel


class ChatTurn(BaseModel):
    role: Literal["user", "assistant"]
    content: str


class ChatRequest(BaseModel):
    message: str
    history: list[ChatTurn] = []


class SourceOut(BaseModel):
    url: str
    title: str


class ChatResponse(BaseModel):
    answer: str
    sources: list[SourceOut]


class RefreshResponse(BaseModel):
    pages_indexed: int


class SignupRequest(BaseModel):
    username: str
    email: str
    password: str


class LoginRequest(BaseModel):
    email: str
    password: str


class AuthResponse(BaseModel):
    id: int
    username: str
    email: str


class UpdateProfileRequest(BaseModel):
    user_id: int
    username: str
    email: str


class ChangePasswordRequest(BaseModel):
    user_id: int
    current_password: str
    new_password: str
