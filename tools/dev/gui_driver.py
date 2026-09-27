#!/usr/bin/env python3
"""Minimal X11 GUI driver for the ChatGPT-in-Firefox consultation workflow.

Rules honoured (user feedback memory): re-activate the target window through
EWMH before EVERY input batch, so no stray input ever lands elsewhere.

Usage:
  gui.py click  <winid> <x> <y> [button]     window-relative coords
  gui.py dclick <winid> <x> <y>
  gui.py paste  <winid> <x> <y> <textfile>   click there, then paste file text
  gui.py key    <winid> <combo>              e.g. Return, ctrl+a, ctrl+v, Escape
  gui.py scroll <winid> <x> <y> <up|down> <n>
  gui.py shot   <winid> <out.png>
"""

import subprocess
import sys
import time

from Xlib import X, XK, display
from Xlib.ext import xtest


def _display():
    return display.Display()


def _activate(winid: str) -> None:
    subprocess.run(["wmctrl", "-i", "-a", winid], check=True)
    time.sleep(0.6)


def _win_origin(d, winid: str):
    win = d.create_resource_object("window", int(winid, 16))
    geo = win.get_geometry()
    origin = win.translate_coords(d.screen().root, 0, 0)
    # translate_coords gives the window's coords in root space inverted;
    # use the absolute position of (0,0) of the window instead:
    abs_pos = d.screen().root.translate_coords(win, 0, 0)
    return -abs_pos.x, -abs_pos.y if False else (0, 0)  # unused fallback


def _abs_coords(d, winid: str, x: int, y: int):
    win = d.create_resource_object("window", int(winid, 16))
    pos = win.translate_coords(d.screen().root, 0, 0)
    # pos gives root coords translated into window space; invert.
    return -pos.x + x if False else _abs_via_query(d, win, x, y)


def _abs_via_query(d, win, x, y):
    # Walk up to the root, summing offsets.
    node = win
    ox, oy = 0, 0
    while True:
        geo = node.get_geometry()
        ox += geo.x
        oy += geo.y
        parent = node.query_tree().parent
        if parent == d.screen().root or parent == 0:
            break
        node = parent
    return ox + x, oy + y


def _move_pointer(d, x: int, y: int) -> None:
    d.screen().root.warp_pointer(x, y)
    d.sync()
    time.sleep(0.15)


def _button(d, button: int, presses: int = 1) -> None:
    for _ in range(presses):
        xtest.fake_input(d, X.ButtonPress, button)
        d.sync()
        time.sleep(0.06)
        xtest.fake_input(d, X.ButtonRelease, button)
        d.sync()
        time.sleep(0.09)


def _keysym_code(d, name: str) -> int:
    sym = XK.string_to_keysym(name)
    if sym == 0:
        raise SystemExit(f"unknown keysym {name}")
    return d.keysym_to_keycode(sym)


def _key_combo(d, combo: str) -> None:
    parts = combo.split("+")
    mods = parts[:-1]
    key = parts[-1]
    mod_map = {"ctrl": "Control_L", "shift": "Shift_L", "alt": "Alt_L", "super": "Super_L"}
    codes = [_keysym_code(d, mod_map.get(m.lower(), m)) for m in mods]
    key_code = _keysym_code(d, key)
    for code in codes:
        xtest.fake_input(d, X.KeyPress, code)
    d.sync()
    time.sleep(0.05)
    xtest.fake_input(d, X.KeyPress, key_code)
    d.sync()
    time.sleep(0.05)
    xtest.fake_input(d, X.KeyRelease, key_code)
    for code in reversed(codes):
        xtest.fake_input(d, X.KeyRelease, code)
    d.sync()
    time.sleep(0.15)


def _set_clipboard(text: str) -> None:
    import gi
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gtk, Gdk
    clip = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
    clip.set_text(text, -1)
    clip.store()
    # Pump the loop briefly so the selection ownership registers.
    while Gtk.events_pending():
        Gtk.main_iteration_do(False)


def main() -> None:
    cmd = sys.argv[1]
    winid = sys.argv[2]
    d = _display()
    _activate(winid)
    if cmd == "click" or cmd == "dclick":
        x, y = int(sys.argv[3]), int(sys.argv[4])
        button = int(sys.argv[5]) if cmd == "click" and len(sys.argv) > 5 else 1
        ax, ay = _abs_via_query(d, d.create_resource_object("window", int(winid, 16)), x, y)
        _move_pointer(d, ax, ay)
        _button(d, button, 2 if cmd == "dclick" else 1)
    elif cmd == "paste":
        x, y = int(sys.argv[3]), int(sys.argv[4])
        text = open(sys.argv[5]).read()
        ax, ay = _abs_via_query(d, d.create_resource_object("window", int(winid, 16)), x, y)
        _move_pointer(d, ax, ay)
        _button(d, 1)
        time.sleep(0.3)
        _set_clipboard(text)
        time.sleep(0.3)
        _key_combo(d, "ctrl+v")
        time.sleep(0.8)  # keep the clipboard owner alive for the transfer
    elif cmd == "key":
        _key_combo(d, sys.argv[3])
    elif cmd == "scroll":
        x, y = int(sys.argv[3]), int(sys.argv[4])
        direction = 4 if sys.argv[5] == "up" else 5
        count = int(sys.argv[6]) if len(sys.argv) > 6 else 3
        ax, ay = _abs_via_query(d, d.create_resource_object("window", int(winid, 16)), x, y)
        _move_pointer(d, ax, ay)
        _button(d, direction, count)
    elif cmd == "shot":
        time.sleep(0.4)
        subprocess.run(["import", "-window", winid, sys.argv[3]], check=True)
    else:
        raise SystemExit("unknown command")
    d.sync()


if __name__ == "__main__":
    main()
