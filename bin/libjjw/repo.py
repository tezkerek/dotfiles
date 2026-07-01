from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from .github import PR, gh_prs, github_slug
from .style import colorize, indent

TRUNKS = ("main", "master", "develop")

FS, RS, LS = "\x1f", "\x1e", "\x1d"


def is_trunk(name: str) -> bool:
    return not name or name in TRUNKS or name.startswith("release/")


@dataclass
class Block:
    name: str
    time: int
    labels: list[str]
    commits: str = ""
    head: bool = False

    def render(self, pr: Optional[PR]) -> str:
        title = colorize(self.name, "yellow")
        if self.head:
            title += " " + colorize("(HEAD)", "green")
        parts = [title, pr.label() if pr else "", *self.labels]
        header = indent("  ".join(p for p in parts if p), 4)
        return f"{header}\n{self.commits}" if self.commits else header


@dataclass
class Repo:
    path: Path

    @property
    def name(self) -> str:
        return self.path.name

    def color_mode(self) -> str:
        return "always" if colorize.enabled else "never"

    def st(self) -> str:
        ref, trunk = self.ref(), self.trunk()
        header = f"{colorize(self.name, 'bold', 'cyan')}  [{colorize(ref or '?', 'green' if is_trunk(ref) else 'yellow')}]"
        if is_trunk(ref) or not trunk:
            return header
        body = self.st_commits(trunk)
        return f"{header}\n{indent(body, 4)}" if body else header

    def wip(self, use_gh: bool) -> str:
        slug = github_slug(self.origin_url()) if use_gh else None
        with ThreadPoolExecutor(max_workers=1) as pool:
            prs_future = pool.submit(gh_prs, slug) if slug else None
            blocks, loose = self.wip_blocks()
            prs, gh_ok = prs_future.result() if prs_future else ({}, True)

        no_pr, opened = [], []
        for block in sorted(blocks, key=lambda b: (b.time, b.name), reverse=True):
            pr = prs.get(block.name)
            (opened if pr and pr.open else no_pr).append(block.render(pr))
        if not (no_pr or opened or loose):
            return ""

        header = colorize(self.name, "bold", "cyan")
        if not gh_ok:
            header += "  " + colorize("(gh failed)", "red")
        sections = [
            "  " + colorize(title, "bold") + "\n" + body
            for title, body in (("No PR", "\n".join(no_pr)), ("Open PRs", "\n".join(opened)), ("Without bookmark", loose))
            if body
        ]
        return header + "\n" + "\n\n".join(sections)

    def store(self) -> str: ...
    def ref(self) -> str: ...
    def trunk(self) -> str: ...
    def st_commits(self, trunk: str) -> str: ...
    def pull(self) -> tuple[str, str]: ...
    def wip_rebase(self, branch: Optional[str], every: bool, fetch: bool, dry_run: bool) -> list[tuple[str, str]]: ...
    def origin_url(self) -> Optional[str]: ...
    def wip_blocks(self) -> tuple[list[Block], str]: ...
