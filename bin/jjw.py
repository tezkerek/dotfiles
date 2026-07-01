#!/usr/bin/env python3
"""VCS sweeps over the repos of a workspace.

Repos: the given dirs; else the repo that contains PWD; else every child repo of
PWD. Workspaces of the same repo are used once.

commands:
  st    show the ref of each repo, and its commits when on a feature (default)
  pull  fetch each repo, and move it to trunk when that is safe
  wip   show local work in progress per repo, with GitHub PR state
  wip-rebase  rebase unpushed bookmarks on trunk, then update stale workspaces
"""

from __future__ import annotations

import argparse
import sys
from typing import Callable, Optional

from libjjw.proc import pmap
from libjjw.repo import Repo
from libjjw.style import colorize
from libjjw.workspace import discover


GLYPHS = {"changed": ("✓", "green"), "failed": ("✗", "red"), "plan": ("→", "cyan"), "undo": ("↶", "magenta")}


def report(repo: Repo, status: str, message: str) -> None:
    glyph, color = GLYPHS.get(status, ("·", "dim"))
    print(f"{colorize(glyph, color)} {colorize(repo.name, 'bold', 'cyan')}  {message}", flush=True)


def cmd_st(repos: list[Repo], args: argparse.Namespace) -> None:
    for out in pmap(lambda r: r.st(), repos):
        print(out, flush=True)


def cmd_pull(repos: list[Repo], args: argparse.Namespace) -> None:
    for repo, (status, message) in zip(repos, pmap(lambda r: r.pull(), repos)):
        report(repo, status, message)


def cmd_wip(repos: list[Repo], args: argparse.Namespace) -> None:
    outputs = [out for out in pmap(lambda r: r.wip(not args.no_gh), repos) if out]
    print("\n\n".join(outputs) if outputs else colorize("nothing in progress", "dim"))


def cmd_wip_rebase(repos: list[Repo], args: argparse.Namespace) -> None:
    printed = False
    for repo, results in zip(repos, pmap(lambda r: r.wip_rebase(args.branch, args.all, args.fetch, args.dry_run), repos)):
        for status, message in results:
            printed = True
            report(repo, status, message)
    if not printed:
        print(colorize(f"no bookmark {args.branch}" if args.branch else "nothing to rebase", "dim"))


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(prog="jjw", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.set_defaults(fn=cmd_st, dirs=[])
    sub = parser.add_subparsers(metavar="{st,pull,wip,wip-rebase}")

    def command(name: str, fn: Callable[[list[Repo], argparse.Namespace], None]) -> argparse.ArgumentParser:
        p = sub.add_parser(name)
        p.set_defaults(fn=fn)
        return p

    command("st", cmd_st).add_argument("dirs", nargs="*")
    command("pull", cmd_pull).add_argument("dirs", nargs="*")

    wip = command("wip", cmd_wip)
    wip.add_argument("dirs", nargs="*")
    wip.add_argument("--no-gh", action="store_true", help="skip GitHub PR data")

    rebase = command("wip-rebase", cmd_wip_rebase)
    rebase.add_argument("branch", nargs="?", help="rebase only this bookmark, also when pushed")
    rebase.add_argument("-a", "--all", action="store_true", help="also rebase pushed bookmarks")
    rebase.add_argument("-f", "--fetch", action="store_true", help="fetch trunk first")
    rebase.add_argument("-n", "--dry-run", action="store_true", help="show what would be rebased")

    args = parser.parse_args(argv)

    repos = discover(args.dirs)
    if not repos:
        print("jjw: no repos found", file=sys.stderr)
        return 1
    args.fn(repos, args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
