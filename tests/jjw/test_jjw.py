from __future__ import annotations

import io
import os
import re
import shutil
import tempfile
import time
import unittest
from contextlib import contextmanager, redirect_stdout
from pathlib import Path
from unittest import mock

from fixtures import advance_origin, commit, git, jj, jj_commit, mkgit, mkgit_origin, mkjj_clone, sh, use_test_env

from jjw import main
from libjjw.git import GitRepo
from libjjw.github import PR, ci_state, github_slug
from libjjw.jj import JjRepo
from libjjw.proc import error_line
from libjjw.repo import is_trunk
from libjjw.style import age, colorize
from libjjw.workspace import discover, repo_at

colorize.enabled = False

HAS_JJ = shutil.which("jj") is not None


@contextmanager
def cwd(path: Path):
    old = Path.cwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(old)


def run_jjw(where: Path, *args: str) -> str:
    out = io.StringIO()
    with cwd(where), redirect_stdout(out):
        main(list(args))
    return out.getvalue()


def block(name: str, out: str) -> str:
    """Commit lines under the header line of bookmark or branch `name`."""
    m = re.search(rf"^    {re.escape(name)}\b.*\n((?:     +.*\n?)*)", out, re.M)
    return m.group(1) if m else ""


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.patch(mock.patch.dict(os.environ))
        use_test_env(self.tmp)

    def patch(self, patcher) -> None:
        patcher.start()
        self.addCleanup(patcher.stop)


class TestPrimitives(unittest.TestCase):
    def test_is_trunk(self):
        for name in ("main", "master", "develop", "release/1.0", ""):
            self.assertTrue(is_trunk(name), name)
        for name in ("my-feature", "releasey"):
            self.assertFalse(is_trunk(name), name)

    def test_github_slug(self):
        self.assertEqual(github_slug("git@github.com:o/r.git"), "o/r")
        self.assertEqual(github_slug("https://github.com/o/r"), "o/r")
        self.assertIsNone(github_slug("https://gitlab.com/o/r"))

    def test_ci_state(self):
        self.assertEqual(ci_state([]), "")
        self.assertEqual(ci_state([{"conclusion": "SUCCESS"}, {"state": "FAILURE"}]), "fail")
        self.assertEqual(ci_state([{"conclusion": "SUCCESS"}, {"conclusion": "", "status": "IN_PROGRESS"}]), "pending")
        self.assertEqual(ci_state([{"conclusion": "SUCCESS"}, {"state": "SUCCESS"}]), "pass")

    def test_age(self):
        now = int(time.time())
        self.assertEqual(age(now + 100), "0s")
        self.assertEqual(age(now - 90), "1m")
        self.assertEqual(age(now - 3 * 86400), "3d")

    def test_error_line(self):
        self.assertEqual(error_line("Warning: x\nError: boom\nHint: y"), "Error: boom")
        self.assertEqual(error_line("one\ntwo\n"), "two")
        self.assertEqual(error_line(""), "failed")

    def test_pr_label(self):
        self.assertEqual(PR(3, "MERGED").label(), "#3 merged")
        self.assertEqual(
            PR(7, "OPEN", draft=True, review="CHANGES_REQUESTED", ci="pending").label(),
            "#7  draft  changes requested  ● ci",
        )


