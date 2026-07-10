import os
import unittest
import urllib.parse
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPO_ROOT / "config" / "scripts" / "imoocs"


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
        <body><section class="content">Lesson body{containers}</section></body></html>
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


if __name__ == "__main__":
    unittest.main()
