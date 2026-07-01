from __future__ import annotations

import os
from pathlib import Path
from typing import Optional

from .git import GitRepo
from .jj import JjRepo
from .proc import pmap, run
from .repo import Repo


def repo_at(path: Path) -> Optional[Repo]:
    path = Path(os.path.abspath(path))
    if (path / ".jj").is_dir():
        return JjRepo(path)
    if (path / ".git").exists():
        return GitRepo(path)
    return None


def current_root() -> Optional[Path]:
    for args in (["jj", "root", "--ignore-working-copy"], ["git", "rev-parse", "--show-toplevel"]):
        out = run(args)
        if out and out.strip():
            return Path(out.strip())
    return None


def discover(dirs: list[str]) -> list[Repo]:
    if dirs:
        candidates = [Path(d) for d in dirs]
    else:
        root = current_root()
        cwd = Path.cwd()
        candidates = [root] if root else sorted(
            (p for p in cwd.iterdir() if p.is_dir() and not p.name.startswith(".")), key=lambda p: p.name.lower())
    repos = [r for r in map(repo_at, candidates) if r]
    stores = list(pmap(lambda r: r.store(), repos))
    seen: set[str] = set()
    unique = []
    for repo, store in zip(repos, stores):
        if store not in seen:
            seen.add(store)
            unique.append(repo)
    return unique