class TestGit(Base):
    def test_repo_type(self):
        self.assertIsInstance(repo_at(mkgit(self.tmp / "g")), GitRepo)
        (self.tmp / "plain").mkdir()
        self.assertIsNone(repo_at(self.tmp / "plain"))

    def test_trunk_precedence(self):
        self.assertEqual(GitRepo(mkgit(self.tmp / "dev", "develop")).trunk(), "develop")
        r = mkgit(self.tmp / "md", "master")
        git(r, "branch", "develop")
        self.assertEqual(GitRepo(r).trunk(), "master")
        r = mkgit(self.tmp / "all", "main")
        git(r, "branch", "master")
        git(r, "branch", "develop")
        self.assertEqual(GitRepo(r).trunk(), "main")

    def test_trunk_prefers_upstream(self):
        r = mkgit_origin(self.tmp / "up", self.tmp / "up.git")
        git(r, "branch", "master")
        git(r, "push", "-q", "origin", "master")
        git(r, "switch", "-q", "master")
        git(r, "branch", "--set-upstream-to=origin/master", "master")
        self.assertEqual(GitRepo(r).trunk(), "master")

    def test_trunk_prefers_origin_head(self):
        seed = mkgit(self.tmp / "seed", "master")
        git(seed, "branch", "develop")
        sh("git", "init", "-q", "--bare", str(self.tmp / "head.git"))
        git(seed, "remote", "add", "origin", str(self.tmp / "head.git"))
        git(seed, "push", "-q", "origin", "master", "develop")
        git(self.tmp / "head.git", "symbolic-ref", "HEAD", "refs/heads/develop")
        sh("git", "clone", "-q", str(self.tmp / "head.git"), str(self.tmp / "head"))
        git(self.tmp / "head", "branch", "master", "origin/master")
        self.assertEqual(GitRepo(self.tmp / "head").trunk(), "develop")

    def test_discover_children(self):
        ws = self.tmp / "ws"
        mkgit(ws / "repo-b")
        mkgit(ws / "Repo-a")
        (ws / "plain-dir").mkdir()
        with cwd(ws):
            self.assertEqual([r.name for r in discover([])], ["Repo-a", "repo-b"])

    def test_discover_current_repo(self):
        r = mkgit(self.tmp / "ws" / "repo")
        (r / "sub").mkdir()
        with cwd(r / "sub"):
            self.assertEqual([r.path for r in discover([])], [r.resolve()])

    def test_discover_dedupes_worktrees(self):
        ws = self.tmp / "ws"
        r = mkgit(ws / "a")
        git(r, "worktree", "add", "-q", str(ws / "b"))
        with cwd(ws):
            self.assertEqual([r.name for r in discover([])], ["a"])

    def test_st_feature(self):
        r = mkgit(self.tmp / "ws" / "repo")
        git(r, "switch", "-qc", "feat")
        commit(r, "feature work")
        out = run_jjw(self.tmp / "ws", "st")
        self.assertEqual(out.splitlines()[0], "repo  [feat]")
        self.assertIn("feature work", out)

    def test_pull(self):
        ws = self.tmp / "ws"
        mkgit_origin(ws / "on-trunk", self.tmp / "on-trunk.git")
        advance_origin(self.tmp / "on-trunk.git", self.tmp / "clone", "upstream commit")
        mkgit_origin(ws / "clean-feat", self.tmp / "clean-feat.git")
        git(ws / "clean-feat", "switch", "-qc", "my-feature")
        mkgit_origin(ws / "dirty-feat", self.tmp / "dirty-feat.git")
        git(ws / "dirty-feat", "switch", "-qc", "my-feature")
        (ws / "dirty-feat" / "uncommitted").write_text("dirty")

        out = run_jjw(ws, "pull", "on-trunk", "clean-feat", "dirty-feat").splitlines()
        self.assertEqual(out, [
            "✓ on-trunk  pulled main",
            "✓ clean-feat  switched to main + pulled",
            "· dirty-feat  dirty; fetched trunk only",
        ])
        self.assertEqual(GitRepo(ws / "clean-feat").ref(), "main")
        self.assertEqual(GitRepo(ws / "dirty-feat").ref(), "my-feature")
        self.assertIn("upstream commit", git(ws / "on-trunk", "log", "--oneline"))

    def test_pull_without_trunk(self):
        mkgit(self.tmp / "ws" / "repo", "feat")
        self.assertEqual(run_jjw(self.tmp / "ws", "pull").strip(), "· repo  no trunk branch found")

    def test_wip_nothing(self):
        r = mkgit_origin(self.tmp / "ws" / "repo", self.tmp / "repo.git")
        self.assertEqual(run_jjw(r, "wip", "--no-gh").strip(), "nothing in progress")


