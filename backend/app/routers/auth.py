from fastapi import APIRouter, HTTPException

from app.auth.service import (
    EmailTakenError,
    InvalidCredentialsError,
    UsernameTakenError,
    UserNotFoundError,
    authenticate_user,
    change_password,
    create_user,
    update_profile,
)
from app.models.schemas import (
    AuthResponse,
    ChangePasswordRequest,
    LoginRequest,
    SignupRequest,
    UpdateProfileRequest,
)

router = APIRouter(prefix="/auth")


@router.post("/signup", response_model=AuthResponse)
def signup(request: SignupRequest) -> AuthResponse:
    username = request.username.strip()
    email = request.email.strip()

    if len(username) < 3:
        raise HTTPException(status_code=400, detail="Username must be at least 3 characters")
    if len(request.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    try:
        user = create_user(username, email, request.password)
    except UsernameTakenError:
        raise HTTPException(status_code=409, detail="That username is already taken")
    except EmailTakenError:
        raise HTTPException(status_code=409, detail="An account with that email already exists")

    return AuthResponse(**user)


@router.post("/login", response_model=AuthResponse)
def login(request: LoginRequest) -> AuthResponse:
    try:
        user = authenticate_user(request.email.strip(), request.password)
    except InvalidCredentialsError:
        raise HTTPException(status_code=401, detail="Incorrect email or password")

    return AuthResponse(**user)


@router.put("/profile", response_model=AuthResponse)
def edit_profile(request: UpdateProfileRequest) -> AuthResponse:
    username = request.username.strip()
    email = request.email.strip()

    if len(username) < 3:
        raise HTTPException(status_code=400, detail="Username must be at least 3 characters")

    try:
        user = update_profile(request.user_id, username, email)
    except UsernameTakenError:
        raise HTTPException(status_code=409, detail="That username is already taken")
    except EmailTakenError:
        raise HTTPException(status_code=409, detail="An account with that email already exists")
    except UserNotFoundError:
        raise HTTPException(status_code=404, detail="Account not found")

    return AuthResponse(**user)


@router.post("/change-password")
def edit_password(request: ChangePasswordRequest) -> dict[str, bool]:
    if len(request.new_password) < 6:
        raise HTTPException(status_code=400, detail="New password must be at least 6 characters")

    try:
        change_password(request.user_id, request.current_password, request.new_password)
    except InvalidCredentialsError:
        raise HTTPException(status_code=401, detail="Current password is incorrect")
    except UserNotFoundError:
        raise HTTPException(status_code=404, detail="Account not found")

    return {"success": True}
