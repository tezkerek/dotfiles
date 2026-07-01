"""Throwaway git and jj repos for jjw tests and the demo."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
JJW_PATH = ROOT / "bin" / "jjw.py"
sys.path.insert(0, str(ROOT / "bin"))

ENV = {
    "GIT_AUTHOR_NAME": "test",
    "GIT_AUTHOR_EMAIL": "test@example.com",
    "GIT_COMMITTER_NAME": "test",
    "GIT_COMMITTER_EMAIL": "test@example.com",
    "GIT_CONFIG_GLOBAL": os.devnull,
    "GIT_CONFIG_NOSYSTEM": "1",
    "JJ_USER": "test",
    "JJ_EMAIL": "test@example.com",
}


def use_test_env(tmp: Path) -> None:
    config = tmp / "jj-config.toml"
    config.write_text("")
    os.environ.update(ENV, JJ_CONFIG=str(config))


def sh(*args: str, cwd: Path | None = None, env: dict | None = None) -> str:
    return subprocess.run(
        args, cwd=cwd, check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        env={**os.environ, **(env or {})},
    ).stdout


def git(repo: Path, *args: str, env: dict | None = None) -> str:
    return sh("git", "-C", str(repo), *args, env=env)


def jj(repo: Path, *args: str) -> str:
    return sh("jj", "-R", str(repo), *args)


def commit(repo: Path, message: str, date: str | None = None) -> None:
    (repo / message.replace(" ", "-")).write_text(message)
    git(repo, "add", "-A")
    git(repo, "commit", "-qm", message, env={"GIT_COMMITTER_DATE": date} if date else None)


def mkgit(repo: Path, branch: str = "main") -> Path:
    repo.mkdir(parents=True)
    git(repo, "init", "-q", "-b", branch)
    commit(repo, "initial")
    return repo


def mkgit_origin(repo: Path, origin: Path) -> Path:
    sh("git", "init", "-q", "--bare", "-b", "main", str(origin))
    mkgit(repo)
    git(repo, "remote", "add", "origin", str(origin))
    git(repo, "push", "-q", "-u", "origin", "main")
    return repo


def advance_origin(origin: Path, scratch: Path, message: str) -> None:
    sh("git", "clone", "-q", str(origin), str(scratch))
    commit(scratch, message)
    git(scratch, "push", "-q", "origin", "main")


def mkjj_clone(origin: Path, repo: Path) -> Path:
    sh("jj", "git", "clone", str(origin), str(repo))
    return repo


def jj_commit(repo: Path, message: str, *new_args: str) -> None:
    jj(repo, "new", *new_args, "-m", message)
    (repo / message.replace(" ", "-")).write_text(message)
