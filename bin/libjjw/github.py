from __future__ import annotations

import json
import re
from dataclasses import dataclass
from typing import Optional

from .proc import pmap, run
from .style import colorize

CI_FAIL = {"FAILURE", "ERROR", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE"}
CI_PENDING = {"", "PENDING", "QUEUED", "IN_PROGRESS", "EXPECTED", "WAITING", "REQUESTED"}


@dataclass
class PR:
    number: int
    state: str
    draft: bool = False
    review: str = ""
    ci: str = ""

    @property
    def open(self) -> bool:
        return self.state == "OPEN"

    def label(self) -> str:
        if not self.open:
            return colorize(f"#{self.number} {self.state.lower()}", "dim")
        parts = [colorize(f"#{self.number}", "blue")]
        if self.draft:
            parts.append(colorize("draft", "dim"))
        if self.review == "APPROVED":
            parts.append(colorize("approved", "green"))
        elif self.review == "CHANGES_REQUESTED":
            parts.append(colorize("changes requested", "red"))
        ci = {"pass": ("✓ ci", "green"), "fail": ("✗ ci", "red"), "pending": ("● ci", "yellow")}.get(self.ci)
        if ci:
            parts.append(colorize(*ci))
        return "  ".join(parts)


def ci_state(checks: Optional[list[dict]]) -> str:
    states = [(c.get("conclusion") or c.get("state") or "").upper() for c in checks or []]
    if not states:
        return ""
    if any(s in CI_FAIL for s in states):
        return "fail"
    if any(s in CI_PENDING for s in states):
        return "pending"
    return "pass"


def github_slug(url: Optional[str]) -> Optional[str]:
    m = re.search(r"github\.com[:/](.+?)(?:\.git)?/?$", url or "")
    return m.group(1) if m else None


def gh_prs(slug: str) -> tuple[dict[str, PR], bool]:
    """PRs of the user by head branch, preferring an open one; and whether gh succeeded."""
    base = ["gh", "pr", "list", "-R", slug, "--author", "@me", "--limit", "100"]
    queries = [
        ["--state", "open", "--json", "headRefName,number,isDraft,reviewDecision,statusCheckRollup"],
        ["--state", "all", "--json", "headRefName,number,state"],
    ]
    results = [None if out is None else json.loads(out) for out in pmap(lambda q: run(base + q), queries)]
    opened, every = results
    prs: dict[str, PR] = {}
    for p in opened or []:
        prs.setdefault(p["headRefName"], PR(
            p["number"], "OPEN", p["isDraft"], p.get("reviewDecision") or "", ci_state(p.get("statusCheckRollup"))))
    for p in every or []:
        if p["state"] != "OPEN":
            prs.setdefault(p["headRefName"], PR(p["number"], p["state"]))
    return prs, opened is not None and every is not None