def fake_prs(slug):
    return {
        "feat-pushed": PR(7, "OPEN", review="APPROVED", ci="pass"),
        "feat-base": PR(3, "MERGED"),
        "g-pushed": PR(9, "OPEN", draft=True, ci="fail"),
    }, True


class WipBase(Base):
    def setUp(self):
        super().setUp()
        self.patch(mock.patch("libjjw.repo.github_slug", lambda url: "o/r"))
        self.patch(mock.patch("libjjw.repo.gh_prs", fake_prs))


class TestWipGit(WipBase):
    def test_wip(self):
        r = mkgit_origin(self.tmp / "wip", self.tmp / "wip.git")
        git(r, "branch", "-q", "g-merged")
        git(r, "switch", "-qc", "g-pushed")
        commit(r, "pushed one")
        git(r, "push", "-q", "-u", "origin", "g-pushed")
        commit(r, "pushed two")
        git(r, "switch", "-q", "main")
        git(r, "switch", "-qc", "g-local")
        commit(r, "local one", date="2020-01-01T00:00:00")
        git(r, "switch", "-qc", "g-stack")
        commit(r, "stack one", date="2021-01-01T00:00:00")
        git(r, "switch", "-q", "main")
        commit(r, "main two")
        git(r, "push", "-q", "origin", "main")
        git(r, "switch", "-q", "g-stack")

        out = run_jjw(r, "wip")
        self.assertIn("g-local  ↑ not pushed  1 behind trunk", out)
        self.assertIn("g-stack (HEAD)  ↑ not pushed  1 behind trunk  on g-local", out)
        self.assertIn("g-pushed  #9  draft  ✗ ci  ↑1", out)
        self.assertNotIn("g-merged", out)
        self.assertLess(out.index("No PR"), out.index("Open PRs"))
        self.assertLess(out.index("g-stack"), out.index("g-local"))
        self.assertIn("stack one", block("g-stack", out))
        self.assertNotIn("local one", block("g-stack", out))


@unittest.skipUnless(HAS_JJ, "jj not installed")
class TestJj(Base):
    def setUp(self):
        super().setUp()
        mkgit_origin(self.tmp / "seed", self.tmp / "origin.git")
        self.repo = mkjj_clone(self.tmp / "origin.git", self.tmp / "ws" / "repo")

    def test_trunk_and_ref(self):
        r = JjRepo(self.repo)
        self.assertEqual(r.trunk(), "main")
        jj_commit(self.repo, "feat 1", "main@origin")
        jj(self.repo, "bookmark", "create", "my-feature", "-r", "@")
        jj(self.repo, "new")
        self.assertEqual(r.ref(), "my-feature")
        self.assertTrue(r.has_bookmark("my-feature"))
        self.assertFalse(r.has_bookmark("nope"))

    def test_st_feature(self):
        jj_commit(self.repo, "feat 1", "main@origin")
        jj(self.repo, "bookmark", "create", "my-feature", "-r", "@")
        jj(self.repo, "new")
        out = run_jjw(self.tmp / "ws", "st")
        self.assertEqual(out.splitlines()[0], "repo  [my-feature]")
        self.assertIn("feat 1", out)
        self.assertIn("(empty)", out)

    def test_pull_moves_to_trunk(self):
        advance_origin(self.tmp / "origin.git", self.tmp / "clone", "upstream commit")
        out = run_jjw(self.tmp / "ws", "pull")
        self.assertEqual(out.strip(), "✓ repo  new main@origin")
        self.assertIn("upstream commit", jj(self.repo, "log", "--no-graph", "-r", "@-", "-T", "description"))

    def test_pull_keeps_feature(self):
        jj_commit(self.repo, "feat 1", "main@origin")
        jj(self.repo, "bookmark", "create", "my-feature", "-r", "@")
        out = run_jjw(self.tmp / "ws", "pull")
        self.assertEqual(out.strip(), "· repo  fetched; left on my-feature")


