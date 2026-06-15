#!/usr/bin/env python3
from evdev import InputDevice
import asyncio
import json
import time
import sys
from collections.abc import AsyncIterator
from typing import Literal, TypeGuard, cast

import evdev
from evdev import InputEvent, ecodes

KANATA_PORT = 7996
KBD_DEVICE_NAME = "kanata"
DEBOUNCE_SEC = 0.1

MODIFIER_KEYS: dict[int, str] = {
    ecodes.KEY_LEFTCTRL: "ctrl",
    ecodes.KEY_RIGHTCTRL: "ctrl",
    ecodes.KEY_LEFTSHIFT: "shift",
    ecodes.KEY_RIGHTSHIFT: "shift",
    ecodes.KEY_LEFTALT: "alt",
    ecodes.KEY_RIGHTALT: "alt",
    ecodes.KEY_LEFTMETA: "super",
    ecodes.KEY_RIGHTMETA: "super",
}

CombinedQueue = asyncio.Queue[
    tuple[Literal["layout"] | Literal["layer"] | Literal["modifiers"], str]
]


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
    return all(isinstance(i, target_type) for i in obj)


def get_list_at_path[T](obj: object, item_type: type[T], *keys: str) -> list[T] | None:
    generic_list = get_at_path(obj, object, *keys)
    if is_list_of(generic_list, item_type):
        return generic_list
    return None


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


def get_modifier(event: InputEvent) -> str | None:
    return MODIFIER_KEYS.get(event.code) if event.type == ecodes.EV_KEY else None


def find_kbd_device() -> str | None:
    for path in evdev.list_devices():
        try:
            device = evdev.InputDevice(path)
            is_target = KBD_DEVICE_NAME in device.name.lower()
            device.close()
            if is_target:
                return path
        except OSError:
            continue
    return None


async def _emit_modifiers_loop(device: InputDevice[str], q: CombinedQueue) -> None:
    held: set[str] = set()
    mods_str = ""
    last_event_time = 0.0
    emit_task: asyncio.Task[None] | None = None

    async def debounced_emit() -> None:
        while True:
            now = time.monotonic()
            time_left = (last_event_time + DEBOUNCE_SEC) - now
            if time_left > 0:
                await asyncio.sleep(time_left)
                continue
            await q.put(("modifiers", mods_str))
            break

    event: InputEvent
    async for event in device.async_read_loop():
        if not (mod := get_modifier(event)):
            continue
        if event.value:
            held.add(mod)
        else:
            held.discard(mod)
        new_mods_str = " ".join(sorted(held))
        if new_mods_str == mods_str:
            continue
        mods_str = new_mods_str
        last_event_time = time.monotonic()
        if emit_task is None or emit_task.done():
            emit_task = asyncio.create_task(debounced_emit())


async def produce_modifiers(q: CombinedQueue) -> None:
    while True:
        try:
            device_path = find_kbd_device()
            if not device_path:
                await asyncio.sleep(2)
                return

            device = evdev.InputDevice(device_path)
            await _emit_modifiers_loop(device, q)
        except Exception as e:
            print(f"[kb_layout] evdev error: {e}", file=sys.stderr)
            await asyncio.sleep(2)


def emit_next(
    layout: str, kanata_layer: str | None = None, modifiers: str = ""
) -> None:
    if not layout:
        return

    classes: list[str] = []
    layer_str = ""
    if kanata_layer and kanata_layer != "default":
        layer_str = f" 󰧾 {kanata_layer}"
        classes.append("layer-active")
    mod_str = ""
    if modifiers:
        mod_str = f" 󰘴 {modifiers}"
        classes.append("modifiers-active")

    result: dict[str, str | list[str]] = {"text": f"{layout}{layer_str}{mod_str}"}
    if classes:
        result["class"] = classes
    print(json.dumps(result), flush=True)


async def consume(q: CombinedQueue) -> None:
    layout = ""
    layer: str | None = None
    modifiers = ""
    while True:
        source, value = await q.get()
        match source:
            case "layer":
                layer = value
            case "layout":
                layout = value
            case "modifiers":
                modifiers = value
        emit_next(layout, layer, modifiers)


async def main() -> None:
    q: CombinedQueue = asyncio.Queue()
    _ = await asyncio.gather(
        produce_kanata_layer(q),
        produce_niri_layout(q),
        produce_modifiers(q),
        consume(q),
        return_exceptions=True,
    )


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
