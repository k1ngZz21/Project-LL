"""Tests for the Tutor bridge (`POST /ai/chat`), decision D1.

Run from the `backend` folder:  python -m unittest discover -s tests -v

Firebase sign-in is replaced by a fixed test user (dependency override), so
these tests cover the bridge itself: no backend learner row is needed, the
vocabulary context reaches the model labelled as unverified, Ollama errors
become clear 503 messages, and (when Ollama is running) a real reply comes
back from the configured model.
"""

import tempfile
import unittest
from pathlib import Path
from unittest import mock

import httpx
from fastapi.testclient import TestClient

from learnlite_api import main

MESSAGES = [{"role": "user", "content": "How do I greet someone in the morning?"}]


def make_client(ollama_url: str, tmp: str, timeout: float = 90) -> TestClient:
    settings = main.Settings(
        database_path=Path(tmp) / "learnlite.sqlite3",
        resource_dir=Path(tmp) / "resources",
        firebase_enabled=True,
        ollama_base_url=ollama_url,
        ollama_timeout_seconds=timeout,
    )
    app = main._make_app(settings)
    app.dependency_overrides[main.get_current_uid] = lambda: "tutor-test-uid"
    return TestClient(app)


def ollama_running(url: str = "http://localhost:11434") -> bool:
    try:
        return httpx.get(f"{url}/api/tags", timeout=3).status_code == 200
    except httpx.HTTPError:
        return False


class AiChatBridgeTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = self._tmp.name

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _fake_ollama(self, handler):
        real = httpx.AsyncClient

        def factory(**kwargs):
            return real(transport=httpx.MockTransport(handler), **kwargs)

        return mock.patch.object(main.httpx, "AsyncClient", side_effect=factory)

    def test_no_learner_row_needed_and_context_is_labelled(self) -> None:
        captured = {}

        def handler(request: httpx.Request) -> httpx.Response:
            import json

            captured["payload"] = json.loads(request.content)
            return httpx.Response(200, json={"message": {"content": "Hello!"}})

        with self._fake_ollama(handler), make_client("http://ollama.test", self.tmp) as client:
            response = client.post(
                "/ai/chat",
                json={
                    "messages": MESSAGES,
                    "context": [
                        {"english": "Good morning", "subanen": "gempya seselem", "status": "Pending review"}
                    ],
                },
            )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["response"], "Hello!")
        system = captured["payload"]["messages"][0]
        self.assertEqual(system["role"], "system")
        self.assertIn('"Good morning" -> "gempya seselem" (Pending review)', system["content"])
        self.assertIn("NOT verified", system["content"])

    def test_context_is_validated(self) -> None:
        with make_client("http://ollama.test", self.tmp) as client:
            too_many = client.post(
                "/ai/chat",
                json={"messages": MESSAGES, "context": [{"english": "a", "subanen": "b"}] * 13},
            )
            not_text = client.post(
                "/ai/chat",
                json={"messages": MESSAGES, "context": [{"english": 5, "subanen": "b"}]},
            )
        self.assertEqual(too_many.status_code, 422)
        self.assertEqual(not_text.status_code, 422)

    def test_stopped_ollama_gives_a_clear_503(self) -> None:
        # Port 9 (discard) is closed on a normal machine.
        with make_client("http://127.0.0.1:9", self.tmp, timeout=5) as client:
            response = client.post("/ai/chat", json={"messages": MESSAGES})
        self.assertEqual(response.status_code, 503)
        self.assertIn("unavailable", response.json()["detail"])

    def test_timeout_gives_a_clear_503(self) -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            raise httpx.ReadTimeout("slow model", request=request)

        with self._fake_ollama(handler), make_client("http://ollama.test", self.tmp) as client:
            response = client.post("/ai/chat", json={"messages": MESSAGES})
        self.assertEqual(response.status_code, 503)
        self.assertIn("timed out", response.json()["detail"])

    def _client_with_real_auth(self) -> TestClient:
        settings = main.Settings(
            database_path=Path(self.tmp) / "learnlite.sqlite3",
            resource_dir=Path(self.tmp) / "resources",
            firebase_enabled=True,
            firebase_project_id="learnlite-f1dd5",
            firebase_admin_credentials=None,
            ollama_base_url="http://ollama.test",
        )
        return TestClient(main._make_app(settings))

    def test_garbage_token_is_rejected_without_credentials(self) -> None:
        with self._client_with_real_auth() as client:
            response = client.post(
                "/ai/chat",
                headers={"Authorization": "Bearer not-a-token"},
                json={"messages": MESSAGES},
            )
        self.assertEqual(response.status_code, 401)

    def test_token_for_another_project_is_rejected(self) -> None:
        claims = {"iss": "https://securetoken.google.com/other-project", "sub": "x", "email_verified": True}
        with mock.patch("google.oauth2.id_token.verify_firebase_token", return_value=claims), \
                self._client_with_real_auth() as client:
            response = client.post(
                "/ai/chat",
                headers={"Authorization": "Bearer token"},
                json={"messages": MESSAGES},
            )
        self.assertEqual(response.status_code, 401)

    def test_valid_token_reaches_the_tutor_without_credentials(self) -> None:
        claims = {
            "iss": "https://securetoken.google.com/learnlite-f1dd5",
            "sub": "learner-uid",
            "email_verified": True,
        }

        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(200, json={"message": {"content": "Hi"}})

        with mock.patch("google.oauth2.id_token.verify_firebase_token", return_value=claims), \
                self._fake_ollama(handler), self._client_with_real_auth() as client:
            response = client.post(
                "/ai/chat",
                headers={"Authorization": "Bearer token"},
                json={"messages": MESSAGES},
            )
        self.assertEqual(response.status_code, 200, response.text)

    def test_unverified_email_is_refused(self) -> None:
        claims = {
            "iss": "https://securetoken.google.com/learnlite-f1dd5",
            "sub": "learner-uid",
            "email_verified": False,
        }
        with mock.patch("google.oauth2.id_token.verify_firebase_token", return_value=claims), \
                self._client_with_real_auth() as client:
            response = client.post(
                "/ai/chat",
                headers={"Authorization": "Bearer token"},
                json={"messages": MESSAGES},
            )
        self.assertEqual(response.status_code, 403)

    @unittest.skipUnless(ollama_running(), "Ollama is not running on localhost:11434")
    def test_live_reply_from_the_configured_model(self) -> None:
        with make_client("http://localhost:11434", self.tmp, timeout=180) as client:
            response = client.post(
                "/ai/chat",
                json={
                    "messages": [{"role": "user", "content": "In one short sentence, what is a flashcard?"}],
                },
            )
        self.assertEqual(response.status_code, 200, response.text)
        body = response.json()
        self.assertEqual(body["model"], "qwen2.5:3b")
        self.assertTrue(body["response"].strip())
        print(f"\nLive reply from {body['model']}: {body['response'][:200]}")


if __name__ == "__main__":
    unittest.main()
