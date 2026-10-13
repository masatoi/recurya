"""Tests for the single-file Python recurya CLI (resources/static/recurya).

Run: python3 -m unittest discover -s tests/cli_py -v

Pure functions are tested directly; the commands run against a stub HTTP
server bound to 127.0.0.1 on an ephemeral port.  Config and workspaces live
in temporary directories; cwd and the environment are restored after each
test.
"""
import contextlib
import io
import json
import os
import shutil
import stat
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
import importlib.util
from importlib.machinery import SourceFileLoader
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
_loader = SourceFileLoader("recurya", str(ROOT / "resources/static/recurya"))
_spec = importlib.util.spec_from_loader("recurya", _loader)
recurya = importlib.util.module_from_spec(_spec)
_loader.exec_module(recurya)


# --------------------------------------------------------------------------
# Fixtures

def cell(index, kind, **kw):
    base = {"index": index, "cell_id": "c%d" % index, "kind": kind, "body": None,
            "description": None, "test_cases": [], "gated": False, "unlocked": False,
            "saved_code": None, "passed": False}
    base.update(kw)
    return base


def sample_notebook(unlocked=False, passed=False, solution_body="(define x 4)"):
    return {
        "handle": "alice", "slug": "nb", "title": "Intro", "summary": "A summary.",
        "cells": [
            cell(0, "prose", body="Welcome to the notebook."),
            cell(1, "code-eval", body="(+ 1 2)"),
            cell(2, "code-exercise", body="(define (sq x) x)", description="Square it.",
                 passed=passed,
                 test_cases=[{"input": "(sq 2)", "expected": "4", "description": None}]),
            cell(3, "code-solution", gated=True, unlocked=unlocked,
                 body=solution_body if unlocked else None),
            cell(4, "scene", body=None),
        ],
    }


def old_manifest_for(nb, files):
    """A manifest as a previous pull of NB would have left it; FILES maps
    file name -> content that was written."""
    width = recurya.index_width(len(nb["cells"]))
    cells = []
    for c in nb["cells"]:
        f = recurya.cell_file(c, width)
        cells.append({"index": c["index"], "cell_id": c["cell_id"], "kind": c["kind"],
                      "hash": recurya.content_hash(files[f]) if f in files else None,
                      "passed": False, "unlocked": c["unlocked"]})
    return {"handle": nb["handle"], "slug": nb["slug"], "title": nb["title"],
            "width": width, "cells": cells}


# --------------------------------------------------------------------------
# Stub HTTP server

