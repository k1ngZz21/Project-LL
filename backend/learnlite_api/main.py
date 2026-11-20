from __future__ import annotations

import json
import os
import re
import sqlite3
import uuid
from contextlib import asynccontextmanager, contextmanager
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Literal
from urllib.parse import quote
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import httpx
from fastapi import Depends, FastAPI, File, HTTPException, Request, UploadFile
from fastapi.responses import Response
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


ROOT = Path(__file__).resolve().parents[1]
USERNAME_PATTERN = re.compile(r"^[A-Za-z0-9_]{3,30}$")
EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
MAX_UPLOAD_BYTES = 25 * 1024 * 1024
ALLOWED_RESOURCE_TYPES = {
    ".pdf": "application/pdf",
    ".mp3": "audio/mpeg",
    ".wav": "audio/wav",
    ".m4a": "audio/mp4",
    ".ogg": "audio/ogg",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".webp": "image/webp",
}


@dataclass(frozen=True)
class Settings:
    database_path: Path = field(
        default_factory=lambda: Path(
            os.getenv("LEARNLITE_DB_PATH", str(ROOT / "data" / "learnlite.sqlite3"))
        )
    )
    resource_dir: Path = field(
        default_factory=lambda: Path(
            os.getenv("LEARNLITE_RESOURCE_DIR", str(ROOT / "data" / "resources"))
        )
    )
    firebase_enabled: bool = field(
        default_factory=lambda: os.getenv("FIREBASE_ENABLED", "false").lower()
        in {"1", "true", "yes"}
    )
    firebase_admin_credentials: str | None = field(
        default_factory=lambda: os.getenv("FIREBASE_ADMIN_CREDENTIALS")
    )
    firebase_project_id: str | None = field(
        default_factory=lambda: os.getenv("FIREBASE_PROJECT_ID")
    )
    firebase_web_api_key: str | None = field(
        default_factory=lambda: os.getenv("FIREBASE_WEB_API_KEY")
    )
    firebase_admin_uids: frozenset[str] = field(
        default_factory=lambda: frozenset(
            item.strip()
            for item in os.getenv("FIREBASE_ADMIN_UIDS", "").split(",")
            if item.strip()
        )
    )
    ollama_base_url: str = field(
        default_factory=lambda: os.getenv(
            "OLLAMA_BASE_URL", "http://localhost:11434"
        ).rstrip("/")
    )
    ollama_model: str = field(
        default_factory=lambda: os.getenv("OLLAMA_MODEL", "qwen2.5:3b")
    )
    ollama_timeout_seconds: float = field(
        default_factory=lambda: float(os.getenv("OLLAMA_TIMEOUT_SECONDS", "90"))
    )
    reward_timezone: str = field(
        default_factory=lambda: os.getenv("REWARD_TIMEZONE", "UTC")
    )
    cors_origins: tuple[str, ...] = field(
        default_factory=lambda: tuple(
            value.strip()
            for value in os.getenv("CORS_ORIGINS", "").split(",")
            if value.strip()
        )
    )


class RegisterRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    full_name: str = Field(min_length=1, max_length=120)
    username: str = Field(min_length=3, max_length=30)
    email: str = Field(min_length=5, max_length=254)
    password: str = Field(min_length=10, max_length=256)
    learning_preference: Literal["Language", "Culture", "Both"]

    @field_validator("username")
    @classmethod
    def valid_username(cls, value: str) -> str:
        if not USERNAME_PATTERN.fullmatch(value):
            raise ValueError("Use 3 to 30 letters, numbers, or underscores.")
        return value

    @field_validator("email")
    @classmethod
    def valid_email(cls, value: str) -> str:
        value = value.lower()
        if not EMAIL_PATTERN.fullmatch(value):
            raise ValueError("Enter a valid email address.")
        return value

    @field_validator("password")
    @classmethod
    def strong_password(cls, value: str) -> str:
        if (
            not re.search(r"[a-z]", value)
            or not re.search(r"[A-Z]", value)
            or not re.search(r"\d", value)
        ):
            raise ValueError("Use uppercase, lowercase, and a number.")
        return value


class LoginRequest(BaseModel):
    username: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=1, max_length=256)


class AvatarUpdate(BaseModel):
    nickname: str | None = Field(default=None, max_length=40)
    avatar_id: str | None = Field(default=None, max_length=80)
    outfit_color: str | None = Field(default=None, max_length=40)
    avatar_completed: bool = False


class QuizQuestionInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    question: str = Field(min_length=1, max_length=1000)
    choices: list[str] = Field(min_length=2, max_length=6)
    correct_answer_index: int = Field(ge=0)
    explanation: str | None = Field(default=None, max_length=2000)

    @model_validator(mode="after")
    def answer_index_exists(self) -> "QuizQuestionInput":
        if self.correct_answer_index >= len(self.choices):
            raise ValueError("The correct answer index must refer to a choice.")
        return self


class LessonInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    title: str = Field(min_length=1, max_length=160)
    content: str = Field(min_length=1, max_length=20000)
    phrase: str | None = Field(default=None, max_length=500)
    pronunciation: str | None = Field(default=None, max_length=500)
    audio_url: str | None = Field(default=None, max_length=2048)
    image_url: str | None = Field(default=None, max_length=2048)
    cultural_note: str | None = Field(default=None, max_length=4000)
    keywords: list[str] = Field(default_factory=list, max_length=30)
    quiz: list[QuizQuestionInput] = Field(default_factory=list, max_length=100)


class ModuleInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    title: str = Field(min_length=1, max_length=160)
    description: str = Field(min_length=1, max_length=4000)
    lessons: list[LessonInput] = Field(min_length=1, max_length=500)


class PublicationUpdate(BaseModel):
    is_published: bool


class QuizSubmission(BaseModel):
    answers: list[int] = Field(max_length=100)


class DictionaryInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    subanen_word: str = Field(min_length=1, max_length=300)
    english_translation: str = Field(min_length=1, max_length=1000)
    bisaya_translation: str | None = Field(default=None, max_length=1000)
    definition: str | None = Field(default=None, max_length=2000)
    example_sentence: str | None = Field(default=None, max_length=2000)
    pronunciation: str | None = Field(default=None, max_length=500)
    module: str | None = Field(default=None, max_length=160)
    topic: str | None = Field(default=None, max_length=160)
    source: str | None = Field(default=None, max_length=1000)
    audio_url: str | None = Field(default=None, max_length=2048)
    is_verified: bool = False
    is_active: bool = True