@unittest.skipUnless(HAS_JJ, "jj not installed")
class TestWipJj(WipBase):
    def test_wip(self):
        mkgit_origin(self.tmp / "seed", self.tmp / "origin.git")
        ws = self.tmp / "ws"
        r = mkjj_clone(self.tmp / "origin.git", ws / "repo")
        jj_commit(r, "pushed one", "main@origin")
        jj(r, "bookmark", "create", "feat-pushed", "-r", "@")
        jj(r, "bookmark", "track", "feat-pushed", "--remote", "origin")
        jj(r, "git", "push", "-b", "feat-pushed")
        jj_commit(r, "pushed two")
        jj(r, "bookmark", "set", "feat-pushed", "-r", "@")
        jj_commit(r, "above pushed")
        jj_commit(r, "base one", "main@origin")
        jj(r, "bookmark", "create", "feat-base", "-r", "@")
        jj_commit(r, "top one")
        jj(r, "bookmark", "create", "feat-top", "-r", "@")
        jj_commit(r, "loose one", "main@origin")
        jj(r, "new")
        jj(r, "workspace", "add", "--name", "second", str(ws / "second"))

        out = run_jjw(r, "wip")
        self.assertIn("feat-pushed  #7  approved  ✓ ci  ↑1", out)
        self.assertIn("+ ", out)
        self.assertIn("above pushed", block("feat-pushed", out))
        self.assertIn("feat-base  #3 merged  ↑ not pushed", out)
        self.assertIn("feat-top  ↑ not pushed  on feat-base", out)
        self.assertIn("top one", block("feat-top", out))
        self.assertNotIn("base one", block("feat-top", out))
        self.assertIn("loose one", out.split("Without bookmark")[1])
        self.assertNotIn("(no description)", out)
        self.assertLess(out.index("No PR"), out.index("Open PRs"))
        self.assertLess(out.index("Open PRs"), out.index("Without bookmark"))

        out = run_jjw(r, "wip", "--no-gh")
        self.assertNotIn("#7", out)
        self.assertNotIn("Open PRs", out)

        with cwd(ws):
            self.assertEqual([x.name for x in discover([])], ["repo"])