class Stub:
    """A tiny scriptable API server.  routes: {(method, path): (status, obj | callable)};
    callable receives the request record and returns (status, obj, headers)."""

    def __init__(self):
        self.requests = []
        self.routes = {}
        stub = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *a):
                pass

            def _serve(self):
                length = int(self.headers.get("Content-Length") or 0)
                body = self.rfile.read(length) if length else b""
                rec = {"method": self.command, "path": self.path,
                       "headers": {k.lower(): v for k, v in self.headers.items()},
                       "body": body}
                stub.requests.append(rec)
                route = stub.routes.get((self.command, self.path.split("?")[0]))
                if route is None:
                    status, obj, headers = 404, {"error": {"code": "not_found",
                                                           "message": "nope"}}, {}
                else:
                    r = route(rec) if callable(route) else route
                    status, obj = r[0], r[1]
                    headers = r[2] if len(r) > 2 else {}
                data = json.dumps(obj).encode("utf-8")
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(data)))
                for k, v in headers.items():
                    self.send_header(k, v)
                self.end_headers()
                self.wfile.write(data)

            do_GET = do_POST = _serve

        self.httpd = HTTPServer(("127.0.0.1", 0), Handler)
        self.url = "http://127.0.0.1:%d" % self.httpd.server_address[1]
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.thread.start()

    def close(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        self.thread.join()


class EnvCase(unittest.TestCase):
    """Isolated config dir, cwd and environment per test."""

    def setUp(self):
        self._cwd = os.getcwd()
        self._env = dict(os.environ)
        self.tmp = tempfile.mkdtemp(prefix="recurya-test-")
        self.cfg = os.path.join(self.tmp, "cfg")
        os.environ["RECURYA_CONFIG_DIR"] = self.cfg
        os.environ.pop("RECURYA_SERVER", None)
        os.environ["no_proxy"] = "127.0.0.1,localhost"
        os.environ["NO_PROXY"] = "127.0.0.1,localhost"
        self.stubs = []

    def tearDown(self):
        os.chdir(self._cwd)
        os.environ.clear()
        os.environ.update(self._env)
        for s in self.stubs:
            s.close()
        shutil.rmtree(self.tmp, ignore_errors=True)

    def stub(self):
        s = Stub()
        self.stubs.append(s)
        return s

    def cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = recurya.main(list(argv))
        return code, out.getvalue(), err.getvalue()


# --------------------------------------------------------------------------
# 1-2. Names and initial code

class NamingTests(unittest.TestCase):
    def test_index_width(self):
        self.assertEqual(recurya.index_width(5), 2)
        self.assertEqual(recurya.index_width(100), 2)
        self.assertEqual(recurya.index_width(101), 3)
        self.assertEqual(recurya.index_width(0), 2)

    def test_cell_file_name(self):
        self.assertEqual(recurya.cell_file_name(3, "code-exercise", 2), "03-exercise.wl")
        self.assertEqual(recurya.cell_file_name(1, "code-eval", 3), "001-eval.wl")
        self.assertEqual(recurya.cell_file_name(4, "code-solution", 2), "04-solution.wl")
        self.assertIsNone(recurya.cell_file_name(0, "prose", 2))
        self.assertIsNone(recurya.cell_file_name(0, "scene", 2))

    def test_cell_file_name_rejects_bad_index(self):
        for bad in ("3", -1, True, "../x", None, 1.5):
            with self.assertRaises(recurya.WorkspaceError, msg=repr(bad)):
                recurya.cell_file_name(bad, "code-eval", 2)

    def test_initial_code(self):
        self.assertEqual(recurya.initial_code({"saved_code": "mine", "body": "b"}), "mine")
        self.assertEqual(recurya.initial_code({"saved_code": None, "body": "b"}), "b")
        self.assertEqual(recurya.initial_code({"saved_code": None, "body": None}), "")
        self.assertEqual(recurya.initial_code({"saved_code": "", "body": "b"}), "")

    def test_content_hash(self):
        self.assertEqual(recurya.content_hash("abc"),
                         "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")


# --------------------------------------------------------------------------
# 3. README

class ReadmeTests(unittest.TestCase):
    def test_readme_content(self):
        nb = sample_notebook()
        text = recurya.render_readme(nb, 2)
        for needle in ("# Intro", "A summary.", "Welcome to the notebook.",
                       "01-eval.wl", "02-exercise.wl", "Square it.", "(sq 2)",
                       "locked", "not supported", "recurya run 02"):
            self.assertIn(needle, text)
        self.assertNotIn("None", text)
        self.assertNotIn("null", text)

    def test_unlocked_solution_listed(self):
        text = recurya.render_readme(sample_notebook(unlocked=True), 2)
        self.assertIn("`03-solution.wl` (solution)", text)
        self.assertNotIn("locked", text)

    def test_null_description_and_summary_skipped(self):
        nb = sample_notebook()
        nb["summary"] = None
        nb["cells"][2]["description"] = None
        text = recurya.render_readme(nb, 2)
        self.assertNotIn("None", text)


# --------------------------------------------------------------------------
# 4. plan_pull

class PlanPullTests(unittest.TestCase):
    def test_fresh_pull(self):
        nb = sample_notebook()
        actions, manifest = recurya.plan_pull(nb, 2, None, {}, False)
        self.assertEqual([a[:2] for a in actions],
                         [("write", "01-eval.wl"), ("write", "02-exercise.wl")])
        self.assertEqual(actions[0][2], "(+ 1 2)")
        for c in manifest["cells"]:
            self.assertNotIn("file", c)
        self.assertEqual(manifest["width"], 2)
        self.assertEqual(manifest["handle"], "alice")
        self.assertEqual(len(manifest["cells"]), 5)
        self.assertEqual(manifest["cells"][1]["hash"], recurya.content_hash("(+ 1 2)"))
        self.assertIsNone(manifest["cells"][0]["hash"])

    def test_repull_unedited_is_written(self):
        nb = sample_notebook()
        files = {"01-eval.wl": "(+ 1 2)", "02-exercise.wl": "(define (sq x) x)"}
        old = old_manifest_for(nb, files)
        nb2 = sample_notebook()
        nb2["cells"][1]["body"] = "(+ 10 20)"
        actions, _ = recurya.plan_pull(nb2, 2, old, files, False)
        self.assertEqual(actions[0], ("write", "01-eval.wl", "(+ 10 20)"))

    def test_repull_edited_is_kept_and_hash_inherited(self):
        nb = sample_notebook()
        files = {"01-eval.wl": "(+ 1 2)", "02-exercise.wl": "(define (sq x) x)"}
        old = old_manifest_for(nb, files)
        edited = dict(files, **{"02-exercise.wl": "(define (sq x) (* x x))"})
        actions, manifest = recurya.plan_pull(nb, 2, old, edited, False)
        self.assertEqual(actions[1], ("keep", "02-exercise.wl"))
        self.assertEqual(manifest["cells"][2]["hash"], old["cells"][2]["hash"])

    def test_force_overwrites(self):
        nb = sample_notebook()
        files = {"01-eval.wl": "(+ 1 2)", "02-exercise.wl": "(define (sq x) x)"}
        old = old_manifest_for(nb, files)
        edited = dict(files, **{"02-exercise.wl": "mine"})
        actions, _ = recurya.plan_pull(nb, 2, old, edited, True)
        self.assertEqual(actions[1][0], "write")

    def test_no_old_manifest(self):
        nb = sample_notebook()
        actions, _ = recurya.plan_pull(nb, 2, None, {"01-eval.wl": "different"}, False)
        self.assertEqual(actions[0], ("keep", "01-eval.wl"))
        actions, _ = recurya.plan_pull(nb, 2, None, {"01-eval.wl": "(+ 1 2)"}, False)
        self.assertEqual(actions[0][0], "write")

    def test_unlocked_solution_written(self):
        nb = sample_notebook(unlocked=True)
        actions, manifest = recurya.plan_pull(nb, 2, None, {}, False)
        self.assertIn(("write", "03-solution.wl", "(define x 4)"), actions)
        self.assertTrue(manifest["cells"][3]["unlocked"])

    def test_cell_file(self):
        nb = sample_notebook()
        self.assertIsNone(recurya.cell_file(nb["cells"][0], 2))
        self.assertIsNone(recurya.cell_file(nb["cells"][3], 2))
        self.assertIsNone(recurya.cell_file(nb["cells"][4], 2))
        self.assertEqual(recurya.cell_file(nb["cells"][2], 2), "02-exercise.wl")


# --------------------------------------------------------------------------
# 5-6. collect_codes, resolve_cell_arg

def sample_manifest():
    return old_manifest_for(sample_notebook(), {})


class CodesAndArgsTests(unittest.TestCase):
    def test_collect_codes(self):
        m = sample_manifest()
        files = {"01-eval.wl": "(+ 1 2)"}
        codes = recurya.collect_codes(m, 2, lambda name: files.get(name))
        self.assertEqual(codes, ["", "(+ 1 2)", ""])

    def test_collect_codes_other_kinds_are_empty(self):
        m = sample_manifest()
        seen = []

        def read(name):
            seen.append(name)
            return "X"
        codes = recurya.collect_codes(m, 4, read)
        self.assertEqual(codes, ["", "X", "X", "", ""])
        self.assertEqual(seen, ["01-eval.wl", "02-exercise.wl"])

    def test_tampered_manifest_index_rejected(self):
        m = sample_manifest()
        m["cells"][1]["index"] = "../../etc"
        seen = []
        with self.assertRaises(recurya.WorkspaceError):
            recurya.collect_codes(m, 2, lambda n: seen.append(n))
        self.assertEqual(seen, [])

    def test_tampered_manifest_file_key_ignored(self):
        m = sample_manifest()
        m["cells"][1]["file"] = "/etc/passwd"
        seen = []
        recurya.collect_codes(m, 2, lambda n: seen.append(n))
        self.assertEqual(seen, ["01-eval.wl", "02-exercise.wl"])

    def test_resolve_cell_arg(self):
        m = sample_manifest()
        self.assertEqual(recurya.resolve_cell_arg("02", m), 2)
        self.assertEqual(recurya.resolve_cell_arg("2", m), 2)
        self.assertEqual(recurya.resolve_cell_arg("02-exercise.wl", m), 2)
        self.assertEqual(recurya.resolve_cell_arg("01-eval.wl", m), 1)

    def test_resolve_cell_arg_rejects(self):
        m = sample_manifest()
        for bad in ("0", "3", "99", "abc", "3abc", "01-solution.wl", "", "-1", "../02-exercise.wl",
                    "4", "²", "02-exercise.wl/"):
            with self.assertRaises(recurya.WorkspaceError, msg=repr(bad)):
                recurya.resolve_cell_arg(bad, m)


# --------------------------------------------------------------------------
# 7. Reports

class ReportTests(unittest.TestCase):
    def test_fail(self):
        r = {"status": "fail", "value": None, "output": "", "error": None,
             "tests": [{"input": "(sq 2)", "expected": "4", "actual": "3", "passed": False,
                        "error": None},
                       {"input": "(sq 1)", "expected": "1", "actual": "1", "passed": True,
                        "error": None}],
             "metrics": {"steps": 12, "cons": 3, "depth": 2}, "revealed_solutions": []}
        text = recurya.format_run_result(r, 2)
        self.assertIn("FAIL  1 of 2 tests failed", text)
        self.assertIn("expected 4", text)
        self.assertIn("got 3", text)
        self.assertIn("steps 12", text)
        self.assertIn("✗ (sq 2)", text)
        self.assertIn("✓ (sq 1)", text)
        self.assertEqual(recurya.result_exit_code(r), 1)

    def test_pass_and_unlocked(self):
        r = {"status": "pass", "tests": [{"input": "a", "expected": "1", "actual": "1",
                                          "passed": True}],
             "metrics": None, "revealed_solutions": [{"index": 4, "cell_id": "x", "body": "b"}]}
        text = recurya.format_run_result(r, 2)
        self.assertIn("PASS  all 1 test passed", text)
        self.assertIn("unlocked: 04-solution.wl", text)
        self.assertEqual(recurya.result_exit_code(r), 0)

    def test_error(self):
        r = {"status": "error", "error": "boom", "error_cell_index": 1, "tests": [],
             "output": "hello\n", "metrics": {"steps": 1, "cons": 0, "depth": 1}}
        text = recurya.format_run_result(r, 2)
        self.assertTrue(text.startswith("ERROR"))
        self.assertIn("error (cell 01): boom", text)
        self.assertIn("output:\nhello", text)
        self.assertEqual(recurya.result_exit_code(r), 1)

    def test_ok(self):
        r = {"status": "ok", "value": "3", "tests": [], "metrics": None}
        self.assertIn("OK    => 3", recurya.format_run_result(r, 2))
        self.assertEqual(recurya.result_exit_code(r), 0)

    def test_test_error_shown(self):
        r = {"status": "fail", "tests": [{"input": "(f)", "expected": "1", "actual": None,
                                          "passed": False, "error": "div by zero"}]}
        self.assertIn("got error: div by zero", recurya.format_run_result(r, 2))

    def test_list_and_status(self):
        text = recurya.format_notebook_list(
            {"items": [{"handle": "a", "slug": "s", "title": "T", "summary": None}],
             "page": 1, "per_page": 20, "total": 1})
        self.assertIn("@a/s  T", text)
        self.assertIn("-- page 1, 1 notebook in total", text)
        m = sample_manifest()
        m["cells"][2]["passed"] = True
        st = recurya.format_status(m, ["02-exercise.wl"])
        self.assertIn("@alice/nb  Intro", st)
        self.assertIn("01-eval.wl", st)
        line = [l for l in st.splitlines() if "02-exercise.wl" in l][0]
        self.assertIn("passed", line)
        self.assertIn("modified", line)
        line1 = [l for l in st.splitlines() if "01-eval.wl" in l][0]
        self.assertNotIn("modified", line1)
        self.assertNotIn("03-solution.wl", st)


# --------------------------------------------------------------------------
# 8-10. Config and credentials

class ServerTests(unittest.TestCase):
    def test_normalize_server(self):
        self.assertEqual(recurya.normalize_server("https://x.example.com/"), "https://x.example.com")
        self.assertEqual(recurya.normalize_server("http://localhost:13000"),
                         "http://localhost:13000")
        self.assertEqual(recurya.normalize_server("http://127.0.0.1:1/"), "http://127.0.0.1:1")
        self.assertEqual(recurya.normalize_server("http://[::1]:80"), "http://[::1]:80")

    def test_normalize_server_rejects(self):
        for bad in ("http://example.com", "ftp://example.com", "example.com", "",
                    "https://", "https://user:pw@example.com", "http://localhost.evil.com",
                    "https://example.com?x=1"):
            with self.assertRaises(recurya.UsageError, msg=bad):
                recurya.normalize_server(bad)


class CredentialTests(unittest.TestCase):
    CFG = {"server": "https://a.example.com", "token": "TOK"}

    def test_priority(self):
        env = {"RECURYA_SERVER": "https://b.example.com"}
        self.assertEqual(recurya.resolve_credentials("https://c.example.com", "T", env, self.CFG),
                         ("https://c.example.com", "T"))
        self.assertEqual(recurya.resolve_credentials(None, "T", env, self.CFG),
                         ("https://b.example.com", "T"))
        self.assertEqual(recurya.resolve_credentials(None, None, {}, self.CFG),
                         ("https://a.example.com", "TOK"))
        self.assertEqual(recurya.resolve_credentials("https://a.example.com/", None, {}, self.CFG),
                         ("https://a.example.com", "TOK"))

    def test_other_server_without_token_refused(self):
        with self.assertRaises(recurya.UsageError) as cm:
            recurya.resolve_credentials("https://evil.example.com", None, {}, self.CFG)
        self.assertIn("belongs to https://a.example.com", str(cm.exception))
        self.assertIn("recurya login --server https://evil.example.com", str(cm.exception))
        with self.assertRaises(recurya.UsageError):
            recurya.resolve_credentials(None, None, {"RECURYA_SERVER": "https://evil.example.com"},
                                        self.CFG)

    def test_not_logged_in(self):
        with self.assertRaises(recurya.UsageError) as cm:
            recurya.resolve_credentials(None, None, {}, None)
        self.assertIn("Not logged in. Run: recurya login --server URL", str(cm.exception))


class ConfigTests(EnvCase):
    def test_save_and_load(self):
        self.assertIsNone(recurya.load_config())
        recurya.save_config("http://localhost:1", "secret")
        self.assertEqual(recurya.load_config(), {"server": "http://localhost:1", "token": "secret"})
        self.assertEqual(stat.S_IMODE(os.stat(self.cfg).st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(os.stat(os.path.join(self.cfg, "config.json")).st_mode),
                         0o600)

    def test_rewrite_keeps_0600(self):
        recurya.save_config("http://localhost:1", "a")
        path = os.path.join(self.cfg, "config.json")
        os.chmod(path, 0o644)
        recurya.save_config("http://localhost:1", "b")
        self.assertEqual(stat.S_IMODE(os.stat(path).st_mode), 0o600)

    def test_config_dir_resolution(self):
        self.assertEqual(recurya.config_dir({"RECURYA_CONFIG_DIR": "/x"}), "/x")
        self.assertEqual(recurya.config_dir({"XDG_CONFIG_HOME": "/y"}), os.path.join("/y", "recurya"))
        self.assertTrue(recurya.config_dir({"HOME": "/h"}).endswith(os.path.join(".config", "recurya")))

    def test_corrupt_config(self):
        os.makedirs(self.cfg)
        Path(self.cfg, "config.json").write_text("{nope")
        with self.assertRaises(recurya.UsageError):
            recurya.load_config()


# --------------------------------------------------------------------------
# 11. Commands against the stub

def api_routes(stub, nb=None, run_result=None):
    nb = nb or sample_notebook()
    stub.routes[("GET", "/api/v1/me")] = (200, {"handle": "alice", "display_name": "Alice"})
    stub.routes[("GET", "/api/v1/notebooks")] = (
        200, {"items": [{"handle": "alice", "slug": "nb", "title": "Intro", "summary": None}],
              "page": 1, "per_page": 20, "total": 1})
    stub.routes[("GET", "/api/v1/notebooks/alice/nb")] = (200, nb)
    if run_result is not None:
        stub.routes[("POST", "/api/v1/notebooks/alice/nb/cells/2/run")] = (200, run_result)


FAIL_RESULT = {"status": "fail", "value": None, "output": "", "error": None,
               "error_cell_index": None,
               "tests": [{"input": "(sq 2)", "expected": "4", "actual": "2", "passed": False,
                          "error": None}],
               "metrics": {"steps": 5, "cons": 0, "depth": 1}, "revealed_solutions": []}
PASS_RESULT = {"status": "pass", "value": None, "output": "", "error": None,
               "error_cell_index": None,
               "tests": [{"input": "(sq 2)", "expected": "4", "actual": "4", "passed": True,
                          "error": None}],
               "metrics": {"steps": 5, "cons": 0, "depth": 1},
               "revealed_solutions": [{"index": 3, "cell_id": "c3", "body": "(define x 4)"}]}


class CommandTests(EnvCase):
    def login(self, stub):
        code, out, err = self.cli("login", "--server", stub.url, "--token", "TKN")
        self.assertEqual(code, 0, err)
        return out

    def pull(self, stub):
        d = os.path.join(self.tmp, "ws")
        code, out, err = self.cli("pull", "@alice/nb", d)
        self.assertEqual(code, 0, err)
        return d, out

    def test_login(self):
        s = self.stub()
        api_routes(s)
        out = self.login(s)
        self.assertIn("Logged in to %s as @alice" % s.url, out)
        self.assertEqual(recurya.load_config(), {"server": s.url, "token": "TKN"})
        req = s.requests[0]
        self.assertEqual(req["headers"]["authorization"], "Bearer TKN")
        self.assertEqual(req["headers"]["accept"], "application/json")
        self.assertEqual(req["headers"]["user-agent"], "recurya-cli/1")

    def test_login_uses_getpass_without_flag(self):
        s = self.stub()
        api_routes(s)
        calls = []
        orig = recurya.getpass.getpass
        recurya.getpass.getpass = lambda prompt="": calls.append(prompt) or "  PW \n"
        try:
            code, out, err = self.cli("login", "--server", s.url)
        finally:
            recurya.getpass.getpass = orig
        self.assertEqual(code, 0, err)
        self.assertEqual(len(calls), 1)
        self.assertEqual(s.requests[0]["headers"]["authorization"], "Bearer PW")

    def test_login_failure_saves_nothing(self):
        s = self.stub()
        s.routes[("GET", "/api/v1/me")] = (401, {"error": {"code": "unauthorized",
                                                          "message": "bad token"}})
        code, out, err = self.cli("login", "--server", s.url, "--token", "x")
        self.assertEqual(code, 2)
        self.assertIsNone(recurya.load_config())

    def test_login_needs_server(self):
        code, out, err = self.cli("login", "--token", "x")
        self.assertEqual(code, 2)
        self.assertIn("--server", err)

    def test_login_rejects_insecure_server(self):
        code, out, err = self.cli("login", "--server", "http://example.com", "--token", "x")
        self.assertEqual(code, 2)

    def test_list(self):
        s = self.stub()
        api_routes(s)
        self.login(s)
        code, out, err = self.cli("list")
        self.assertEqual(code, 0, err)
        self.assertIn("@alice/nb  Intro", out)
        self.assertEqual(s.requests[-1]["path"], "/api/v1/notebooks?page=1")
        self.cli("list", "--page", "3")
        self.assertEqual(s.requests[-1]["path"], "/api/v1/notebooks?page=3")

    def test_pull(self):
        s = self.stub()
        api_routes(s)
        self.login(s)
        d, out = self.pull(s)
        self.assertIn("Pulled @alice/nb", out)
        self.assertEqual(sorted(os.listdir(d)), [".recurya", "01-eval.wl", "02-exercise.wl",
                                                 "README.md"])
        self.assertEqual(Path(d, "01-eval.wl").read_text(), "(+ 1 2)")
        self.assertIn("Square it.", Path(d, "README.md").read_text())
        m = json.loads(Path(d, ".recurya/notebook.json").read_text())
        self.assertEqual(m["server"], s.url)
        self.assertEqual(m["width"], 2)
        self.assertTrue(all("file" not in c for c in m["cells"]))

    def test_pull_default_dir_and_kept_message(self):
        s = self.stub()
        api_routes(s)
        self.login(s)
        os.chdir(self.tmp)
        code, out, err = self.cli("pull", "@alice/nb")
        self.assertEqual(code, 0, err)
        self.assertTrue(os.path.isdir(os.path.join(self.tmp, "nb", ".recurya")))
        Path(self.tmp, "nb", "02-exercise.wl").write_text("edited")
        code, out, err = self.cli("pull", "@alice/nb")
        self.assertIn("kept (edited locally): 02-exercise.wl", out)
        self.assertEqual(Path(self.tmp, "nb", "02-exercise.wl").read_text(), "edited")
        code, out, err = self.cli("pull", "@alice/nb", "--force")
        self.assertEqual(Path(self.tmp, "nb", "02-exercise.wl").read_text(), "(define (sq x) x)")

    def test_pull_bad_ref(self):
        s = self.stub()
        api_routes(s)
        self.login(s)
        for ref in ("alice", "@alice/", "@/nb", "@alice/.."):
            code, out, err = self.cli("pull", ref, os.path.join(self.tmp, "x"))
            self.assertEqual(code, 2, ref)

    def test_pull_ignores_hostile_server_index(self):
        s = self.stub()
        nb = sample_notebook()
        nb["cells"][1]["index"] = "../../evil"
        api_routes(s, nb)
        self.login(s)
        d = os.path.join(self.tmp, "ws")
        code, out, err = self.cli("pull", "@alice/nb", d)
        self.assertEqual(code, 2)
        self.assertFalse(os.path.exists(os.path.join(self.tmp, "evil")))

    def test_run_fail_then_pass_with_reveal(self):
        s = self.stub()
        api_routes(s, run_result=FAIL_RESULT)
        self.login(s)
        d, _ = self.pull(s)
        os.chdir(d)
        Path(d, "02-exercise.wl").write_text("(define (sq x) (* x x))")
        code, out, err = self.cli("run", "2")
        self.assertEqual(code, 1, err)
        self.assertIn("FAIL  1 of 1 test failed", out)
        post = [r for r in s.requests if r["method"] == "POST"][-1]
        self.assertEqual(post["headers"]["content-type"], "application/json")
        self.assertEqual(json.loads(post["body"]), {"codes": ["", "(+ 1 2)",
                                                              "(define (sq x) (* x x))"]})
        # now it passes and reveals the solution
        s.routes[("POST", "/api/v1/notebooks/alice/nb/cells/2/run")] = (200, PASS_RESULT)
        s.routes[("GET", "/api/v1/notebooks/alice/nb")] = (
            200, sample_notebook(unlocked=True, passed=True))
        code, out, err = self.cli("run", "02-exercise.wl")
        self.assertEqual(code, 0, err)
        self.assertIn("unlocked: 03-solution.wl", out)
        self.assertEqual(Path(d, "03-solution.wl").read_text(), "(define x 4)")
        # the edited exercise file is not clobbered
        self.assertEqual(Path(d, "02-exercise.wl").read_text(), "(define (sq x) (* x x))")
        m = json.loads(Path(d, ".recurya/notebook.json").read_text())
        self.assertTrue(m["cells"][2]["passed"])
        self.assertTrue(m["cells"][3]["unlocked"])
        self.assertEqual(m["server"], s.url)
        self.assertIn("03-solution.wl", Path(d, "README.md").read_text())

    def test_run_pass_without_reveal_updates_passed(self):
        s = self.stub()
        res = dict(PASS_RESULT, revealed_solutions=[])
        api_routes(s, run_result=res)
        self.login(s)
        d, _ = self.pull(s)
        os.chdir(d)
        code, out, err = self.cli("run", "2")
        self.assertEqual(code, 0, err)
        m = json.loads(Path(d, ".recurya/notebook.json").read_text())
        self.assertTrue(m["cells"][2]["passed"])

    def test_run_rejects_prose_and_outside_workspace(self):
        s = self.stub()
        api_routes(s, run_result=FAIL_RESULT)
        self.login(s)
        d, _ = self.pull(s)
        os.chdir(d)
        n = len(s.requests)
        self.assertEqual(self.cli("run", "0")[0], 2)
        self.assertEqual(len(s.requests), n)
        os.chdir(self.tmp)
        code, out, err = self.cli("run", "2")
        self.assertEqual(code, 2)
        self.assertIn("recurya pull", err)

    def test_status(self):
        s = self.stub()
        api_routes(s)
        self.login(s)
        d, _ = self.pull(s)
        os.chdir(d)
        code, out, err = self.cli("status")
        self.assertEqual(code, 0, err)
        self.assertIn("01-eval.wl", out)
        self.assertNotIn("modified", out)
        Path(d, "01-eval.wl").write_text("changed")
        code, out, err = self.cli("status")
        line = [l for l in out.splitlines() if "01-eval.wl" in l][0]
        self.assertIn("modified", line)

    def test_redirect_not_followed(self):
        target = self.stub()
        api_routes(target)
        s = self.stub()
        s.routes[("GET", "/api/v1/me")] = (302, {}, {"Location": target.url + "/api/v1/me"})
        code, out, err = self.cli("login", "--server", s.url, "--token", "TKN")
        self.assertEqual(code, 2)
        self.assertIn("redirected", err)
        self.assertEqual(target.requests, [])
        self.assertIsNone(recurya.load_config())

    def test_401_guidance(self):
        s = self.stub()
        api_routes(s)
        self.login(s)
        s.routes[("GET", "/api/v1/notebooks")] = (
            401, {"error": {"code": "unauthorized", "message": "token revoked"}})
        code, out, err = self.cli("list")
        self.assertEqual(code, 2)
        self.assertIn("Not authorized: token revoked", err)
        self.assertIn("recurya login", err)

    def test_other_api_error(self):
        s = self.stub()
        api_routes(s)
        self.login(s)
        s.routes[("GET", "/api/v1/notebooks")] = (
            503, {"error": {"code": "unavailable", "message": "try later"}})
        code, out, err = self.cli("list")
        self.assertEqual(code, 2)
        self.assertIn("Server said: try later", err)

    def test_non_json_error_body(self):
        s = self.stub()
        api_routes(s)
        self.login(s)
        s.routes[("GET", "/api/v1/notebooks")] = lambda rec: (500, "oops")
        code, out, err = self.cli("list")
        self.assertEqual(code, 2)
        self.assertIn("500", err)

    def test_connection_refused(self):
        s = self.stub()
        api_routes(s)
        self.login(s)
        s.close()
        self.stubs.remove(s)
        code, out, err = self.cli("list")
        self.assertEqual(code, 2)
        self.assertTrue(err.strip())

    def test_http_loopback_ignores_proxy_env(self):
        s = self.stub()
        api_routes(s)
        self.login(s)
        os.environ["http_proxy"] = "http://127.0.0.1:9"   # nothing listens there
        os.environ.pop("no_proxy", None)
        os.environ.pop("NO_PROXY", None)
        before = len(s.requests)
        code, out, err = self.cli("list")
        self.assertEqual(code, 0, err)
        self.assertGreater(len(s.requests), before)

    def test_env_server_other_than_saved_blocks_token(self):
        saved = self.stub()
        api_routes(saved)
        self.login(saved)
        other = self.stub()
        api_routes(other)
        os.environ["RECURYA_SERVER"] = other.url
        code, out, err = self.cli("list")
        self.assertEqual(code, 2)
        self.assertIn("recurya login --server", err)
        self.assertEqual(other.requests, [])

    def test_run_refuses_manifest_server_mismatch(self):
        s = self.stub()
        api_routes(s, run_result=FAIL_RESULT)
        self.login(s)
        d, _ = self.pull(s)
        mpath = Path(d, ".recurya/notebook.json")
        m = json.loads(mpath.read_text())
        m["server"] = "https://elsewhere.example.com"
        mpath.write_text(json.dumps(m))
        os.chdir(d)
        n = len(s.requests)
        code, out, err = self.cli("run", "2")
        self.assertEqual(code, 2)
        self.assertEqual(len(s.requests), n)
        self.assertIn("elsewhere.example.com", err)

    def test_tampered_manifest_does_not_read_outside(self):
        s = self.stub()
        api_routes(s, run_result=FAIL_RESULT)
        self.login(s)
        d, _ = self.pull(s)
        mpath = Path(d, ".recurya/notebook.json")
        m = json.loads(mpath.read_text())
        m["cells"][1]["index"] = "../../etc/passwd"
        mpath.write_text(json.dumps(m))
        os.chdir(d)
        n = len(s.requests)
        code, out, err = self.cli("run", "2")
        self.assertEqual(code, 2)
        self.assertEqual(len(s.requests), n)

    def test_unexpected_exception_mapped(self):
        orig = recurya.cmd_list
        recurya.cmd_list = lambda *a, **k: 1 / 0
        try:
            code, out, err = self.cli("list")
        finally:
            recurya.cmd_list = orig
        self.assertEqual(code, 2)
        self.assertIn("unexpected error", err)

    def test_keyboard_interrupt(self):
        orig = recurya.cmd_list

        def boom(*a, **k):
            raise KeyboardInterrupt()
        recurya.cmd_list = boom
        try:
            code, out, err = self.cli("list")
        finally:
            recurya.cmd_list = orig
        self.assertEqual(code, 130)


# --------------------------------------------------------------------------
# 12. Entry point

class MainTests(EnvCase):
    def test_no_args(self):
        code, out, err = self.cli()
        self.assertEqual(code, 2)
        self.assertIn("usage", (out + err).lower())

    def test_unknown_command(self):
        code, out, err = self.cli("frobnicate")
        self.assertEqual(code, 2)

    def test_unknown_option(self):
        code, out, err = self.cli("list", "--bogus")
        self.assertEqual(code, 2)

    def test_version(self):
        code, out, err = self.cli("--version")
        self.assertEqual(code, 0)
        self.assertIn("recurya", out + err)

    def test_list_not_logged_in(self):
        code, out, err = self.cli("list")
        self.assertEqual(code, 2)
        self.assertIn("Not logged in", err)


if __name__ == "__main__":
    unittest.main()