SCHEMA = """
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS learners (
    uid TEXT PRIMARY KEY,
    username TEXT NOT NULL COLLATE NOCASE UNIQUE,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL COLLATE NOCASE UNIQUE,
    learning_preference TEXT NOT NULL,
    nickname TEXT,
    avatar_id TEXT,
    outfit_color TEXT,
    avatar_completed INTEGER NOT NULL DEFAULT 0,
    xp INTEGER NOT NULL DEFAULT 0 CHECK (xp >= 0),
    created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS modules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    lessons_json TEXT NOT NULL,
    is_published INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS lesson_progress (
    uid TEXT NOT NULL REFERENCES learners(uid) ON DELETE CASCADE,
    module_id INTEGER NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
    lesson_index INTEGER NOT NULL CHECK (lesson_index >= 0),
    started_at TEXT,
    completed_at TEXT,
    PRIMARY KEY (uid, module_id, lesson_index)
);
CREATE TABLE IF NOT EXISTS quiz_attempts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uid TEXT NOT NULL REFERENCES learners(uid) ON DELETE CASCADE,
    module_id INTEGER NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
    lesson_index INTEGER NOT NULL,
    score INTEGER NOT NULL,
    total_questions INTEGER NOT NULL,
    result_json TEXT NOT NULL,
    completed_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS dictionary_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    subanen_word TEXT NOT NULL,
    english_translation TEXT NOT NULL,
    bisaya_translation TEXT,
    definition TEXT,
    example_sentence TEXT,
    pronunciation TEXT,
    module TEXT,
    topic TEXT,
    source TEXT,
    audio_url TEXT,
    is_verified INTEGER NOT NULL DEFAULT 0,
    is_active INTEGER NOT NULL DEFAULT 1,
    review_status TEXT NOT NULL DEFAULT 'pending_review',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS resources (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    media_type TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    path TEXT NOT NULL,
    created_at TEXT NOT NULL,
    module_id INTEGER,
    lesson_index INTEGER,
    vocabulary_id INTEGER
);
CREATE TABLE IF NOT EXISTS certificates (
    certificate_id TEXT PRIMARY KEY,
    uid TEXT NOT NULL REFERENCES learners(uid) ON DELETE CASCADE,
    module_id INTEGER NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
    issued_at TEXT NOT NULL,
    UNIQUE(uid, module_id)
);
CREATE TABLE IF NOT EXISTS reward_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uid TEXT NOT NULL REFERENCES learners(uid) ON DELETE CASCADE,
    event_key TEXT NOT NULL,
    xp INTEGER NOT NULL CHECK (xp > 0),
    created_at TEXT NOT NULL,
    UNIQUE(uid, event_key)
);
CREATE TABLE IF NOT EXISTS offline_events (
    event_id TEXT PRIMARY KEY,
    uid TEXT NOT NULL REFERENCES learners(uid) ON DELETE CASCADE,
    module_id INTEGER NOT NULL,
    lesson_index INTEGER NOT NULL,
    completed_at TEXT NOT NULL,
    accepted_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_progress_user_date
    ON lesson_progress(uid, completed_at);
CREATE INDEX IF NOT EXISTS idx_quiz_user_module
    ON quiz_attempts(uid, module_id, lesson_index, score);
CREATE INDEX IF NOT EXISTS idx_dictionary_status
    ON dictionary_entries(is_active, is_verified);
CREATE INDEX IF NOT EXISTS idx_resources_module
    ON resources(module_id, lesson_index);
"""


def connect_db(path: Path) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(path, timeout=10)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    connection.execute("PRAGMA busy_timeout = 10000")
    return connection


@contextmanager
def database(path: Path):
    connection = connect_db(path)
    try:
        with connection:
            yield connection
    finally:
        connection.close()


def initialize_db(path: Path) -> None:
    with database(path) as connection:
        connection.executescript(SCHEMA)


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def iso_utc(value: datetime | None = None) -> str:
    return (value or now_utc()).astimezone(timezone.utc).isoformat()


def reward_zone(settings: Settings) -> ZoneInfo:
    try:
        return ZoneInfo(settings.reward_timezone)
    except ZoneInfoNotFoundError as error:
        raise HTTPException(
            status_code=500, detail="The reward timezone is not configured correctly."
        ) from error


def init_firebase(settings: Settings) -> Any:
    try:
        import firebase_admin
        from firebase_admin import credentials
    except ImportError as error:
        raise HTTPException(
            status_code=503, detail="Firebase Admin support is not installed."
        ) from error

    if firebase_admin._apps:
        return firebase_admin.get_app()
    credential = (
        credentials.Certificate(settings.firebase_admin_credentials)
        if settings.firebase_admin_credentials
        else credentials.ApplicationDefault()
    )
    options = (
        {"projectId": settings.firebase_project_id}
        if settings.firebase_project_id
        else None
    )
    try:
        return firebase_admin.initialize_app(credential, options=options)
    except Exception as error:
        raise HTTPException(
            status_code=503,
            detail="Firebase Admin is not configured. Set credentials and project ID.",
        ) from error


def firebase_auth(settings: Settings) -> Any:
    init_firebase(settings)
    from firebase_admin import auth

    return auth


def verify_firebase_token(settings: Settings, token: str) -> dict[str, Any]:
    """Verifies a Firebase ID token and returns its claims.

    With a service-account file, Firebase Admin verifies the token and also
    checks that it has not been revoked. Without one, the Admin SDK cannot run
    (it needs Google credentials), so the token is verified against Google's
    public signing keys instead: signature, audience (the Firebase project),
    issuer, expiry and subject. Raises ValueError for an invalid token.
    """
    if settings.firebase_admin_credentials:
        return firebase_auth(settings).verify_id_token(token, check_revoked=True)

    project_id = settings.firebase_project_id
    if not project_id:
        raise HTTPException(
            status_code=503,
            detail="Firebase is not configured. Set FIREBASE_PROJECT_ID.",
        )
    from google.auth.transport import requests as google_requests
    from google.oauth2 import id_token as google_id_token

    claims = google_id_token.verify_firebase_token(
        token, google_requests.Request(), audience=project_id
    )
    if not claims or claims.get("iss") != f"https://securetoken.google.com/{project_id}":
        raise ValueError("The token was not issued for this Firebase project.")
    subject = claims.get("sub")
    if not isinstance(subject, str) or not subject:
        raise ValueError("The token has no subject.")
    return {**claims, "uid": subject}


def get_current_uid(request: Request) -> str:
    settings: Settings = request.app.state.settings
    if not settings.firebase_enabled:
        raise HTTPException(status_code=503, detail="Firebase authentication is disabled.")
    authorization = request.headers.get("authorization", "")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=401, detail="A Firebase ID token is required.")
    try:
        decoded = verify_firebase_token(settings, token)
    except HTTPException:
        raise
    except Exception as error:
        raise HTTPException(status_code=401, detail="The Firebase ID token is invalid.") from error
    if not decoded.get("email_verified", True):
        raise HTTPException(status_code=403, detail="Verify your email before continuing.")
    uid = decoded.get("uid")
    if not isinstance(uid, str) or not uid:
        raise HTTPException(status_code=401, detail="The Firebase identity is invalid.")
    return uid


def require_admin(request: Request, uid: str = Depends(get_current_uid)) -> str:
    settings: Settings = request.app.state.settings
    if uid not in settings.firebase_admin_uids:
        raise HTTPException(status_code=403, detail="Administrator access is required.")
    return uid


def learner_exists(connection: sqlite3.Connection, uid: str) -> sqlite3.Row:
    row = connection.execute("SELECT * FROM learners WHERE uid = ?", (uid,)).fetchone()
    if row is None:
        raise HTTPException(
            status_code=404,
            detail="No LearnLite profile is linked to this account. Contact an administrator.",
        )
    return row


def _xp_level(xp: int) -> int:
    return xp // 100


def _learner_profile(connection: sqlite3.Connection, uid: str) -> dict[str, Any]:
    learner = learner_exists(connection, uid)
    completed = connection.execute(
        "SELECT COUNT(*) FROM lesson_progress WHERE uid = ? AND completed_at IS NOT NULL",
        (uid,),
    ).fetchone()[0]
    return {
        "username": learner["username"],
        "full_name": learner["full_name"],
        "nickname": learner["nickname"],
        "avatar_id": learner["avatar_id"],
        "outfit_color": learner["outfit_color"],
        "avatar_completed": bool(learner["avatar_completed"]),
        "user_level": _xp_level(learner["xp"]),
        "xp": learner["xp"],
        "streak": _streak(connection, uid, ZoneInfo("UTC")),
        "completed_lessons": completed,
    }


