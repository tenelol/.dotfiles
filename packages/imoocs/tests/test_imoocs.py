import ctypes
import json
import os
import sys
import tempfile
import unittest
import urllib.parse
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch


REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT_PATH = REPO_ROOT / "packages" / "imoocs" / "imoocs"


def load_imoocs_python():
    source = SCRIPT_PATH.read_text()
    start_marker = 'IMOOCS_HTTP_ACTION="$action" BACKEND="$backend" python3 - "$@" <<\'PY\'\n'
    start = source.index(start_marker) + len(start_marker)
    embedded = source[start:source.index("\nPY\n}", start)]
    main_call = "\ntry:\n    raise SystemExit(main())\nexcept KeyboardInterrupt:"
    embedded = embedded[:embedded.index(main_call)]
    namespace = {"__name__": "imoocs_test"}
    previous_backend = os.environ.get("BACKEND")
    os.environ["BACKEND"] = "imoocs-test"
    try:
        exec(compile(embedded, str(SCRIPT_PATH), "exec"), namespace)
    finally:
        if previous_backend is None:
            os.environ.pop("BACKEND", None)
        else:
            os.environ["BACKEND"] = previous_backend
    return namespace


class ImoocsCookieStoreTests(unittest.TestCase):
    def test_macos_save_updates_without_deleting_and_preserves_failed_writes(self):
        imoocs = load_imoocs_python()
        jar = imoocs["http"].cookiejar.CookieJar()
        jar.set_cookie(imoocs["cookie_from_dict"]({"name": "session", "value": "test-session"}))
        keyring = Mock()
        keyring.delete_password.side_effect = RuntimeError(-25244, "Invalid owner edit")
        keyring.set_password.side_effect = RuntimeError(-25244, "Delete before add failed")
        imoocs["keyring"] = keyring
        api = SimpleNamespace(
            _sec=SimpleNamespace(SecItemUpdate=Mock()),
            _found=SimpleNamespace(CFDataCreate=Mock(return_value=1), CFRelease=Mock()),
            OS_status=ctypes.c_int32,
            create_query=Mock(side_effect=lambda **kwargs: kwargs),
            k_=lambda name: name,
            error=SimpleNamespace(item_not_found=-25300),
            SecItemAdd=Mock(return_value=0),
            Error=SimpleNamespace(raise_for_status=Mock()),
        )

        def check_status(status):
            if status:
                raise RuntimeError(status)

        api.Error.raise_for_status.side_effect = check_status
        with patch.object(sys, "platform", "darwin"), patch.dict(
            sys.modules, {"keyring.backends.macOS": SimpleNamespace(api=api)}
        ):
            for status in (0, -25300, -25244):
                with self.subTest(status=status):
                    api._sec.SecItemUpdate.return_value = status
                    api.SecItemAdd.reset_mock()
                    if status == -25244:
                        with self.assertRaises(RuntimeError):
                            imoocs["save_cookie_jar"](jar)
                    else:
                        imoocs["save_cookie_jar"](jar)
                    query, attributes = api._sec.SecItemUpdate.call_args.args
                    self.assertEqual(query, {
                        "kSecClass": "kSecClassGenericPassword",
                        "kSecAttrService": "imoocs",
                        "kSecAttrAccount": "moocs-session-cookies",
                    })
                    self.assertEqual(set(attributes), {"kSecValueData"})
                    self.assertEqual(api.SecItemAdd.call_count, int(status == -25300))
                    _, raw, size = api._found.CFDataCreate.call_args.args
                    self.assertEqual(len(raw), size)
                    self.assertEqual(json.loads(raw)[0]["value"], "test-session")
        keyring.delete_password.assert_not_called()
        keyring.set_password.assert_not_called()


class ImoocsMultipleAssignmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.imoocs = load_imoocs_python()

    def test_problem_descriptors_preserve_order_and_deduplicate(self):
        page_html = """
        <div class="panel problem-container extra" data-lang="ja"
             data-urlprefix="/assignments/2026/INI203/first/"></div>
        <div data-urlprefix="/assignments/2026/INI203/second" class="problem-container"></div>
        <div class="problem-container" data-urlprefix="/assignments/2026/INI203/first"></div>
        <div class="problem-containerish" data-urlprefix="/assignments/2026/INI203/ignored"></div>
        <div class="problem-container"></div>
        """
        descriptors = self.imoocs["problem_descriptors"](
            page_html,
            "https://moocs.iniad.org/courses/2026/INI203/00b/00",
        )

        self.assertEqual(
            [item["urlPrefix"] for item in descriptors],
            [
                "https://moocs.iniad.org/assignments/2026/INI203/first",
                "https://moocs.iniad.org/assignments/2026/INI203/second",
            ],
        )
        self.assertEqual(descriptors[0]["language"], "ja")
        self.assertEqual(
            self.imoocs["problem_descriptor"](
                page_html,
                "https://moocs.iniad.org/courses/2026/INI203/00b/00",
            )["urlPrefix"],
            descriptors[0]["urlPrefix"],
        )
        self.assertEqual(self.imoocs["problem_descriptors"]("<main>No assignments</main>", "https://moocs.iniad.org/"), [])

    def test_google_material_links_include_anchor_embed_and_html_urls(self):
        page_url = "https://moocs.iniad.org/courses/2026/STS201/02/01"
        page_html = """
        <a href="https://docs.google.com/presentation/d/deck/edit">Lecture slides</a>
        <object data="https://drive.google.com/file/d/handout/view"></object>
        <button onclick="window.open('https://drive.google.com/drive/folders/folder-id')">Files</button>
        <a href="https://docs.google.com/presentation/d/deck/edit">Duplicate</a>
        """

        self.assertEqual(
            self.imoocs["extract_google_material_links"](page_html, page_url),
            [
                {
                    "url": "https://docs.google.com/presentation/d/deck/edit",
                    "kind": "presentation",
                    "source": "anchor",
                    "text": "Lecture slides",
                },
                {
                    "url": "https://drive.google.com/file/d/handout/view",
                    "kind": "drive",
                    "source": "object",
                    "text": "",
                },
                {
                    "url": "https://drive.google.com/drive/folders/folder-id",
                    "kind": "folder",
                    "source": "html",
                    "text": "",
                },
            ],
        )

    def test_open_url_resolves_every_assignment_and_keeps_first_alias(self):
        page_url = "https://moocs.iniad.org/courses/2026/INI203/00b/00"
        problem_ids = ["first", "second", "third"]
        containers = "\n".join(
            f'<div class="panel problem-container" data-urlprefix="/assignments/2026/INI203/{problem_id}"></div>'
            for problem_id in problem_ids
        )
        page_html = f"""
        <html><head><title>Multiple assignments : INIAD MOOCs</title>
        <meta name="csrf-token" content="test-token"></head>
        <body><section class="content">Lesson body
        <a href="https://docs.google.com/presentation/d/test-deck/edit">Lecture slides</a>
        {containers}</section></body></html>
        """
        captured = []

        def fake_request(_jar, url, **_kwargs):
            self.assertEqual(url, page_url)
            return page_url, 200, {}, page_html.encode()

        def fake_problem_json(_jar, url, requested_page_url, token):
            self.assertEqual(requested_page_url, page_url)
            self.assertEqual(token, "test-token")
            path_parts = [urllib.parse.unquote(part) for part in urllib.parse.urlparse(url).path.split("/") if part]
            problem_id, endpoint = path_parts[-2:]
            if endpoint == "status":
                if problem_id == "second":
                    raise RuntimeError("temporary status failure")
                return {"status": "open" if problem_id == "first" else "closed"}
            if endpoint == "problem":
                return {
                    "html": (
                        f"<p>Question {problem_id}</p>"
                        f'<input name="{problem_id}-answer" type="text" required>'
                        f'<input name="{problem_id}-file" type="file">'
                    )
                }
            if endpoint == "answers":
                return {
                    f"{problem_id}-answer": {"data": f"value-{problem_id}"},
                    f"{problem_id}-file": {
                        "data": "",
                        "file": {"filename": f"{problem_id}.ipynb", "filetype": "application/octet-stream"},
                    },
                }
            raise AssertionError(f"unexpected endpoint: {url}")

        self.imoocs["load_cookie_jar"] = lambda: (object(), "loaded")
        self.imoocs["ensure_moocs_authenticated"] = lambda _jar: True
        self.imoocs["save_cookie_jar"] = lambda _jar: None
        self.imoocs["request"] = fake_request
        self.imoocs["fetch_problem_json"] = fake_problem_json
        self.imoocs["print_json"] = captured.append

        self.assertEqual(self.imoocs["open_url"](page_url), 0)
        payload = captured[0]
        data = payload["data"]
        assignments = data["assignments"]

        self.assertTrue(payload["ok"])
        self.assertEqual(data["assignmentCount"], 3)
        self.assertEqual([item["problemId"] for item in assignments], problem_ids)
        self.assertEqual(data["route"]["problemId"], "first")
        self.assertEqual(data["problem"]["problemId"], "first")
        self.assertEqual([item["status"] for item in assignments], ["open", "unknown", "closed"])
        self.assertEqual(assignments[1]["endpointErrors"][0]["endpoint"], "status")
        self.assertEqual(
            [field["pid"] for field in assignments[1]["fields"]],
            ["second-answer", "second-file"],
        )
        self.assertEqual(assignments[1]["currentAnswers"]["second-answer"], "value-second")
        self.assertEqual(assignments[1]["fields"][1]["uploadedFile"]["filename"], "second.ipynb")
        self.assertIn("Question first", data["bodyText"])
        self.assertIn("Question second", data["bodyText"])
        self.assertIn("Question third", data["bodyText"])
        self.assertEqual(
            data["links"],
            [{
                "url": "https://docs.google.com/presentation/d/test-deck/edit",
                "text": "Lecture slides",
                "title": "",
            }],
        )
        self.assertEqual(
            data["materialLinks"],
            [{
                "url": "https://docs.google.com/presentation/d/test-deck/edit",
                "kind": "presentation",
                "source": "anchor",
                "text": "Lecture slides",
            }],
        )


