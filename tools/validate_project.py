#!/usr/bin/env python3
#
"""Validate the repository before spending build time.

Checks: required files for the current phase, icon.png, JSON data files, export presets,
project.godot references, accidental signing keys, and the asset license ledger.
Prints every problem it finds and exits with status 1 if there is any error.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import generate_icons  # noqa: E402  (shares the strict icon.png validation)

CURRENT_PHASE = 1

PHASE_FILES = {
    1: [
        "README.md",
        "project.godot",
        "export_presets.cfg",
        ".gitignore",
        ".github/workflows/build-android.yml",
        "icon.png",
        "assets/generated/.gitkeep",
        "tools/setup_godot.sh",
        "tools/setup_android.sh",
        "tools/make_debug_keystore.sh",
        "tools/generate_icons.py",
        "tools/generate_placeholders.py",
        "tools/validate_project.py",
        "tools/run_tests.sh",
        "docs/BUILD.md",
        "docs/ASSETS.md",
        "docs/TESTING.md",
        "docs/SIGNING.md",
        "data/weapons.json",
        "game/main.tscn",
        "game/main.gd",
        "game/autoload/config.gd",
        "game/autoload/settings.gd",
        "game/autoload/audio.gd",
        "game/autoload/session.gd",
        "game/autoload/net.gd",
        "game/ui/theme_factory.gd",
        "game/ui/widgets.gd",
        "game/ui/screen_manager.gd",
        "game/ui/loading_screen.gd",
        "game/ui/main_menu.gd",
        "game/ui/avatar_screen.gd",
        "game/ui/settings_panel.gd",
        "game/ui/popups.gd",
        "tests/test_runner.gd",
    ],
}

EXPECTED_PRESETS = ["Android arm64", "Android arm32", "Android universal"]
APPROVED_LICENSES = ("CC0", "CC-BY", "CC BY", "MIT", "Apache", "OFL", "Public Domain", "Own work")
FORBIDDEN_LICENSE_TOKENS = ("-NC", "-ND", "NONCOMMERCIAL", "NODERIVATIVES", "NON-COMMERCIAL")
SKIP_DIRS = {".git", ".godot", "build", "__pycache__"}

errors: list = []
warnings: list = []


def err(message: str) -> None:
    errors.append(message)


def warn(message: str) -> None:
    warnings.append(message)


def read_text(rel: str) -> str:
    path = ROOT / rel
    return path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""


def check_required_files() -> None:
    for rel in PHASE_FILES.get(CURRENT_PHASE, []):
        path = ROOT / rel
        if not path.is_file():
            err(f"missing file: {rel}")
        elif path.stat().st_size == 0 and not rel.endswith(".gitkeep"):
            err(f"file exists but is empty (paste its contents): {rel}")


def check_icon() -> None:
    try:
        generate_icons.load_icon(ROOT)
    except generate_icons.IconError as exc:
        err(str(exc))


def check_json() -> None:
    for path in sorted((ROOT / "data").glob("*.json")):
        rel = path.relative_to(ROOT).as_posix()
        if path.stat().st_size == 0:
            warn(f"{rel} is empty (fine until the phase that fills it)")
            continue
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except ValueError as exc:
            err(f"{rel} is not valid JSON: {exc}")


def check_export_presets() -> None:
    text = read_text("export_presets.cfg")
    if not text:
        return
    for name in EXPECTED_PRESETS:
        if f'name="{name}"' not in text:
            err(f'export_presets.cfg is missing the preset "{name}"')
    ids = re.findall(r'package/unique_name="([^"]*)"', text)
    if not ids:
        err("export_presets.cfg has no package/unique_name")
    for pkg in ids:
        if not re.fullmatch(r"[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+", pkg):
            err(f'invalid Android package name: "{pkg}"')
    if len(set(ids)) > 1:
        err("presets use different package names; they must all match")
    for key in ("keystore/release_password", "keystore/debug_password"):
        if re.search(rf'{re.escape(key)}="[^"]+"', text):
            err(f"{key} is filled in export_presets.cfg; secrets must never be committed")


def check_project_godot() -> None:
    text = read_text("project.godot")
    if not text:
        return
    main_scene = re.search(r'run/main_scene="(res://[^"]+)"', text)
    if main_scene and not (ROOT / main_scene.group(1)[6:]).is_file():
        err(f"main scene does not exist: {main_scene.group(1)}")
    section = ""
    for line in text.splitlines():
        header = re.match(r"\[(.+)\]\s*$", line)
        if header:
            section = header.group(1)
            continue
        if section == "autoload":
            entry = re.match(r'(\w+)="\*?(res://[^"]+)"', line)
            if entry and not (ROOT / entry.group(2)[6:]).is_file():
                err(f"autoload {entry.group(1)} points to a missing file: {entry.group(2)}")


def check_no_keystores() -> None:
    for path in ROOT.rglob("*"):
        if any(part in SKIP_DIRS for part in path.relative_to(ROOT).parts):
            continue
        if path.is_file() and path.suffix.lower() in (".keystore", ".jks"):
            err(f"signing key found in the repository (remove it): {path.relative_to(ROOT).as_posix()}")


def pack_of(parts: tuple):
    """Return the pack folder name for a path below assets/, or None if it has none."""
    if len(parts) >= 2 and parts[1] in ("models", "audio"):
        return parts[3] if len(parts) >= 5 else None
    return parts[2] if len(parts) >= 4 else None


def check_assets() -> None:
    assets = ROOT / "assets"
    if not assets.is_dir():
        return
    ledger = read_text("docs/ASSETS.md").splitlines()
    rows = [line for line in ledger if line.strip().startswith("|")]
    packs = set()
    total = 0
    for path in assets.rglob("*"):
        if not path.is_file() or path.name.startswith(".") or path.suffix == ".import":
            continue
        rel_parts = path.relative_to(ROOT).parts
        if len(rel_parts) > 1 and rel_parts[1] == "generated":
            continue
        total += path.stat().st_size
        if path.stat().st_size > 10 * 1024 * 1024:
            warn(f"large asset ({path.stat().st_size // (1024 * 1024)} MB): {path.relative_to(ROOT).as_posix()}")
        pack = pack_of(rel_parts)
        if pack is None:
            err(f"asset is not inside a named pack folder: {path.relative_to(ROOT).as_posix()}")
        else:
            packs.add(pack)
    for pack in sorted(packs):
        matching = [row for row in rows if pack in row]
        if not matching:
            err(f'asset pack "{pack}" is not listed in docs/ASSETS.md')
            continue
        row = matching[0]
        upper = row.upper()
        if any(token in upper for token in FORBIDDEN_LICENSE_TOKENS):
            err(f'asset pack "{pack}" has a non-commercial or no-derivatives license in docs/ASSETS.md')
        elif not any(lic.upper() in upper for lic in APPROVED_LICENSES):
            err(f'asset pack "{pack}" has no recognised license in its docs/ASSETS.md row')
    print(f"Assets: {len(packs)} pack(s), {total / (1024 * 1024):.1f} MB")


def main() -> int:
    check_required_files()
    check_icon()
    check_json()
    check_export_presets()
    check_project_godot()
    check_no_keystores()
    check_assets()

    for message in warnings:
        print(f"::warning::{message}")
    for message in errors:
        print(f"::error::{message}")
    print(f"Validation (phase {CURRENT_PHASE}): {len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())