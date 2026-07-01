from __future__ import annotations

import os
import re
import sys
import time


class Style:
    CODES = dict(bold=1, dim=2, red=31, green=32, yellow=33, blue=34, magenta=35, cyan=36)

    def __init__(self, enabled: bool):
        self.enabled = enabled

    def __call__(self, text: str, *names: str) -> str:
        if not self.enabled or not text:
            return text
        codes = "".join(f"\x1b[{self.CODES[n]}m" for n in names)
        return f"{codes}{text}\x1b[0m"


colorize = Style(sys.stdout.isatty() and "NO_COLOR" not in os.environ)

_AGE_MARK = re.compile(r"@AGE:(\d+)@")
_AGE_UNITS = (("y", 365 * 86400), ("mo", 30 * 86400), ("w", 7 * 86400), ("d", 86400), ("h", 3600), ("m", 60))


def age(epoch: int) -> str:
    seconds = max(0, int(time.time()) - epoch)
    for unit, size in _AGE_UNITS:
        if seconds >= size:
            return f"{seconds // size}{unit}"
    return f"{seconds}s"


def fill_ages(text: str) -> str:
    return _AGE_MARK.sub(lambda m: age(int(m.group(1))), text)


def indent(text: str, n: int) -> str:
    return "\n".join(" " * n + line for line in text.splitlines())


UNPUSHED = "↑ not pushed"


def push_label(ahead: int, behind: int) -> str:
    parts = []
    if ahead:
        parts.append(colorize(f"↑{ahead}", "cyan"))
    if behind:
        parts.append(colorize(f"↓{behind}", "magenta"))
    return " ".join(parts)


def behind_label(n: int) -> str:
    return colorize(f"{n} behind trunk", "magenta") if n else ""


def parent_label(names: list[str]) -> str:
    return colorize(f"on {', '.join(names)}", "dim") if names else ""
