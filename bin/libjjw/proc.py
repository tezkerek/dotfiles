from __future__ import annotations

import os
import subprocess
import threading
from concurrent.futures import ThreadPoolExecutor
from typing import Callable, Iterable, Iterator, Optional, TypeVar

T = TypeVar("T")
R = TypeVar("R")

_SLOTS = threading.BoundedSemaphore(2 * (os.cpu_count() or 4))


def pmap(fn: Callable[[T], R], items: Iterable[T], workers: int = 16) -> Iterator[R]:
    items = list(items)
    with ThreadPoolExecutor(max_workers=max(1, min(len(items), workers))) as pool:
        yield from pool.map(fn, items)


def run(args: list[str]) -> Optional[str]:
    with _SLOTS:
        p = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    return p.stdout if p.returncode == 0 else None


def ok(args: list[str]) -> bool:
    with _SLOTS:
        return subprocess.run(args, stdout=subprocess.DEVNULL).returncode == 0


def attempt(args: list[str]) -> tuple[bool, str]:
    with _SLOTS:
        p = subprocess.run(args, capture_output=True, text=True)
    return p.returncode == 0, p.stdout + p.stderr


def lines(text: Optional[str]) -> list[str]:
    return [line for line in (text or "").splitlines() if line]


def error_line(text: str) -> str:
    rows = lines(text)
    return next((r for r in rows if r.startswith("Error:")), rows[-1] if rows else "failed")
