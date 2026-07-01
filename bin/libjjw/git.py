from __future__ import annotations

import os
from typing import Optional

from .proc import lines, ok, pmap, run
from .repo import FS, TRUNKS, Block, Repo, is_trunk
from .style import UNPUSHED, age, behind_label, colorize, indent, parent_label, push_label


class GitRepo(Repo):
    def git(self, *args: str) -> Optional[str]:
        return run(["git", "-C", str(self.path), *args])

    def git_ok(self, *args: str) -> bool:
        return ok(["git", "-C", str(self.path), *args])

    def store(self) -> str:
        return os.path.realpath((self.git("rev-parse", "--path-format=absolute", "--git-common-dir") or "").strip())

    def ref(self) -> str:
        return (self.git("branch", "--show-current") or "").strip()

    def trunk(self) -> str:
        head = (self.git("symbolic-ref", "--short", "refs/remotes/origin/HEAD") or "").strip()
        if head:
            return head[len("origin/"):] if head.startswith("origin/") else head
        upstream = (self.git("rev-parse", "--abbrev-ref", "@{upstream}") or "").strip().partition("/")[2]
        if upstream in TRUNKS:
            return upstream
        return next((t for t in TRUNKS if self.git_ok("show-ref", "--verify", "--quiet", f"refs/heads/{t}")), "")

    def st_commits(self, trunk: str) -> str:
        return self.git("log", f"--color={self.color_mode()}", "--format=%C(auto)%h%Creset %s", f"{trunk}..HEAD") or ""

    def pull(self) -> tuple[str, str]:
        ref, trunk = self.ref(), self.trunk()
        if not trunk:
            return "noop", "no trunk branch found"
        if is_trunk(ref):
            if self.git_ok("pull", "--ff-only", "-q"):
                return "changed", f"pulled {ref}"
            return "failed", "git pull --ff-only failed"
        if self.git("status", "--porcelain"):
            if self.git_ok("fetch", "-q", "origin", f"{trunk}:{trunk}"):
                return "noop", "dirty; fetched trunk only"
            return "failed", f"git fetch origin {trunk} failed"
        if self.git_ok("switch", "-q", trunk) and self.git_ok("pull", "--ff-only", "-q"):
            return "changed", f"switched to {trunk} + pulled"
        return "failed", f"switch/pull {trunk} failed"

    def wip_rebase(self, branch: Optional[str], every: bool, fetch: bool, dry_run: bool) -> list[tuple[str, str]]:
        return [("noop", "git repo; skipped")]

    def origin_url(self) -> Optional[str]:
        return (self.git("remote", "get-url", "origin") or "").strip() or None

    def base(self) -> str:
        trunk = self.trunk()
        if trunk and self.git_ok("rev-parse", "--verify", "-q", f"refs/remotes/origin/{trunk}"):
            return f"origin/{trunk}"
        return trunk

    def branches(self, *args: str) -> dict[str, list[str]]:
        out = self.git("for-each-ref", *args, f"--format=%(refname:short){FS}%(objectname){FS}%(committerdate:unix){FS}%(HEAD)",
                       "refs/heads")
        return {row.split(FS)[0]: row.split(FS)[1:] for row in lines(out)}

    def wip_blocks(self) -> tuple[list[Block], str]:
        base = self.base()
        if not base:
            return [], ""
        wip = {name: info for name, info in self.branches(f"--no-merged={base}").items() if not is_trunk(name)}

        def count(*args: str) -> int:
            return int((self.git("rev-list", "--count", *args) or "0").strip())

        def block(name: str) -> Block:
            sha, ts, head = wip[name]
            counts = self.git("rev-list", "--left-right", "--count", f"{name}...origin/{name}")
            push = push_label(*map(int, counts.split())) if counts else colorize(UNPUSHED, "cyan")
            under = [o for o, info in self.branches(f"--merged={name}").items() if o in wip and info[0] != sha]
            distance = {o: count(f"{o}..{name}") for o in under}
            parent = [min(under, key=distance.__getitem__)] if under else []
            log = self.git("log", f"--format=%h{FS}%s{FS}%ct", name, "--not", base, *under) or ""
            commits = [
                indent(f"{colorize(h, 'yellow')} {subject} {colorize(age(int(ct)), 'dim')}", 8)
                for h, subject, ct in (row.split(FS) for row in lines(log))
            ]
            return Block(
                name=name,
                time=int(ts),
                labels=[push, behind_label(count(f"{name}..{base}")), parent_label(parent)],
                commits="\n".join(commits),
                head=head == "*",
            )

        return list(pmap(block, wip, workers=8)), ""