def _module_row(connection: sqlite3.Connection, module_id: int) -> sqlite3.Row:
    row = connection.execute("SELECT * FROM modules WHERE id = ?", (module_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Learning module not found.")
    return row


def _module_data(
    connection: sqlite3.Connection,
    module: sqlite3.Row,
    uid: str | None,
    *,
    admin: bool = False,
) -> dict[str, Any]:
    lessons = json.loads(module["lessons_json"])
    completed_indices: set[int] = set()
    last_lesson_index: int | None = None
    if uid:
        progress = connection.execute(
            "SELECT lesson_index, started_at, completed_at FROM lesson_progress "
            "WHERE uid = ? AND module_id = ? ORDER BY started_at DESC, completed_at DESC",
            (uid, module["id"]),
        ).fetchall()
        completed_indices = {
            row["lesson_index"] for row in progress if row["completed_at"]
        }
        for row in progress:
            if row["started_at"] or row["completed_at"]:
                last_lesson_index = row["lesson_index"]
                break

    returned_lessons = []
    for index, lesson in enumerate(lessons):
        item = {
            "index": index,
            "title": lesson["title"],
            "content": lesson["content"],
            "completed": index in completed_indices,
            "phrase": lesson.get("phrase"),
            "pronunciation": lesson.get("pronunciation"),
            "audio_url": lesson.get("audio_url"),
            "image_url": lesson.get("image_url"),
            "cultural_note": lesson.get("cultural_note"),
            "keywords": lesson.get("keywords", []),
            "quiz": [],
        }
        for question in lesson.get("quiz", []):
            quiz_item = {
                "question": question["question"],
                "choices": question["choices"],
            }
            if admin:
                quiz_item["correct_answer_index"] = question["correct_answer_index"]
                quiz_item["explanation"] = question.get("explanation")
            item["quiz"].append(quiz_item)
        returned_lessons.append(item)

    return {
        "id": module["id"],
        "title": module["title"],
        "description": module["description"],
        "lesson_count": len(lessons),
        "completed_lessons": len(completed_indices),
        "last_lesson_index": last_lesson_index,
        "lessons": returned_lessons,
        **({"is_published": bool(module["is_published"])} if admin else {}),
    }


def _active_days(connection: sqlite3.Connection, uid: str, zone: ZoneInfo) -> set[date]:
    rows = connection.execute(
        "SELECT completed_at FROM lesson_progress "
        "WHERE uid = ? AND completed_at IS NOT NULL",
        (uid,),
    ).fetchall()
    result: set[date] = set()
    for row in rows:
        timestamp = datetime.fromisoformat(row["completed_at"])
        result.add(timestamp.astimezone(zone).date())
    return result


def _streak(connection: sqlite3.Connection, uid: str, zone: ZoneInfo) -> int:
    active = _active_days(connection, uid, zone)
    today = now_utc().astimezone(zone).date()
    current = today if today in active else today - timedelta(days=1)
    streak = 0
    while current in active:
        streak += 1
        current -= timedelta(days=1)
    return streak


def _reward_event(
    connection: sqlite3.Connection,
    uid: str,
    event_key: str,
    amount: int,
    at: datetime,
) -> int:
    inserted = connection.execute(
        "INSERT OR IGNORE INTO reward_events(uid, event_key, xp, created_at) "
        "VALUES (?, ?, ?, ?)",
        (uid, event_key, amount, iso_utc(at)),
    ).rowcount
    if not inserted:
        return 0
    connection.execute("UPDATE learners SET xp = xp + ? WHERE uid = ?", (amount, uid))
    return amount


def _complete_lesson(
    connection: sqlite3.Connection,
    uid: str,
    module_id: int,
    lesson_index: int,
    completed_at: datetime,
    zone: ZoneInfo,
    *,
    event_id: str | None = None,
) -> bool:
    module = _module_row(connection, module_id)
    if not module["is_published"]:
        raise HTTPException(status_code=404, detail="Learning module not found.")
    lessons = json.loads(module["lessons_json"])
    if lesson_index < 0 or lesson_index >= len(lessons):
        raise HTTPException(status_code=404, detail="Lesson not found.")
    existing = connection.execute(
        "SELECT completed_at FROM lesson_progress WHERE uid = ? AND module_id = ? AND lesson_index = ?",
        (uid, module_id, lesson_index),
    ).fetchone()
    if existing and existing["completed_at"]:
        return False
    connection.execute(
        "INSERT INTO lesson_progress(uid, module_id, lesson_index, started_at, completed_at) "
        "VALUES (?, ?, ?, ?, ?) ON CONFLICT(uid, module_id, lesson_index) DO UPDATE SET "
        "completed_at = excluded.completed_at",
        (uid, module_id, lesson_index, iso_utc(completed_at), iso_utc(completed_at)),
    )
    _reward_event(
        connection,
        uid,
        f"lesson:{module_id}:{lesson_index}",
        10,
        completed_at,
    )
    local_date = completed_at.astimezone(zone).date()
    activity_rows = connection.execute(
        "SELECT completed_at FROM lesson_progress WHERE uid = ? AND completed_at IS NOT NULL",
        (uid,),
    ).fetchall()
    first_today = sum(
        datetime.fromisoformat(row["completed_at"]).astimezone(zone).date() == local_date
        for row in activity_rows
    )
    if first_today == 1:
        _reward_event(connection, uid, f"daily:{local_date.isoformat()}", 5, completed_at)
    week_start = local_date - timedelta(days=local_date.weekday())
    week_end = week_start + timedelta(days=7)
    weekly_rows = connection.execute(
        "SELECT completed_at FROM lesson_progress WHERE uid = ? AND completed_at IS NOT NULL",
        (uid,),
    ).fetchall()
    weekly_total = sum(
        week_start
        <= datetime.fromisoformat(row["completed_at"]).astimezone(zone).date()
        < week_end
        for row in weekly_rows
    )
    if weekly_total == 5:
        _reward_event(
            connection,
            uid,
            f"weekly:{week_start.isoformat()}",
            25,
            completed_at,
        )
    total = connection.execute(
        "SELECT COUNT(*) FROM lesson_progress WHERE uid = ? AND module_id = ? AND completed_at IS NOT NULL",
        (uid, module_id),
    ).fetchone()[0]
    if total == len(lessons):
        connection.execute(
            "INSERT OR IGNORE INTO certificates(certificate_id, uid, module_id, issued_at) "
            "VALUES (?, ?, ?, ?)",
            (str(uuid.uuid4()), uid, module_id, iso_utc(completed_at)),
        )
    if event_id:
        connection.execute(
            "INSERT OR IGNORE INTO offline_events(event_id, uid, module_id, lesson_index, completed_at, accepted_at) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (event_id, uid, module_id, lesson_index, iso_utc(completed_at), iso_utc()),
        )
    return True


def _certificate_pdf(name: str, module_title: str, issued: str) -> bytes:
    safe_values = [
        re.sub(r"[^\x20-\x7e]", "?", value)
        for value in (name, module_title, issued[:10])
    ]
    lines = [
        "LEARNLITE CERTIFICATE OF COMPLETION",
        f"Awarded to: {safe_values[0]}",
        f"For completing: {safe_values[1]}",
        f"Issued: {safe_values[2]}",
    ]
    commands = ["BT /F1 20 Tf 60 730 Td"]
    for index, line in enumerate(lines):
        if index:
            commands.append("0 -52 Td /F1 14 Tf")
        escaped = line.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
        commands.append(f"({escaped}) Tj")
    commands.append("ET")
    stream = "\n".join(commands).encode("ascii")
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        b"<< /Length " + str(len(stream)).encode() + b" >>\nstream\n" + stream + b"\nendstream",
    ]
    pdf = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for number, item in enumerate(objects, 1):
        offsets.append(len(pdf))
        pdf.extend(f"{number} 0 obj\n".encode())
        pdf.extend(item)
        pdf.extend(b"\nendobj\n")
    xref_offset = len(pdf)
    pdf.extend(f"xref\n0 {len(offsets)}\n".encode())
    pdf.extend(b"0000000000 65535 f \n")
    for offset in offsets[1:]:
        pdf.extend(f"{offset:010d} 00000 n \n".encode())
    pdf.extend(
        f"trailer\n<< /Size {len(offsets)} /Root 1 0 R >>\nstartxref\n{xref_offset}\n%%EOF\n".encode()
    )
    return bytes(pdf)


def _dictionary_record(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": row["id"],
        "subanen_word": row["subanen_word"],
        "english_translation": row["english_translation"],
        "bisaya_translation": row["bisaya_translation"],
        "definition": row["definition"],
        "example_sentence": row["example_sentence"],
        "pronunciation": row["pronunciation"],
        "module": row["module"],
        "topic": row["topic"],
        "audio_url": row["audio_url"],
        "source": row["source"],
        "review_status": row["review_status"],
        "is_verified": bool(row["is_verified"]),
        "is_active": bool(row["is_active"]),
    }


def _ensure_local_resource_url(value: str | None) -> None:
    if value and not value.startswith("/resources/"):
        raise HTTPException(
            status_code=422,
            detail="Uploaded media must use a LearnLite /resources/ URL.",
        )


def _make_app(settings: Settings) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        initialize_db(settings.database_path)
        settings.resource_dir.mkdir(parents=True, exist_ok=True)
        yield

    app = FastAPI(title="LearnLite API", version="1.0.0", lifespan=lifespan)
    app.state.settings = settings
    if settings.cors_origins:
        from fastapi.middleware.cors import CORSMiddleware

        app.add_middleware(
            CORSMiddleware,
            allow_origins=list(settings.cors_origins),
            allow_credentials=True,
            allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
            allow_headers=["Authorization", "Content-Type"],
        )

    def db():
        return database(settings.database_path)

    def user(uid: str = Depends(get_current_uid)) -> str:
        return uid

    def admin(uid: str = Depends(require_admin)) -> str:
        return uid

    @app.get("/health")
    def health() -> dict[str, Any]:
        with db() as connection:
            connection.execute("SELECT 1").fetchone()
        return {
            "status": "ok",
            "database": "ok",
            "firebase_enabled": settings.firebase_enabled,
            "ollama_model": settings.ollama_model,
        }

    @app.get("/auth/username-availability")
    def username_availability(username: str) -> dict[str, bool]:
        normalized = username.strip()
        if not USERNAME_PATTERN.fullmatch(normalized):
            raise HTTPException(status_code=422, detail="Enter a valid username.")
        with db() as connection:
            exists = connection.execute(
                "SELECT 1 FROM learners WHERE username = ? COLLATE NOCASE",
                (normalized,),
            ).fetchone()
        return {"available": exists is None}

    @app.post("/auth/register")
    def register(body: RegisterRequest) -> dict[str, str]:
        if not settings.firebase_enabled:
            raise HTTPException(
                status_code=503,
                detail="Firebase registration is unavailable until Firebase Admin is configured.",
            )
        auth = firebase_auth(settings)
        with db() as connection:
            if connection.execute(
                "SELECT 1 FROM learners WHERE username = ? COLLATE NOCASE",
                (body.username,),
            ).fetchone():
                raise HTTPException(status_code=409, detail="That username is already in use.")
            if connection.execute(
                "SELECT 1 FROM learners WHERE email = ? COLLATE NOCASE", (body.email,)
            ).fetchone():
                raise HTTPException(status_code=409, detail="That email is already in use.")
            firebase_user = None
            try:
                firebase_user = auth.create_user(
                    email=body.email,
                    password=body.password,
                    display_name=body.full_name,
                    email_verified=False,
                )
                connection.execute(
                    "INSERT INTO learners(uid, username, full_name, email, learning_preference, created_at) "
                    "VALUES (?, ?, ?, ?, ?, ?)",
                    (
                        firebase_user.uid,
                        body.username,
                        body.full_name,
                        body.email,
                        body.learning_preference,
                        iso_utc(),
                    ),
                )
            except HTTPException:
                raise
            except Exception as error:
                if firebase_user is not None:
                    try:
                        auth.delete_user(firebase_user.uid)
                    except Exception:
                        pass
                raise HTTPException(
                    status_code=409,
                    detail="The account could not be created. Check the email and try again.",
                ) from error
            token = auth.create_custom_token(firebase_user.uid)
        return {"custom_token": token.decode("utf-8") if isinstance(token, bytes) else token}

    @app.post("/auth/login")
    async def username_login(body: LoginRequest) -> dict[str, str]:
        if not settings.firebase_enabled or not settings.firebase_web_api_key:
            raise HTTPException(
                status_code=503,
                detail="Username sign-in requires Firebase and FIREBASE_WEB_API_KEY configuration.",
            )
        with db() as connection:
            learner = connection.execute(
                "SELECT uid, email FROM learners WHERE username = ? COLLATE NOCASE",
                (body.username,),
            ).fetchone()
        if learner is None:
            raise HTTPException(status_code=401, detail="Username or password is incorrect.")
        url = (
            "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
            f"?key={quote(settings.firebase_web_api_key, safe='')}"
        )
        try:
            async with httpx.AsyncClient(timeout=12) as client:
                response = await client.post(
                    url,
                    json={
                        "email": learner["email"],
                        "password": body.password,
                        "returnSecureToken": True,
                    },
                )
        except httpx.TimeoutException as error:
            raise HTTPException(status_code=503, detail="Firebase sign-in timed out.") from error
        except httpx.RequestError as error:
            raise HTTPException(status_code=503, detail="Could not reach Firebase sign-in.") from error
        if response.status_code != 200:
            raise HTTPException(status_code=401, detail="Username or password is incorrect.")
        auth = firebase_auth(settings)
        try:
            decoded = auth.verify_id_token(response.json()["idToken"])
            custom_token = auth.create_custom_token(decoded["uid"])
        except Exception as error:
            raise HTTPException(status_code=503, detail="Firebase sign-in could not be verified.") from error
        return {
            "custom_token": custom_token.decode("utf-8")
            if isinstance(custom_token, bytes)
            else custom_token
        }

    @app.get("/auth/profile")
    def fetch_profile(uid: str = Depends(user)) -> dict[str, Any]:
        with db() as connection:
            return _learner_profile(connection, uid)

    @app.patch("/auth/profile")
    def update_profile(body: AvatarUpdate, uid: str = Depends(user)) -> dict[str, Any]:
        if body.avatar_id is not None or body.outfit_color is not None or body.avatar_completed:
            raise HTTPException(
                status_code=422,
                detail="Avatar customization is unavailable until approved assets are configured.",
            )
        with db() as connection:
            learner_exists(connection, uid)
            connection.execute(
                "UPDATE learners SET nickname = ? WHERE uid = ?",
                (body.nickname.strip() if body.nickname else None, uid),
            )
            return _learner_profile(connection, uid)

    @app.get("/modules")
    def list_modules(search: str = "", uid: str = Depends(user)) -> list[dict[str, Any]]:
        with db() as connection:
            rows = connection.execute(
                "SELECT * FROM modules WHERE is_published = 1 "
                "AND (lower(title) LIKE ? OR lower(description) LIKE ?) ORDER BY id",
                (f"%{search.strip().lower()}%", f"%{search.strip().lower()}%"),
            ).fetchall()
            learner_exists(connection, uid)
            return [_module_data(connection, row, uid) for row in rows]

    @app.get("/modules/{module_id}")
    def get_module(module_id: int, uid: str = Depends(user)) -> dict[str, Any]:
        with db() as connection:
            module = _module_row(connection, module_id)
            if not module["is_published"]:
                raise HTTPException(status_code=404, detail="Learning module not found.")
            learner_exists(connection, uid)
            return _module_data(connection, module, uid)

    @app.post("/modules/{module_id}/lessons/{lesson_index}/start")
    def start_lesson(module_id: int, lesson_index: int, uid: str = Depends(user)) -> dict[str, Any]:
        with db() as connection:
            connection.execute("BEGIN IMMEDIATE")
            module = _module_row(connection, module_id)
            if not module["is_published"]:
                raise HTTPException(status_code=404, detail="Learning module not found.")
            lessons = json.loads(module["lessons_json"])
            if lesson_index < 0 or lesson_index >= len(lessons):
                raise HTTPException(status_code=404, detail="Lesson not found.")
            learner_exists(connection, uid)
            connection.execute(
                "INSERT INTO lesson_progress(uid, module_id, lesson_index, started_at) "
                "VALUES (?, ?, ?, ?) ON CONFLICT(uid, module_id, lesson_index) "
                "DO UPDATE SET started_at = excluded.started_at",
                (uid, module_id, lesson_index, iso_utc()),
            )
            return _module_data(connection, module, uid)

    @app.post("/modules/{module_id}/lessons/{lesson_index}/complete")
    def complete_lesson(module_id: int, lesson_index: int, uid: str = Depends(user)) -> dict[str, Any]:
        with db() as connection:
            connection.execute("BEGIN IMMEDIATE")
            learner_exists(connection, uid)
            _complete_lesson(
                connection,
                uid,
                module_id,
                lesson_index,
                now_utc(),
                reward_zone(settings),
            )
            return _module_data(connection, _module_row(connection, module_id), uid)

    @app.post("/modules/{module_id}/lessons/{lesson_index}/quiz/submit")
    def submit_quiz(
        module_id: int,
        lesson_index: int,
        body: QuizSubmission,
        uid: str = Depends(user),
    ) -> dict[str, Any]:
        with db() as connection:
            connection.execute("BEGIN IMMEDIATE")
            learner = learner_exists(connection, uid)
            module = _module_row(connection, module_id)
            if not module["is_published"]:
                raise HTTPException(status_code=404, detail="Learning module not found.")
            lessons = json.loads(module["lessons_json"])
            if lesson_index < 0 or lesson_index >= len(lessons):
                raise HTTPException(status_code=404, detail="Lesson not found.")
            questions = lessons[lesson_index].get("quiz", [])
            if not questions:
                raise HTTPException(status_code=404, detail="This lesson has no quiz.")
            if len(body.answers) != len(questions):
                raise HTTPException(status_code=422, detail="Submit one answer for every question.")
            if any(answer < 0 or answer >= len(question["choices"]) for answer, question in zip(body.answers, questions)):
                raise HTTPException(status_code=422, detail="An answer index is out of range.")
            correct = sum(
                answer == question["correct_answer_index"]
                for answer, question in zip(body.answers, questions)
            )
            previous_best = connection.execute(
                "SELECT MAX(score) FROM quiz_attempts WHERE uid = ? AND module_id = ? AND lesson_index = ?",
                (uid, module_id, lesson_index),
            ).fetchone()[0]
            earned = correct if previous_best is None or correct > previous_best else 0
            completed_at = now_utc()
            before_level = _xp_level(learner["xp"])
            result_questions = [
                {
                    "question": question["question"],
                    "choices": question["choices"],
                    "selected_answer_index": answer,
                    "correct_answer_index": question["correct_answer_index"],
                    "explanation": question.get("explanation"),
                }
                for answer, question in zip(body.answers, questions)
            ]
            attempt_id = connection.execute(
                "INSERT INTO quiz_attempts(uid, module_id, lesson_index, score, total_questions, result_json, completed_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                (
                    uid,
                    module_id,
                    lesson_index,
                    correct,
                    len(questions),
                    json.dumps(result_questions, ensure_ascii=False),
                    iso_utc(completed_at),
                ),
            ).lastrowid
            if earned:
                connection.execute("UPDATE learners SET xp = xp + ? WHERE uid = ?", (earned, uid))
            refreshed = learner_exists(connection, uid)
            return {
                "attempt_id": attempt_id,
                "score": correct,
                "total_questions": len(questions),
                "correct_answers": correct,
                "incorrect_answers": len(questions) - correct,
                "xp_awarded": earned,
                "lesson_xp_awarded": 0,
                "total_xp_awarded": earned,
                "previous_level": before_level,
                "current_level": _xp_level(refreshed["xp"]),
                "completed_at": iso_utc(completed_at),
                "questions": result_questions,
                "module": _module_data(connection, module, uid),
            }

    @app.get("/modules/{module_id}/lessons/{lesson_index}/quiz/attempts")
    def quiz_attempts(module_id: int, lesson_index: int, uid: str = Depends(user)) -> list[dict[str, Any]]:
        with db() as connection:
            learner_exists(connection, uid)
            module = _module_row(connection, module_id)
            if not module["is_published"]:
                raise HTTPException(status_code=404, detail="Learning module not found.")
            rows = connection.execute(
                "SELECT * FROM quiz_attempts WHERE uid = ? AND module_id = ? AND lesson_index = ? ORDER BY id DESC",
                (uid, module_id, lesson_index),
            ).fetchall()
            return [
                {
                    "attempt_id": row["id"],
                    "score": row["score"],
                    "total_questions": row["total_questions"],
                    "correct_answers": row["score"],
                    "incorrect_answers": row["total_questions"] - row["score"],
                    "xp_awarded": 0,
                    "lesson_xp_awarded": 0,
                    "total_xp_awarded": 0,
                    "completed_at": row["completed_at"],
                    "questions": json.loads(row["result_json"]),
                }
                for row in rows
            ]

    @app.post("/offline-sync/events")
    def sync_offline_events(body: dict[str, list[dict[str, Any]]], uid: str = Depends(user)) -> list[dict[str, Any]]:
        completions = body.get("completions")
        if not isinstance(completions, list) or len(completions) > 500:
            raise HTTPException(status_code=422, detail="Completions must be a list of at most 500 events.")
        results: list[dict[str, Any]] = []
        with db() as connection:
            learner_exists(connection, uid)
            for event in completions:
                event_id = event.get("event_id")
                if not isinstance(event_id, str):
                    results.append({"accepted": False, "detail": "Missing event ID."})
                    continue
                try:
                    uuid.UUID(event_id)
                    module_id = int(event["module_id"])
                    lesson_index = int(event["lesson_index"])
                    completed_at = datetime.fromisoformat(event["completed_at"].replace("Z", "+00:00"))
                    if completed_at.tzinfo is None:
                        completed_at = completed_at.replace(tzinfo=timezone.utc)
                except (ValueError, KeyError, TypeError, AttributeError):
                    results.append({"event_id": event_id, "accepted": False, "detail": "Invalid event data."})
                    continue
                if event.get("user_id") not in (None, uid):
                    results.append({"event_id": event_id, "accepted": False, "detail": "Event belongs to a different account."})
                    continue
                try:
                    connection.execute("SAVEPOINT offline_event")
                    already = connection.execute(
                        "SELECT 1 FROM offline_events WHERE event_id = ? AND uid = ?",
                        (event_id, uid),
                    ).fetchone()
                    if already:
                        connection.execute("RELEASE offline_event")
                        results.append({"event_id": event_id, "accepted": True})
                        continue
                    _complete_lesson(
                        connection,
                        uid,
                        module_id,
                        lesson_index,
                        completed_at,
                        reward_zone(settings),
                        event_id=event_id,
                    )
                    connection.execute("RELEASE offline_event")
                    results.append({"event_id": event_id, "accepted": True})
                except HTTPException as error:
                    connection.execute("ROLLBACK TO offline_event")
                    connection.execute("RELEASE offline_event")
                    results.append({"event_id": event_id, "accepted": False, "detail": str(error.detail)})
        return results

    @app.get("/vocabulary/translate")
    def translate(
        q: str,
        source_language: str = "Subanen",
        target_language: str = "English",
        uid: str = Depends(user),
    ) -> list[dict[str, Any]]:
        if not q.strip() or len(q) > 200:
            raise HTTPException(status_code=422, detail="Enter a search term of 1 to 200 characters.")
        keys = {
            "subanen": "subanen_word",
            "english": "english_translation",
            "cebuano": "bisaya_translation",
        }
        source_key = keys.get(source_language.lower())
        target_key = keys.get(target_language.lower())
        if not source_key or not target_key or source_key == target_key:
            raise HTTPException(status_code=422, detail="That language pair is not supported.")
        with db() as connection:
            learner_exists(connection, uid)
            rows = connection.execute(
                f"SELECT * FROM dictionary_entries WHERE is_active = 1 AND is_verified = 1 "
                f"AND {source_key} IS NOT NULL AND {target_key} IS NOT NULL "
                f"AND lower({source_key}) LIKE ? ORDER BY id LIMIT 100",
                (f"%{q.strip().lower()}%",),
            ).fetchall()
            return [
                {
                    "entry": _dictionary_record(row),
                    "source_language": source_language,
                    "target_language": target_language,
                    "translation": row[target_key],
                }
                for row in rows
            ]

    @app.get("/content-packs")
    def content_packs(uid: str = Depends(user)) -> list[dict[str, Any]]:
        with db() as connection:
            learner_exists(connection, uid)
            modules = connection.execute(
                "SELECT id, title, lessons_json FROM modules WHERE is_published = 1 ORDER BY id"
            ).fetchall()
            packs = [
                {
                    "id": f"module:{row['id']}",
                    "type": "module",
                    "title": row["title"],
                    "size_bytes": len(row["lessons_json"].encode()),
                }
                for row in modules
            ]
            entries = connection.execute(
                "SELECT * FROM dictionary_entries WHERE is_active = 1 AND is_verified = 1 ORDER BY id"
            ).fetchall()
            if entries:
                data = [_dictionary_record(row) for row in entries]
                packs.append(
                    {
                        "id": "dictionary",
                        "type": "dictionary",
                        "title": "Verified dictionary",
                        "size_bytes": len(json.dumps(data, ensure_ascii=False).encode()),
                    }
                )
            return packs

    @app.get("/content-packs/{pack_id}")
    def content_pack(pack_id: str, uid: str = Depends(user)) -> dict[str, Any]:
        with db() as connection:
            learner_exists(connection, uid)
            if pack_id == "dictionary":
                rows = connection.execute(
                    "SELECT * FROM dictionary_entries WHERE is_active = 1 AND is_verified = 1 ORDER BY id"
                ).fetchall()
                data = [_dictionary_record(row) for row in rows]
                if not data:
                    raise HTTPException(status_code=404, detail="No verified dictionary content is available.")
                return {
                    "id": "dictionary",
                    "type": "dictionary",
                    "title": "Verified dictionary",
                    "data": data,
                    "resource_urls": [],
                }
            match = re.fullmatch(r"module:(\d+)", pack_id)
            if not match:
                raise HTTPException(status_code=404, detail="Content pack not found.")
            module_id = int(match.group(1))
            module = _module_row(connection, module_id)
            if not module["is_published"]:
                raise HTTPException(status_code=404, detail="Content pack not found.")
            data = _module_data(connection, module, None)
            resources = connection.execute(
                "SELECT id FROM resources WHERE module_id = ? ORDER BY created_at",
                (module_id,),
            ).fetchall()
            return {
                "id": pack_id,
                "type": "module",
                "title": module["title"],
                "data": data,
                "resource_urls": [f"/resources/{row['id']}" for row in resources],
            }

    @app.get("/resources/{resource_id}")
    def fetch_resource(resource_id: str, uid: str = Depends(user)) -> Response:
        with db() as connection:
            learner_exists(connection, uid)
            row = connection.execute(
                "SELECT * FROM resources WHERE id = ?", (resource_id,)
            ).fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="Resource not found.")
            path = Path(row["path"])
            if not path.is_file():
                raise HTTPException(status_code=404, detail="Resource file is unavailable.")
            payload = path.read_bytes()
            return Response(
                payload,
                media_type=row["media_type"],
                headers={"Content-Length": str(len(payload)), "Cache-Control": "private, max-age=3600"},
            )

    @app.get("/rewards")
    def rewards(uid: str = Depends(user)) -> dict[str, Any]:
        zone = reward_zone(settings)
        with db() as connection:
            learner_exists(connection, uid)
            now = now_utc().astimezone(zone)
            today = now.date()
            active_days = _active_days(connection, uid, zone)
            streak = _streak(connection, uid, zone)
            longest = 0
            run = 0
            previous: date | None = None
            for active_day in sorted(active_days):
                run = run + 1 if previous and active_day == previous + timedelta(days=1) else 1
                longest = max(longest, run)
                previous = active_day
            daily_count = sum(day == today for day in active_days)
            week_start = today - timedelta(days=today.weekday())
            week_days = {day for day in active_days if week_start <= day < week_start + timedelta(days=7)}
            daily_reward = connection.execute(
                "SELECT xp FROM reward_events WHERE uid = ? AND event_key = ?",
                (uid, f"daily:{today.isoformat()}"),
            ).fetchone()
            weekly_reward = connection.execute(
                "SELECT xp FROM reward_events WHERE uid = ? AND event_key = ?",
                (uid, f"weekly:{week_start.isoformat()}"),
            ).fetchone()
            calendar = []
            for offset in range(27, -1, -1):
                day = today - timedelta(days=offset)
                calendar.append(
                    {
                        "activity_date": day.isoformat(),
                        "weekday": day.strftime("%A"),
                        "active": day in active_days,
                        "is_today": day == today,
                        "is_future": day > today,
                    }
                )
            badges = [
                {
                    "id": "first_lesson",
                    "title": "First Steps",
                    "description": "Complete your first lesson.",
                    "earned": bool(active_days),
                    "progress": min(1, sum(1 for _ in active_days)),
                    "target": 1,
                },
                {
                    "id": "five_lessons",
                    "title": "Learning Explorer",
                    "description": "Complete five lessons.",
                    "earned": connection.execute(
                        "SELECT COUNT(*) FROM lesson_progress WHERE uid = ? AND completed_at IS NOT NULL",
                        (uid,),
                    ).fetchone()[0] >= 5,
                    "progress": min(
                        5,
                        connection.execute(
                            "SELECT COUNT(*) FROM lesson_progress WHERE uid = ? AND completed_at IS NOT NULL",
                            (uid,),
                        ).fetchone()[0],
                    ),
                    "target": 5,
                },
                {
                    "id": "perfect_quiz",
                    "title": "Perfect Score",
                    "description": "Earn a perfect score on a quiz.",
                    "earned": bool(connection.execute(
                        "SELECT 1 FROM quiz_attempts WHERE uid = ? AND score = total_questions LIMIT 1",
                        (uid,),
                    ).fetchone()),
                    "progress": int(bool(connection.execute(
                        "SELECT 1 FROM quiz_attempts WHERE uid = ? AND score = total_questions LIMIT 1",
                        (uid,),
                    ).fetchone())),
                    "target": 1,
                },
                {
                    "id": "seven_day_streak",
                    "title": "Consistent Learner",
                    "description": "Learn on seven consecutive days.",
                    "earned": longest >= 7,
                    "progress": min(7, streak),
                    "target": 7,
                },
            ]
            certificates = connection.execute(
                "SELECT c.certificate_id, c.module_id, m.title, l.full_name, c.issued_at "
                "FROM certificates c JOIN modules m ON m.id = c.module_id "
                "JOIN learners l ON l.uid = c.uid WHERE c.uid = ? ORDER BY c.issued_at DESC",
                (uid,),
            ).fetchall()
            return {
                "timezone": settings.reward_timezone,
                "today": today.isoformat(),
                "streak": streak,
                "longest_streak": longest,
                "active_dates": [day.isoformat() for day in sorted(active_days)],
                "calendar": calendar,
                "daily_quest": {
                    "title": "Daily learner",
                    "description": "Complete one lesson today.",
                    "progress": min(1, daily_count),
                    "target": 1,
                    "completed": daily_count >= 1,
                    "xp_reward": 5,
                    "xp_awarded": daily_reward["xp"] if daily_reward else 0,
                },
                "weekly_chest": {
                    "title": "Weekly learning chest",
                    "description": "Complete five lessons this week.",
                    "progress": min(5, len(week_days)),
                    "target": 5,
                    "unlocked": len(week_days) >= 5,
                    "xp_reward": 25,
                    "xp_awarded": weekly_reward["xp"] if weekly_reward else 0,
                    "week_start": week_start.isoformat(),
                },
                "badges": badges,
                "certificates": [
                    {
                        "certificate_id": row["certificate_id"],
                        "module_id": row["module_id"],
                        "module_title": row["title"],
                        "learner_name": row["full_name"],
                        "issued_at": row["issued_at"],
                    }
                    for row in certificates
                ],
            }

    @app.get("/rewards/certificates/{certificate_id}/pdf")
    def certificate_pdf(certificate_id: str, uid: str = Depends(user)) -> Response:
        with db() as connection:
            row = connection.execute(
                "SELECT c.issued_at, m.title, l.full_name FROM certificates c "
                "JOIN modules m ON m.id = c.module_id JOIN learners l ON l.uid = c.uid "
                "WHERE c.certificate_id = ? AND c.uid = ?",
                (certificate_id, uid),
            ).fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="Certificate not found.")
            pdf = _certificate_pdf(row["full_name"], row["title"], row["issued_at"])
            return Response(
                pdf,
                media_type="application/pdf",
                headers={"Content-Disposition": f'attachment; filename="learnlite-certificate-{certificate_id}.pdf"'},
            )

    @app.post("/ai/chat")
    async def ai_chat(body: dict[str, Any], request: Request, uid: str = Depends(user)) -> dict[str, Any]:
        # D1: any verified Firebase user may use the Tutor. Learning data lives
        # in the app's SQLite database, so no backend learner row is required.
        messages = body.get("messages")
        if not isinstance(messages, list) or not messages or len(messages) > 10:
            raise HTTPException(status_code=422, detail="Send between 1 and 10 chat messages.")
        safe_messages = []
        for message in messages:
            if not isinstance(message, dict) or message.get("role") not in {"user", "assistant"}:
                raise HTTPException(status_code=422, detail="Chat messages must use user or assistant roles.")
            content = message.get("content")
            if not isinstance(content, str) or not content.strip() or len(content) > 4000:
                raise HTTPException(status_code=422, detail="Each message must contain 1 to 4000 characters.")
            safe_messages.append({"role": message["role"], "content": content.strip()})
        if safe_messages[-1]["role"] != "user":
            raise HTTPException(status_code=422, detail="The last chat message must be from the learner.")
        system_message = (
            "You are LearnLite, a patient educational tutor. Explain concepts clearly, "
            "offer examples, and help learners practice. Never invent or assert Subanen "
            "translations, cultural facts, or pronunciation; say when verified source "
            "material is unavailable. Do not claim to have accessed learner records."
        )
        # Optional workbook rows the app found for the learner's question. They
        # come from the bundled workbook and are not verified, so the model may
        # quote them only with that label and must not add other Subanen forms.
        context = body.get("context")
        if context is not None:
            if not isinstance(context, list) or len(context) > 12:
                raise HTTPException(status_code=422, detail="Send at most 12 vocabulary context entries.")
            lines = []
            for item in context:
                if not isinstance(item, dict):
                    raise HTTPException(status_code=422, detail="Vocabulary context entries must be objects.")
                fields = {}
                for key in ("english", "subanen", "status"):
                    value = item.get(key, "")
                    if not isinstance(value, str) or len(value) > 200:
                        raise HTTPException(status_code=422, detail="Vocabulary context fields must be short text.")
                    fields[key] = " ".join(value.split())
                if fields["english"] and fields["subanen"]:
                    lines.append(
                        f'- "{fields["english"]}" -> "{fields["subanen"]}" '
                        f'({fields["status"] or "Pending review"})'
                    )
            if lines:
                system_message += (
                    "\n\nWorkbook vocabulary from the learner's device that may be relevant. "
                    "These entries are NOT verified; if you use one, quote it exactly and say "
                    "it is pending review by a fluent speaker. Do not give any other Subanen "
                    "forms:\n" + "\n".join(lines)
                )
        payload = {
            "model": settings.ollama_model,
            "messages": [{"role": "system", "content": system_message}, *safe_messages],
            "stream": False,
        }
        try:
            async with httpx.AsyncClient(timeout=settings.ollama_timeout_seconds) as client:
                response = await client.post(
                    f"{settings.ollama_base_url}/api/chat",
                    json=payload,
                )
                response.raise_for_status()
                response_body = response.json()
        except httpx.TimeoutException as error:
            raise HTTPException(status_code=503, detail="The local AI tutor timed out. Is Ollama running?") from error
        except httpx.RequestError as error:
            raise HTTPException(status_code=503, detail="The local AI tutor is unavailable. Start Ollama and try again.") from error
        except httpx.HTTPStatusError as error:
            raise HTTPException(status_code=503, detail="Ollama could not complete the tutor request.") from error
        except ValueError as error:
            raise HTTPException(status_code=502, detail="Ollama returned an invalid response.") from error
        content = response_body.get("message", {}).get("content")
        if not isinstance(content, str) or not content.strip():
            raise HTTPException(status_code=502, detail="Ollama returned an empty tutor response.")
        return {"response": content.strip(), "model": settings.ollama_model}

    @app.get("/admin/session")
    def admin_session(uid: str = Depends(admin)) -> dict[str, bool]:
        return {"is_admin": True}

    @app.get("/admin/summary")
    def admin_summary(uid: str = Depends(admin)) -> dict[str, Any]:
        with db() as connection:
            totals = {
                "total_modules": connection.execute("SELECT COUNT(*) FROM modules").fetchone()[0],
                "published_modules": connection.execute("SELECT COUNT(*) FROM modules WHERE is_published = 1").fetchone()[0],
                "total_lessons": sum(
                    len(json.loads(row["lessons_json"]))
                    for row in connection.execute("SELECT lessons_json FROM modules").fetchall()
                ),
                "verified_dictionary_entries": connection.execute(
                    "SELECT COUNT(*) FROM dictionary_entries WHERE is_verified = 1 AND is_active = 1"
                ).fetchone()[0],
                "uploaded_resources": connection.execute("SELECT COUNT(*) FROM resources").fetchone()[0],
                "quiz_attempts": connection.execute("SELECT COUNT(*) FROM quiz_attempts").fetchone()[0],
            }
            resources = connection.execute(
                "SELECT * FROM resources ORDER BY created_at DESC LIMIT 5"
            ).fetchall()
            activity = [
                {"type": "lesson_completed", "count": connection.execute(
                    "SELECT COUNT(*) FROM lesson_progress WHERE completed_at IS NOT NULL"
                ).fetchone()[0]},
                {"type": "quiz_submitted", "count": totals["quiz_attempts"]},
            ]
            return {
                **totals,
                "recent_uploads": [
                    {
                        "id": row["id"],
                        "name": row["name"],
                        "media_type": row["media_type"],
                        "size_bytes": row["size_bytes"],
                        "url": f"/resources/{row['id']}",
                        "created_at": row["created_at"],
                        "module_id": row["module_id"],
                        "lesson_index": row["lesson_index"],
                        "vocabulary_id": row["vocabulary_id"],
                    }
                    for row in resources
                ],
                "activity": activity,
            }

    @app.get("/admin/modules")
    def admin_modules(uid: str = Depends(admin)) -> list[dict[str, Any]]:
        with db() as connection:
            rows = connection.execute("SELECT * FROM modules ORDER BY id DESC").fetchall()
            return [_module_data(connection, row, None, admin=True) for row in rows]

    @app.post("/admin/modules", status_code=201)
    def create_module(body: ModuleInput, uid: str = Depends(admin)) -> dict[str, Any]:
        for lesson in body.lessons:
            _ensure_local_resource_url(lesson.audio_url)
            _ensure_local_resource_url(lesson.image_url)
        serialized = [lesson.model_dump(exclude_none=True) for lesson in body.lessons]
        with db() as connection:
            now = iso_utc()
            cursor = connection.execute(
                "INSERT INTO modules(title, description, lessons_json, is_published, created_at, updated_at) "
                "VALUES (?, ?, ?, 0, ?, ?)",
                (body.title, body.description, json.dumps(serialized, ensure_ascii=False), now, now),
            )
            return _module_data(connection, _module_row(connection, cursor.lastrowid), None, admin=True)

    @app.put("/admin/modules/{module_id}")
    def update_module(module_id: int, body: ModuleInput, uid: str = Depends(admin)) -> dict[str, Any]:
        for lesson in body.lessons:
            _ensure_local_resource_url(lesson.audio_url)
            _ensure_local_resource_url(lesson.image_url)
        serialized = [lesson.model_dump(exclude_none=True) for lesson in body.lessons]
        with db() as connection:
            _module_row(connection, module_id)
            connection.execute(
                "UPDATE modules SET title = ?, description = ?, lessons_json = ?, updated_at = ? WHERE id = ?",
                (body.title, body.description, json.dumps(serialized, ensure_ascii=False), iso_utc(), module_id),
            )
            return _module_data(connection, _module_row(connection, module_id), None, admin=True)

    @app.patch("/admin/modules/{module_id}/publication")
    def publish_module(module_id: int, body: PublicationUpdate, uid: str = Depends(admin)) -> dict[str, bool]:
        with db() as connection:
            module = _module_row(connection, module_id)
            connection.execute(
                "UPDATE modules SET is_published = ?, updated_at = ? WHERE id = ?",
                (int(body.is_published), iso_utc(), module_id),
            )
            return {"is_published": body.is_published}

    @app.delete("/admin/modules/{module_id}", status_code=204)
    def delete_module(module_id: int, uid: str = Depends(admin)) -> Response:
        with db() as connection:
            _module_row(connection, module_id)
            connection.execute("DELETE FROM modules WHERE id = ?", (module_id,))
        return Response(status_code=204)

    @app.get("/admin/dictionary")
    def admin_dictionary(q: str = "", uid: str = Depends(admin)) -> list[dict[str, Any]]:
        with db() as connection:
            rows = connection.execute(
                "SELECT * FROM dictionary_entries WHERE lower(subanen_word) LIKE ? "
                "OR lower(english_translation) LIKE ? ORDER BY id DESC LIMIT 500",
                (f"%{q.strip().lower()}%", f"%{q.strip().lower()}%"),
            ).fetchall()
            return [_dictionary_record(row) for row in rows]

    @app.post("/admin/dictionary", status_code=201)
    def create_dictionary_entry(body: DictionaryInput, uid: str = Depends(admin)) -> dict[str, Any]:
        _ensure_local_resource_url(body.audio_url)
        verified = body.is_verified and bool(body.source and body.source.strip())
        status = "verified" if verified else "pending_review"
        values = body.model_dump()
        with db() as connection:
            now = iso_utc()
            cursor = connection.execute(
                "INSERT INTO dictionary_entries(subanen_word, english_translation, bisaya_translation, "
                "definition, example_sentence, pronunciation, module, topic, source, audio_url, "
                "is_verified, is_active, review_status, created_at, updated_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    values["subanen_word"], values["english_translation"], values["bisaya_translation"],
                    values["definition"], values["example_sentence"], values["pronunciation"],
                    values["module"], values["topic"], values["source"], values["audio_url"],
                    int(verified), int(values["is_active"]), status, now, now,
                ),
            )
            row = connection.execute("SELECT * FROM dictionary_entries WHERE id = ?", (cursor.lastrowid,)).fetchone()
            return _dictionary_record(row)

    @app.patch("/admin/dictionary/{entry_id}")
    def update_dictionary_entry(entry_id: int, body: dict[str, Any], uid: str = Depends(admin)) -> dict[str, Any]:
        allowed = set(DictionaryInput.model_fields)
        if not body or set(body) - allowed:
            raise HTTPException(status_code=422, detail="Dictionary entry contains unsupported fields.")
        with db() as connection:
            current = connection.execute(
                "SELECT * FROM dictionary_entries WHERE id = ?", (entry_id,)
            ).fetchone()
            if current is None:
                raise HTTPException(status_code=404, detail="Dictionary entry not found.")
            current_values = {key: current[key] for key in allowed}
            current_values["is_verified"] = bool(current_values["is_verified"])
            current_values["is_active"] = bool(current_values["is_active"])
            current_values.update(body)
            validated = DictionaryInput.model_validate(current_values)
            _ensure_local_resource_url(validated.audio_url)
            text_changed = any(
                key in body
                for key in (
                    "subanen_word", "english_translation", "bisaya_translation",
                    "definition", "example_sentence", "pronunciation", "source",
                    "audio_url", "module", "topic",
                )
            )
            verified = validated.is_verified and bool(validated.source and validated.source.strip())
            if text_changed:
                verified = False
            status = "verified" if verified else "pending_review"
            values = validated.model_dump()
            connection.execute(
                "UPDATE dictionary_entries SET subanen_word = ?, english_translation = ?, "
                "bisaya_translation = ?, definition = ?, example_sentence = ?, pronunciation = ?, "
                "module = ?, topic = ?, source = ?, audio_url = ?, is_verified = ?, is_active = ?, "
                "review_status = ?, updated_at = ? WHERE id = ?",
                (
                    values["subanen_word"], values["english_translation"], values["bisaya_translation"],
                    values["definition"], values["example_sentence"], values["pronunciation"],
                    values["module"], values["topic"], values["source"], values["audio_url"],
                    int(verified), int(values["is_active"]), status, iso_utc(), entry_id,
                ),
            )
            return _dictionary_record(
                connection.execute("SELECT * FROM dictionary_entries WHERE id = ?", (entry_id,)).fetchone()
            )

    @app.delete("/admin/dictionary/{entry_id}", status_code=204)
    def deactivate_dictionary_entry(entry_id: int, uid: str = Depends(admin)) -> Response:
        with db() as connection:
            updated = connection.execute(
                "UPDATE dictionary_entries SET is_active = 0, updated_at = ? WHERE id = ?",
                (iso_utc(), entry_id),
            ).rowcount
            if not updated:
                raise HTTPException(status_code=404, detail="Dictionary entry not found.")
        return Response(status_code=204)

    @app.post("/admin/resources", status_code=201)
    async def upload_resource(
        request: Request,
        file: UploadFile = File(...),
        module_id: int | None = None,
        lesson_index: int | None = None,
        vocabulary_id: int | None = None,
        uid: str = Depends(admin),
    ) -> dict[str, Any]:
        filename = Path(file.filename or "").name
        suffix = Path(filename).suffix.lower()
        media_type = ALLOWED_RESOURCE_TYPES.get(suffix)
        if not filename or not media_type:
            raise HTTPException(status_code=415, detail="Upload a supported PDF, audio, or image file.")
        content = await file.read(MAX_UPLOAD_BYTES + 1)
        if not content:
            raise HTTPException(status_code=422, detail="The uploaded file is empty.")
        if len(content) > MAX_UPLOAD_BYTES:
            raise HTTPException(status_code=413, detail="Resource files must be 25 MB or smaller.")
        if module_id is not None:
            with db() as connection:
                module = _module_row(connection, module_id)
                lessons = json.loads(module["lessons_json"])
                if lesson_index is not None and not 0 <= lesson_index < len(lessons):
                    raise HTTPException(status_code=404, detail="Lesson not found.")
        resource_id = str(uuid.uuid4())
        safe_name = f"{resource_id}{suffix}"
        target = settings.resource_dir / safe_name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        created_at = iso_utc()
        with db() as connection:
            connection.execute(
                "INSERT INTO resources(id, name, media_type, size_bytes, path, created_at, module_id, lesson_index, vocabulary_id) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    resource_id, filename, media_type, len(content), str(target), created_at,
                    module_id, lesson_index, vocabulary_id,
                ),
            )
        return {
            "id": resource_id,
            "name": filename,
            "media_type": media_type,
            "size_bytes": len(content),
            "url": f"/resources/{resource_id}",
            "created_at": created_at,
            "module_id": module_id,
            "lesson_index": lesson_index,
            "vocabulary_id": vocabulary_id,
        }

    return app


app = _make_app(Settings())
