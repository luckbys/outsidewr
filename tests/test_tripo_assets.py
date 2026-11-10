"""Offline contract tests. Fixtures stay in temp directories, never in game assets."""

import contextlib
import io
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import tripo_assets as tripo


def fixture_glb():
    binary = struct.pack("<9f3H", 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 2)
    binary += b"\0" * (-len(binary) % 4)
    document = {
        "asset": {"version": "2.0"}, "scene": 0,
        "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "indices": 1}]}],
        "buffers": [{"byteLength": len(binary)}],
        "bufferViews": [{"buffer": 0, "byteLength": 36}, {"buffer": 0, "byteOffset": 36, "byteLength": 6}],
        "accessors": [{"bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3", "min": [0, 0, 0], "max": [1, 1, 0]},
                      {"bufferView": 1, "componentType": 5123, "count": 3, "type": "SCALAR"}]}
    payload = json.dumps(document).encode()
    payload += b" " * (-len(payload) % 4)
    total = 12 + 8 + len(payload) + 8 + len(binary)
    return struct.pack("<4sII", b"glTF", 2, total) + struct.pack("<I4s", len(payload), b"JSON") + payload + struct.pack("<I4s", len(binary), b"BIN\0") + binary


class Response(io.BytesIO):
    def __init__(self, data):
        super().__init__(data)
        self.headers = {"Content-Length": str(len(data))}


class Opener:
    def __init__(self, responses):
        self.responses, self.requests = list(responses), []

    def open(self, request, timeout):
        self.requests.append(request)
        item = self.responses.pop(0)
        if isinstance(item, Exception):
            raise item
        return Response(item if isinstance(item, bytes) else json.dumps(item).encode())


class Clock:
    def __init__(self):
        self.time, self.waits = 0.0, []

    def now(self):
        return self.time

    def sleep(self, seconds):
        self.time += seconds
        self.waits.append(seconds)


class FakeTripo:
    """Only simulates the documented wire contract; makes no network calls."""
    def __init__(self):
        self.calls, self.tasks, self.polls = [], {}, []
        self.riggable, self.fail_create, self.fail_download = True, False, False

    def create(self, stage, body):
        self.calls.append((stage, body))
        task_id = "00000000-0000-4000-8000-%012d" % len(self.calls)
        self.tasks[task_id] = stage
        if self.fail_create:
            raise tripo.TripoError("simulated timeout after submission")
        return task_id

    def poll(self, task_id, timeout, report):
        self.polls.append(task_id)
        stage = self.tasks[task_id]
        output = {"riggable": self.riggable, "rig_type": "biped"} if stage == "check" else {"model_url": "https://cdn.example/model.glb?signed=temporary"}
        return {"status": "success", "output": output}

    def download(self, url, destination):
        if self.fail_download:
            raise tripo.TripoError("simulated expired URL")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(fixture_glb())
        return tripo.validate_glb(destination)


class TripoTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.directory = Path(self.temporary.name)
        self.catalog = tripo.load_catalog()
        self.client = FakeTripo()
        self.state = self.directory / "state.json"
        self.output = self.directory / "models"

    def tearDown(self):
        self.temporary.cleanup()

    def pipeline(self):
        return tripo.Pipeline(self.client, self.catalog, self.state, self.output, lambda value: None)

    def test_catalog_has_eight_assets_and_twenty_documented_steps(self):
        assets = self.catalog["assets"]
        self.assertEqual(len(assets), 8)
        self.assertEqual(sum(4 if a["animate"] else 1 for a in assets), 20)
        self.assertEqual(self.catalog["model"], "P2-20260801")

    def test_plan_needs_no_key_and_never_constructs_an_api_client(self):
        with patch.object(tripo, "Client", side_effect=AssertionError("network client created")), contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(tripo.main(["plan"]), 0)
        self.assertIn("8 modelos", output.getvalue())

    def test_missing_key_stops_before_state_or_task_creation(self):
        with patch.dict(tripo.os.environ, {}, clear=True), contextlib.redirect_stderr(io.StringIO()) as output:
            self.assertEqual(tripo.main(["generate", "--asset", "house_brick", "--state", str(self.state)]), 2)
        self.assertFalse(self.state.exists())
        self.assertIn("TRIPO_API_KEY ausente", output.getvalue())

    def test_existing_triploapi_variable_is_reused_without_another_key(self):
        opener = Opener([])
        with patch.dict(tripo.os.environ, {"triploapi": "test-only-existing-binding"}, clear=True):
            client = tripo.Client(opener=opener)
        self.assertEqual(client.key, "test-only-existing-binding")
        self.assertEqual(opener.requests, [])

    def test_generation_requires_an_explicit_asset_selection(self):
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(tripo.main(["generate"]), 2)

    def test_static_asset_downloads_glb_and_repeated_run_does_not_bill_again(self):
        asset = self.catalog["assets"][0]
        self.pipeline().run(asset)
        self.assertTrue((self.output / "house_brick.glb").exists())
        self.pipeline().run(asset)
        self.assertEqual(len(self.client.calls), 1)
        state = self.state.read_text()
        self.assertNotIn("signed=", state)
        self.assertNotIn("model_url", state)

    def test_character_pipeline_checks_and_rigs_the_original_generation(self):
        asset = self.catalog["assets"][4]
        self.pipeline().run(asset)
        calls = self.client.calls
        self.assertEqual([stage for stage, _ in calls], ["generate", "check", "rig", "walk"])
        self.assertEqual(calls[1][1]["input"], "00000000-0000-4000-8000-000000000001")
        self.assertEqual(calls[2][1]["input"], calls[1][1]["input"])
        self.assertEqual(calls[2][1]["model"], "v3.0-20260909")
        self.assertEqual(calls[3][1]["input"], "00000000-0000-4000-8000-000000000003")
        self.assertEqual(calls[3][1]["animation"], "preset:walk")

    def test_failed_rig_check_preserves_source_and_stops_paid_followup_steps(self):
        self.client.riggable = False
        with self.assertRaisesRegex(tripo.TripoError, "rig-check"):
            self.pipeline().run(self.catalog["assets"][4])
        self.assertEqual(len(self.client.calls), 2)
        self.assertTrue((self.directory / "sources/police_hero-generate.glb").exists())
        self.assertFalse((self.output / "police_hero.glb").exists())

    def test_unknown_submission_never_automatically_posts_a_second_task(self):
        self.client.fail_create = True
        asset = self.catalog["assets"][0]
        with self.assertRaises(tripo.TripoError):
            self.pipeline().run(asset)
        self.client.fail_create = False
        with self.assertRaisesRegex(tripo.TripoError, "POST duplicado"):
            self.pipeline().run(asset)
        self.assertEqual(len(self.client.calls), 1)

    def test_known_rejection_can_be_retried_after_credentials_are_corrected(self):
        original_create = self.client.create
        def reject(stage, body):
            raise tripo.TripoError("HTTP 401", known_rejected=True)
        self.client.create = reject
        asset = self.catalog["assets"][0]
        with self.assertRaises(tripo.TripoError):
            self.pipeline().run(asset)
        self.client.create = original_create
        self.pipeline().run(asset)
        self.assertEqual(len(self.client.calls), 1)
        self.assertTrue((self.output / "house_brick.glb").exists())

    def test_adopting_unknown_task_resumes_without_another_generation(self):
        self.client.fail_create = True
        with self.assertRaises(tripo.TripoError):
            self.pipeline().run(self.catalog["assets"][0])
        task_id = next(iter(self.client.tasks))
        self.assertEqual(tripo.main(["adopt", "--asset", "house_brick", "--stage", "generate", "--task-id", task_id, "--state", str(self.state)]), 0)
        self.client.fail_create = False
        self.pipeline().run(self.catalog["assets"][0])
        self.assertEqual(len(self.client.calls), 1)

    def test_failed_download_retries_existing_task_without_a_new_post(self):
        self.client.fail_download = True
        with self.assertRaises(tripo.TripoError):
            self.pipeline().run(self.catalog["assets"][0])
        self.client.fail_download = False
        self.pipeline().run(self.catalog["assets"][0])
        self.assertEqual(len(self.client.calls), 1)
        self.assertEqual(len(self.client.polls), 2)

    def test_completed_character_stages_are_not_polled_again_when_resuming(self):
        original_download = self.client.download
        def fail_final(url, destination):
            if destination.parent == self.output:
                raise tripo.TripoError("simulated final download failure")
            return original_download(url, destination)
        self.client.download = fail_final
        asset = self.catalog["assets"][4]
        with self.assertRaises(tripo.TripoError):
            self.pipeline().run(asset)
        self.client.download = original_download
        self.pipeline().run(asset)
        self.assertEqual(len(self.client.calls), 4)
        self.assertEqual(len(self.client.polls), 5)

    def test_changed_prompt_does_not_silently_generate_another_paid_asset(self):
        asset = self.catalog["assets"][0]
        self.pipeline().run(asset)
        changed = {**asset, "prompt": "different prompt"}
        with self.assertRaisesRegex(tripo.TripoError, "mudou"):
            self.pipeline().run(changed)
        self.assertEqual(len(self.client.calls), 1)

    def test_existing_artist_file_is_not_overwritten(self):
        self.output.mkdir()
        target = self.output / "house_brick.glb"
        target.write_bytes(fixture_glb())
        with self.assertRaisesRegex(tripo.TripoError, "não foi substituído"):
            self.pipeline().run(self.catalog["assets"][0])
        self.assertEqual(len(self.client.calls), 0)

    def test_api_request_uses_v3_and_scoped_bearer_authorization(self):
        opener = Opener([{"code": 0, "data": {"task_id": "00000000-0000-4000-8000-000000000001"}}])
        client = tripo.Client(key="test-only-not-a-real-key", opener=opener)
        client.create("generate", {"prompt": "fixture", "model": "P2-20260801"})
        request = opener.requests[0]
        self.assertEqual(request.full_url, tripo.API_ROOT + "/generation/text-to-model")
        self.assertEqual(request.get_header("Authorization"), "Bearer test-only-not-a-real-key")

    def test_http_error_does_not_echo_key_or_signed_url(self):
        secret = "test-only-sensitive-value"
        error = HTTPError(tripo.API_ROOT, 401, secret, {}, io.BytesIO(secret.encode()))
        client = tripo.Client(key=secret, opener=Opener([error]))
        with self.assertRaises(tripo.TripoError) as caught:
            client.create("generate", {})
        self.assertNotIn(secret, str(caught.exception))
        self.assertIn("401", str(caught.exception))

    def test_actual_provider_insufficient_credit_error_is_explained_and_retry_safe(self):
        body = json.dumps({"code": 2010, "message": "You don't have enough credit to create this task"}).encode()
        error = HTTPError(tripo.API_ROOT, 403, "Forbidden", {}, io.BytesIO(body))
        client = tripo.Client(key="test-only", opener=Opener([error]))
        with self.assertRaises(tripo.TripoError) as caught:
            client.create("generate", {})
        self.assertIn("Créditos insuficientes", str(caught.exception))
        self.assertIn("2010", str(caught.exception))
        self.assertTrue(caught.exception.known_rejected)

    def test_api_redirects_do_not_forward_authentication(self):
        request = Request(tripo.API_ROOT, headers={"Authorization": "Bearer test-only"})
        self.assertIsNone(tripo.NoRedirect().redirect_request(request, None, 302, "redirect", {}, "https://cdn.example/model.glb"))

    def test_download_uses_no_api_authorization_and_validates_the_glb(self):
        client = tripo.Client(key="test-only")
        opener = Opener([fixture_glb()])
        client.download_opener = opener
        target = self.directory / "model.glb"
        checksum = client.download("https://cdn.example/model.glb?signed=temporary", target)
        self.assertEqual(checksum, tripo.validate_glb(target))
        self.assertIsNone(opener.requests[0].get_header("Authorization"))

    def test_download_rejects_non_https_before_connecting(self):
        client = tripo.Client(key="test-only")
        opener = Opener([])
        client.download_opener = opener
        with self.assertRaises(tripo.TripoError):
            client.download("http://cdn.example/model.glb", self.directory / "model.glb")
        self.assertEqual(opener.requests, [])

    def test_bad_download_does_not_replace_an_existing_file(self):
        client = tripo.Client(key="test-only")
        client.download_opener = Opener([b"<html>not a GLB file</html>"])
        target = self.directory / "model.glb"
        target.write_bytes(b"original")
        with self.assertRaises(tripo.TripoError):
            client.download("https://cdn.example/model.glb", target)
        self.assertEqual(target.read_bytes(), b"original")
        self.assertEqual(list(self.directory.glob("*.part")), [])

    def test_polling_obeys_the_documented_two_second_interval(self):
        clock = Clock()
        opener = Opener([{"code": 0, "data": {"status": "running", "progress": 30}},
                         {"code": 0, "data": {"status": "success", "output": {}}}])
        client = tripo.Client(key="test-only", opener=opener, sleep=clock.sleep, now=clock.now)
        result = client.poll("00000000-0000-4000-8000-000000000001", 10, lambda value: None)
        self.assertEqual(result["status"], "success")
        self.assertEqual(clock.waits, [2])

    def test_terminal_task_failure_stops_polling(self):
        opener = Opener([{"code": 0, "data": {"status": "failed"}}])
        client = tripo.Client(key="test-only", opener=opener)
        with self.assertRaisesRegex(tripo.TripoError, "failed"):
            client.poll("00000000-0000-4000-8000-000000000001", 10, lambda value: None)
        self.assertEqual(len(opener.requests), 1)


if __name__ == "__main__":
    unittest.main()