class ImoocsSlideCollectionTests(unittest.TestCase):
    def setUp(self):
        self.imoocs = load_imoocs_python()

    def test_drive_file_id_from_supported_urls(self):
        extract = self.imoocs["drive_file_id_from_value"]
        self.assertEqual(extract("https://drive.google.com/file/d/file-id-123/view"), "file-id-123")
        self.assertEqual(extract("https://docs.google.com/presentation/d/deck-id-123/edit"), "deck-id-123")
        self.assertEqual(extract("https://drive.google.com/open?id=query-id-123"), "query-id-123")

    def test_slide_collect_args_accept_refresh_google(self):
        options = self.imoocs["parse_slide_collect_args"]([
            "--path", "/tmp/slides",
            "--year", "2026",
            "--refresh-google",
        ])
        self.assertTrue(options["refresh_google"])

    def test_content_disposition_repairs_utf8_decoded_as_latin1(self):
        expected = "確率統計2.pdf"
        mojibake = expected.encode("utf-8").decode("latin-1")
        self.assertEqual(
            self.imoocs["filename_from_content_disposition"](f'attachment; filename="{mojibake}"'),
            expected,
        )

    def test_drive_download_tries_drive_uc_after_usercontent_failure(self):
        calls = []

        def fake_request(_jar, url, **_kwargs):
            calls.append(url)
            if "drive.usercontent.google.com" in url:
                return url, 403, {"Content-Type": "text/html"}, b"forbidden"
            return (
                url,
                200,
                {"Content-Type": "application/pdf", "Content-Disposition": 'attachment; filename="lecture.pdf"'},
                b"%PDF-1.4\n%%EOF\n",
            )

        self.imoocs["request"] = fake_request
        final_url, _headers, filename, body = self.imoocs["download_drive_file_body"](
            object(),
            {"id": "file-id-123", "name": "Lecture", "mimeType": ""},
        )

        self.assertIn("drive.google.com/uc", final_url)
        self.assertEqual(filename, "lecture.pdf")
        self.assertTrue(body.startswith(b"%PDF"))
        self.assertEqual(len(calls), 2)

    def test_drive_download_exports_native_presentation_found_on_view_page(self):
        def fake_request(_jar, url, **_kwargs):
            if "/export/pdf" in url:
                return url, 200, {"Content-Type": "application/pdf"}, b"%PDF-1.4\n%%EOF\n"
            if "/file/d/" in url:
                return (
                    url,
                    200,
                    {"Content-Type": "text/html"},
                    b'<html>application/vnd.google-apps.presentation</html>',
                )
            return url, 200, {"Content-Type": "text/html"}, b"not downloadable"

        self.imoocs["request"] = fake_request
        final_url, _headers, filename, body = self.imoocs["download_drive_file_body"](
            object(),
            {"id": "deck-id-123", "name": "Lecture", "mimeType": ""},
        )

        self.assertIn("/presentation/d/deck-id-123/export/pdf", final_url)
        self.assertEqual(filename, "Lecture.pdf")
        self.assertTrue(body.startswith(b"%PDF"))

    def test_slide_collect_downloads_linked_drive_file(self):
        page_url = "https://moocs.iniad.org/courses/2026/STS201/02/01"
        page_html = """
        <main><a href="https://drive.google.com/file/d/file-id-123/view">Lecture PDF</a></main>
        """
        captured = []

        self.imoocs["load_cookie_jar"] = lambda: (object(), "loaded")
        self.imoocs["ensure_moocs_authenticated"] = lambda _jar: True
        self.imoocs["save_cookie_jar"] = lambda _jar: None
        self.imoocs["list_courses"] = lambda _jar, _year: [{
            "courseId": "2026/STS201", "name": "Statistics", "slug": "STS201",
        }]
        self.imoocs["list_lectures"] = lambda _jar, _course: [{
            "courseId": "2026/STS201", "lessonId": "02", "name": "Week 2", "slug": "02",
        }]
        self.imoocs["list_pages"] = lambda _jar, _lecture: [{
            "courseId": "2026/STS201",
            "lessonId": "02",
            "pageId": "01",
            "slug": "01",
            "title": "Lecture",
            "url": page_url,
        }]
        self.imoocs["authenticated_html"] = lambda _jar, _url: (page_url, page_html)
        self.imoocs["download_drive_file_body"] = lambda _jar, item: (
            "https://drive.usercontent.google.com/download?id=" + item["id"],
            {"Content-Type": "application/pdf", "Content-Disposition": 'attachment; filename="week2.pdf"'},
            "week2.pdf",
            b"%PDF-1.4\n%%EOF\n",
        )
        self.imoocs["print_json"] = captured.append

        with tempfile.TemporaryDirectory() as output_dir:
            result = self.imoocs["slide_collect"]([
                "--path", output_dir,
                "--year", "2026",
                "--course", "STS201",
                "--lecture", "02",
                "--page", "01",
            ])
            payload = captured[0]
            self.assertEqual(result, 0)
            self.assertTrue(payload["ok"])
            self.assertEqual(payload["data"]["downloadedFileCount"], 1)
            self.assertEqual(payload["data"]["downloadedPdfCount"], 1)
            self.assertTrue(Path(payload["data"]["downloadedFilePaths"][0]).is_file())


if __name__ == "__main__":
    unittest.main()
