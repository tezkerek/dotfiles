from __future__ import annotations

import os
import re
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Iterable, Optional

from .proc import attempt, error_line, lines, ok, pmap, run
from .repo import FS, LS, RS, TRUNKS, Block, Repo, is_trunk
from .style import UNPUSHED, behind_label, colorize, fill_ages, indent, parent_label, push_label

UP_TO_DATE = "up to date"

_ANSI = re.compile(r"\x1b\[[0-9;]*m")
_CONNECTOR = re.compile(r"^[│|~ ]+$")

_JJ_EMPTY = '(empty() & description(exact:""))'
_JJ_MARKS = "(bookmarks() & mine() & mutable())"
_JJ_AGE = 'label("timestamp", "@AGE:" ++ stringify(committer.timestamp().format("%s")) ++ "@")'
_JJ_LINE = f'''separate(" ",
    change_id.shortest(8),
    if(description, description.first_line(), label("description placeholder", "(no description)")),
    if(empty, label("empty", "(empty)")),
    if(conflict, label("conflict", "(conflict)")),
    working_copies,
    {_JJ_AGE}
)'''


def jj_quote(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


@dataclass
class JjCommit:
    id: str
    parents: list[str]
    bookmarks: list[str]
    empty: bool
    time: int
    line: str


@dataclass
class JjGraph:
    commits: dict[str, JjCommit]
    children: dict[str, list[str]] = field(default_factory=dict)

    def __post_init__(self):
        for c in self.commits.values():
            for p in c.parents:
                if p in self.commits:
                    self.children.setdefault(p, []).append(c.id)

    def _walk(self, start: Iterable[str], step: Callable[[str], list[str]]) -> set[str]:
        seen: set[str] = set()
        todo = [i for i in start if i in self.commits]
        while todo:
            i = todo.pop()
            if i not in seen:
                seen.add(i)
                todo.extend(j for j in step(i) if j in self.commits)
        return seen

    def ancestors(self, ids: Iterable[str]) -> set[str]:
        return self._walk(ids, lambda i: self.commits[i].parents)

    def descendants(self, ids: Iterable[str]) -> set[str]:
        return self._walk(ids, lambda i: self.children.get(i, []))

    def ordered(self, ids: set[str]) -> list[JjCommit]:
        return [c for i, c in self.commits.items() if i in ids]


class JjRepo(Repo):
    def jj(self, *args: str, color: bool = False) -> Optional[str]:
        mode = self.color_mode() if color else "never"
        return run(["jj", "-R", str(self.path), "--ignore-working-copy", f"--color={mode}", *args])

    def jj_ok(self, *args: str) -> bool:
        return ok(["jj", "-R", str(self.path), "--quiet", *args])

    def jj_try(self, *args: str) -> tuple[bool, str]:
        return attempt(["jj", "-R", str(self.path), "--color=never", *args])

    def log(self, revset: str, template: str, color: bool = False) -> str:
        return self.jj("log", "--no-graph", "-r", revset, "-T", template, color=color) or ""

    def count(self, revset: str) -> int:
        return len(self.log(revset, '"x"'))

    def exists(self, revset: str) -> bool:
        return self.count(revset) > 0

    def store(self) -> str:
        p = self.path / ".jj" / "repo"
        if p.is_file():
            target = Path(p.read_text().strip())
            p = target if target.is_absolute() else self.path / ".jj" / target
        return os.path.realpath(p)

    def ref(self) -> str:
        out = self.log("latest(::@ & bookmarks())", 'stringify(local_bookmarks.map(|b| b.name()).join("\n"))')
        return next(iter(lines(out)), "")

    def trunk(self) -> str:
        out = self.jj("bookmark", "list", "--all-remotes", "-T", 'if(remote == "origin", name ++ "\n")')
        remote = set(lines(out))
        return next((t for t in TRUNKS if t in remote), "")

    def has_bookmark(self, name: str) -> bool:
        return self.exists(f"present(bookmarks(exact:{jj_quote(name)}))")

    def st_commits(self, trunk: str) -> str:
        return self.jj("log", "-r", "trunk()..@ | trunk()", color=True) or ""

    def pull(self) -> tuple[str, str]:
        ref, trunk = self.ref(), self.trunk()
        if not self.jj_ok("git", "fetch"):
            return "failed", "jj git fetch failed"
        if not trunk:
            return "noop", "no trunk on origin; fetched only"
        if not is_trunk(ref) and self.has_bookmark(ref):
            return "noop", f"fetched; left on {ref}"
        if self.jj_ok("new", f"{trunk}@origin"):
            return "changed", f"new {trunk}@origin"
        return "failed", f"jj new {trunk}@origin failed"

    def wip_rebase(self, branch: Optional[str], every: bool, fetch: bool, dry_run: bool) -> list[tuple[str, str]]:
        trunk = self.trunk()
        if not trunk:
            return [("noop", "no trunk on origin")]
        if fetch:
            done, out = self.jj_try("git", "fetch", "-b", trunk)
            if not done:
                return [("failed", colorize(error_line(out), "red"))]
        if branch:
            if not self.has_bookmark(branch):
                return []
            names = [branch]
        else:
            out = self.jj("bookmark", "list", "-r", "mine() & mutable()", "-T", 'if(!remote, name ++ "\n")')
            names = [n for n in dict.fromkeys(lines(out)) if not is_trunk(n)]
        force, verbose = every or bool(branch), bool(branch)
        if dry_run:
            planned: list[str] = []
            return [r for r in (self.plan_bookmark(n, force, verbose, planned) for n in names) if r]
        roots = self.workspace_roots()
        for root in roots.values():
            ok(["jj", "-R", root, "--quiet", "util", "snapshot"])
        op = self.op_id()
        results = [r for r in (self.rebase_bookmark(n, force, verbose) for n in names) if r]
        if self.op_id() != op:
            results += self.update_stale(roots)
            results.append(("undo", f"{colorize('undo:', 'dim')} {colorize(self.restore_command(op), 'bold')}"))
        return results

    def op_id(self) -> str:
        return (self.jj("op", "log", "-n1", "--no-graph", "-T", "id.short()") or "").strip()

    def restore_command(self, op: str) -> str:
        rel = os.path.relpath(self.path)
        repo = "" if rel == "." else f"-R {rel} "
        return f"jj {repo}op restore {op}"

    def workspace_roots(self) -> dict[str, str]:
        names = lines(self.jj("workspace", "list", "-T", 'name ++ "\n"'))
        roots = {ws: (self.jj("workspace", "root", "--name", ws) or "").strip() for ws in names}
        return {ws: root for ws, root in roots.items() if root}

    def skip_reason(self, ref: str, force: bool) -> str:
        if not self.exists(f"{ref}..trunk()"):
            return UP_TO_DATE
        if not force and self.exists(f'roots(trunk()..{ref}):: & ::remote_bookmarks(remote=exact:"origin")'):
            return "has pushed commits; skipped"
        return ""

    @staticmethod
    def skipped(name: str, reason: str, verbose: bool) -> Optional[tuple[str, str]]:
        if reason == UP_TO_DATE and not verbose:
            return None
        return "noop", f"{colorize(name, 'yellow')}  {colorize(reason, 'dim')}"

    def plan_bookmark(self, name: str, force: bool, verbose: bool, planned: list[str]) -> Optional[tuple[str, str]]:
        ref = f"bookmarks(exact:{jj_quote(name)})"
        moved = " | ".join(f"roots(trunk()..{r})::" for r in planned)
        reason = UP_TO_DATE if moved and self.exists(f"{ref} & ({moved})") else self.skip_reason(ref, force)
        if reason:
            return self.skipped(name, reason, verbose)
        planned.append(ref)
        return "plan", f"{colorize(name, 'yellow')}  would rebase"

    def rebase_bookmark(self, name: str, force: bool, verbose: bool) -> Optional[tuple[str, str]]:
        ref = f"bookmarks(exact:{jj_quote(name)})"
        reason = self.skip_reason(ref, force)
        if reason:
            return self.skipped(name, reason, verbose)
        done, out = self.jj_try("rebase", "-b", ref, "-d", "trunk()")
        if not done:
            return "failed", f"{colorize(name, 'yellow')}  {colorize(error_line(out), 'red')}"
        if self.exists(f"conflicts() & (trunk()..{ref})"):
            return "failed", f"{colorize(name, 'yellow')}  {colorize('rebased with conflicts', 'red')}"
        return "changed", f"{colorize(name, 'yellow')}  rebased"

    def update_stale(self, roots: dict[str, str]) -> list[tuple[str, str]]:
        results = []
        for ws, root in roots.items():
            done, out = attempt(["jj", "-R", root, "--color=never", "workspace", "update-stale"])
            if not done:
                results.append(("failed", f"workspace {colorize(ws, 'green')}  {colorize(error_line(out), 'red')}"))
            elif "Updated working copy" in out:
                results.append(("changed", f"workspace {colorize(ws, 'green')}  updated stale working copy"))
        return results

    def origin_url(self) -> Optional[str]:
        out = self.jj("git", "remote", "list")
        return next((parts[1] for parts in map(str.split, lines(out)) if parts[0] == "origin"), None)

    def bookmark_labels(self) -> dict[str, str]:
        template = (
            'name ++ "\t" ++ if(remote, remote, ".") ++ "\t" ++ if(conflict, "1", "0") ++ "\t"'
            ' ++ if(present, "1", "0") ++ "\t"'
            ' ++ if(tracked, tracking_ahead_count.exact() ++ "\t" ++ tracking_behind_count.exact(), "0\t0") ++ "\n"'
        )
        out = self.jj("bookmark", "list", "-a", "-r", "mine() & mutable()", "-T", template)
        local: dict[str, bool] = {}
        origin: dict[str, Optional[tuple[int, int]]] = {}
        for row in lines(out):
            name, remote, conflict, present, local_behind, local_ahead = row.split("\t")
            if remote == ".":
                local[name] = conflict == "1"
            elif remote == "origin":
                origin[name] = (int(local_ahead), int(local_behind)) if present == "1" else None

        labels = {}
        for name, conflict in local.items():
            if conflict:
                labels[name] = colorize("✗ conflict", "red")
            elif name not in origin:
                labels[name] = colorize(UNPUSHED, "cyan")
            elif origin[name] is None:
                labels[name] = colorize(f"{UNPUSHED} (tracked)", "cyan")
            else:
                labels[name] = push_label(*origin[name])
        return labels

    def graph(self, revset: str) -> JjGraph:
        template = (
            f'stringify(commit_id) ++ "{FS}"'
            f' ++ stringify(parents.map(|c| c.commit_id()).join("{LS}")) ++ "{FS}"'
            f' ++ stringify(local_bookmarks.map(|b| b.name()).join("{LS}")) ++ "{FS}"'
            f' ++ if(empty && description == "", "1", "0") ++ "{FS}"'
            f' ++ stringify(committer.timestamp().format("%s")) ++ "{FS}"'
            f' ++ {_JJ_LINE} ++ "{RS}"'
        )
        commits = {}
        for record in self.log(revset, template, color=True).split(RS):
            if not record.strip():
                continue
            cid, parents, bookmarks, empty, ts, line = record.split(FS)
            commits[cid] = JjCommit(cid, parents.split(LS), [b for b in bookmarks.split(LS) if b],
                                    empty == "1", int(ts), fill_ages(line))
        return JjGraph(commits)

    def wip_blocks(self) -> tuple[list[Block], str]:
        with ThreadPoolExecutor(max_workers=1) as pool:
            loose = pool.submit(self.loose)
            labels = self.bookmark_labels()
            blocks = self.bookmark_blocks(labels) if labels else []
            return blocks, loose.result()

    def bookmark_blocks(self, labels: dict[str, str]) -> list[Block]:
        g = self.graph(f"(::{_JJ_MARKS} & mutable()) | {_JJ_MARKS}::")
        targets = {name: {c.id for c in g.commits.values() if name in c.bookmarks} for name in labels}
        marks = set().union(*targets.values())
        under_marks = g.ancestors(marks)

        def block(name: str) -> Block:
            own = targets[name]
            below = (g.ancestors(own) & marks) - own
            below_heads = below - g.ancestors(p for i in below for p in g.commits[i].parents)
            children = {c for i in own for c in g.children.get(i, [])}
            above_all = g.descendants(children)
            above = above_all - under_marks - g.descendants(above_all & marks)
            above = {i for i in above if not g.commits[i].empty}
            stack = g.ancestors(own) - g.ancestors(below)
            behind = self.count(f"bookmarks(exact:{jj_quote(name)})..trunk()")
            parent = [b for c in g.ordered(below_heads) for b in c.bookmarks]
            commits = [indent(f"{colorize('+', 'dim')} {c.line}", 6) for c in g.ordered(above)]
            commits += [indent(c.line, 8) for c in g.ordered(stack)]
            return Block(
                name=name,
                time=max((g.commits[i].time for i in above | own), default=0),
                labels=[labels[name], behind_label(behind), parent_label(parent)],
                commits="\n".join(commits),
            )

        return list(pmap(block, labels, workers=8))

    def loose(self) -> str:
        x = f"((mine() & mutable()) ~ ::{_JJ_MARKS} ~ {_JJ_MARKS}:: ~ {_JJ_EMPTY})"
        forks = lines(self.log(f"roots({x})-", 'stringify(commit_id) ++ "\n"'))
        from_template = (
            '"from " ++ separate(" ", commit_id.shortest(8), bookmarks,'
            f' if(!immutable, description.first_line()), {_JJ_AGE}) ++ "\n"'
        )

        def group(fork: str) -> str:
            head = self.log(fork, from_template, color=True)
            graph = self.jj("log", "-r", f"(roots({x}) & {fork}+):: & {x}", "-T", _JJ_LINE + ' ++ "\n"', color=True) or ""
            graph = "\n".join(line for line in graph.splitlines() if not _CONNECTOR.match(_ANSI.sub("", line)))
            return indent(fill_ages(head), 4) + "\n" + indent(fill_ages(graph), 6)

        return "\n".join(pmap(group, forks, workers=8))