@unittest.skipUnless(HAS_JJ, "jj not installed")
class TestWipRebaseJj(Base):
    def setUp(self):
        super().setUp()
        mkgit_origin(self.tmp / "seed", self.tmp / "origin.git")
        self.ws = self.tmp / "ws"
        self.repo = mkjj_clone(self.tmp / "origin.git", self.ws / "repo")

    def bookmark(self, name: str, message: str, *new_args: str) -> None:
        jj_commit(self.repo, message, *new_args)
        jj(self.repo, "bookmark", "create", name, "-r", "@")

    def push(self, name: str) -> None:
        jj(self.repo, "bookmark", "track", name, "--remote", "origin")
        jj(self.repo, "git", "push", "-b", name)

    def on_trunk(self, name: str) -> bool:
        return bool(jj(self.repo, "log", "--no-graph", "-r", f'bookmarks(exact:"{name}") & main@origin::', "-T", '"x"'))

    def advance(self) -> None:
        advance_origin(self.tmp / "origin.git", self.tmp / "clone", "upstream commit")

    def test_default_skips_pushed(self):
        self.bookmark("local", "local one", "main@origin")
        self.bookmark("pushed", "pushed one", "main@origin")
        self.push("pushed")
        self.bookmark("stacked", "stacked one")
        jj(self.repo, "new", "main@origin")
        self.advance()

        skipped = ["· repo  pushed  has pushed commits; skipped", "· repo  stacked  has pushed commits; skipped"]
        out = run_jjw(self.repo, "wip-rebase", "--fetch").splitlines()
        self.assertEqual(out[:-1], ["✓ repo  local  rebased", *skipped])
        self.assertRegex(out[-1], r"^↶ repo  undo: jj op restore \w+$")
        self.assertTrue(self.on_trunk("local"))
        self.assertFalse(self.on_trunk("pushed"))
        self.assertEqual(run_jjw(self.repo, "wip-rebase").splitlines(), skipped)

    def test_all_and_branch(self):
        self.bookmark("pushed", "pushed one", "main@origin")
        self.push("pushed")
        self.bookmark("other", "other one", "main@origin")
        self.push("other")
        jj(self.repo, "new", "main@origin")
        self.advance()
        jj(self.repo, "git", "fetch")

        self.assertEqual(run_jjw(self.repo, "wip-rebase", "pushed").splitlines()[0], "✓ repo  pushed  rebased")
        self.assertFalse(self.on_trunk("other"))
        self.assertEqual(run_jjw(self.repo, "wip-rebase", "pushed").strip(), "· repo  pushed  up to date")
        self.assertEqual(run_jjw(self.repo, "wip-rebase", "nope").strip(), "no bookmark nope")
        self.assertEqual(run_jjw(self.repo, "wip-rebase", "-a").splitlines()[0], "✓ repo  other  rebased")
        self.assertTrue(self.on_trunk("other"))

    def test_updates_stale_workspace(self):
        self.bookmark("local", "local one", "main@origin")
        jj(self.repo, "new", "main@origin")
        second = self.ws / "second"
        jj(self.repo, "workspace", "add", "--name", "second", "-r", "local", str(second))
        (second / "dirty").write_text("dirty")
        self.advance()

        out = run_jjw(self.repo, "wip-rebase", "-f").splitlines()
        self.assertEqual(out[:2], ["✓ repo  local  rebased", "✓ repo  workspace second  updated stale working copy"])
        self.assertEqual((second / "dirty").read_text(), "dirty")
        self.assertTrue((second / "upstream-commit").exists())
        self.assertEqual(jj(self.repo, "log", "--no-graph", "-r", "divergent()", "-T", '"x"'), "")
        self.assertIn("dirty", jj(second, "diff", "--name-only"))

    def test_dry_run(self):
        self.bookmark("base", "base one", "main@origin")
        self.bookmark("top", "top one")
        self.bookmark("pushed", "pushed one", "main@origin")
        self.push("pushed")
        jj(self.repo, "new", "main@origin")
        self.advance()
        jj(self.repo, "git", "fetch")
        op = jj(self.repo, "op", "log", "-n1", "--no-graph", "-T", "id")

        self.assertEqual(run_jjw(self.repo, "wip-rebase", "-n").splitlines(), [
            "→ repo  base  would rebase",
            "· repo  pushed  has pushed commits; skipped",
        ])
        self.assertEqual(run_jjw(self.repo, "wip-rebase", "-n", "-a").splitlines(), [
            "→ repo  base  would rebase",
            "→ repo  pushed  would rebase",
        ])
        self.assertEqual(run_jjw(self.repo, "wip-rebase", "-n", "top").strip(), "→ repo  top  would rebase")
        self.assertEqual(jj(self.repo, "op", "log", "-n1", "--no-graph", "-T", "id"), op)

    def test_undo(self):
        self.bookmark("base", "base one", "main@origin")
        self.bookmark("top", "top one")
        jj(self.repo, "new", "main@origin")
        self.advance()
        jj(self.repo, "git", "fetch")

        out = run_jjw(self.repo, "wip-rebase").splitlines()
        self.assertEqual(out[0], "✓ repo  base  rebased")
        self.assertEqual(len(out), 2)
        self.assertTrue(self.on_trunk("top"))
        undo = out[-1].split("undo: ", 1)[1].split()
        sh(*undo, cwd=self.repo)
        self.assertFalse(self.on_trunk("base"))
        self.assertFalse(self.on_trunk("top"))


class TestWipRebaseGit(Base):
    def test_skips_git(self):
        r = mkgit_origin(self.tmp / "g", self.tmp / "g.git")
        self.assertEqual(run_jjw(r, "wip-rebase").strip(), "· g  git repo; skipped")


if __name__ == "__main__":
    unittest.main()
