#!/usr/bin/env python3
import asyncio
import json
import sys
from collections.abc import AsyncIterator
from typing import Literal, TypeGuard, cast

KANATA_PORT = 7996

CombinedQueue = asyncio.Queue[tuple[Literal["layout"] | Literal["layer"], str]]


def get_at_path[T](obj: object, target_type: type[T], *keys: str) -> T | None:
    acc: object = obj

    for k in keys:
        if not isinstance(acc, dict) or k not in acc:
            return None

        acc = cast(object, acc[k])

        if acc is None:
            return None

    if isinstance(acc, target_type):
        return acc
    return None


def is_list_of[T](obj: object, target_type: type[T]) -> TypeGuard[list[T]]:
    if not isinstance(obj, list):
        return False
    return all(
        isinstance(i, target_type)
        for i in obj  # pyright: ignore[reportUnknownVariableType]
    )


def get_list_at_path[T](obj: object, item_type: type[T], *keys: str) -> list[T] | None:
    generic_list = get_at_path(obj, object, *keys)
    if is_list_of(generic_list, item_type):
        return generic_list


async def read_lines(reader: asyncio.StreamReader) -> AsyncIterator[str]:
    while True:
        line = await reader.readline()
        if not line:
            break
        text = line.decode().rstrip("\n")
        if text:
            yield text


def extract_layer_name(line: str) -> str | None:
    obj = cast(object, json.loads(line))
    return get_at_path(obj, str, "LayerChange", "new")


async def produce_kanata_layer(q: CombinedQueue) -> None:
    while True:
        try:
            r, w = await asyncio.open_connection("127.0.0.1", KANATA_PORT)
            w.write_eof()
            await w.drain()
            async for line in read_lines(r):
                if layer_name := extract_layer_name(line):
                    await q.put(("layer", layer_name))
        except Exception as e:
            print(f"[kb_layout] kanata error: {e}", file=sys.stderr)
            await asyncio.sleep(2)


def next_niri_layout(
    current_layouts: list[str], line: str
) -> tuple[list[str], str | None]:
    obj = cast(object, json.loads(line))
    layouts_obj = get_at_path(
        obj,
        object,
        "KeyboardLayoutsChanged",
        "keyboard_layouts",
    )
    next_layouts = current_layouts
    if layouts_obj:
        idx = get_at_path(layouts_obj, int, "current_idx")
        layout_names = get_list_at_path(layouts_obj, str, "names")
        if layout_names is not None:
            next_layouts = layout_names
    else:
        idx = get_at_path(obj, int, "KeyboardLayoutSwitched", "idx")

    return (next_layouts, None if idx is None else next_layouts[idx])


async def produce_niri_layout(q: CombinedQueue) -> None:
    while True:
        try:
            known_layouts: list[str] = []
            proc = await asyncio.create_subprocess_exec(
                "niri",
                "msg",
                "--json",
                "event-stream",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            assert proc.stdout is not None
            async for line in read_lines(proc.stdout):
                known_layouts, next_layout = next_niri_layout(known_layouts, line)
                if next_layout is not None:
                    await q.put(("layout", next_layout))
        except Exception as e:
            print(f"[kb_layout] niri error: {e}", file=sys.stderr)
            await asyncio.sleep(2)


def emit_next(layout: str, kanata_layer: str | None = None) -> None:
    if not layout:
        return
    if kanata_layer and kanata_layer != "default":
        result = {"text": f"{layout} 󰧾 {kanata_layer}", "class": "layer-active"}
    else:
        result = {"text": layout}
    print(json.dumps(result), flush=True)


async def consume(q: CombinedQueue) -> None:
    layout = ""
    layer = None
    while True:
        source, value = await q.get()
        match source:
            case "layer":
                layer = value
            case "layout":
                layout = value
        emit_next(layout, layer)


async def main() -> None:
    q: CombinedQueue = asyncio.Queue()
    _ = await asyncio.gather(
        produce_kanata_layer(q),
        produce_niri_layout(q),
        consume(q),
        return_exceptions=True,
    )


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
