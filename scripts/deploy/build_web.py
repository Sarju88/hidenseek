#!/usr/bin/env python3
"""Export the active game, excluding editor plugins and archived prototypes."""
import argparse
import contextlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
DIRECTORIES = ["assets", "scenes/level", "scenes/ui", "scenes/items", "scripts/audio", "scripts/hiding", "scripts/inventory", "scripts/items", "scripts/ui", "scripts/shooter"]
FILES = ["icon.png", "scripts/level/level.gd", "scripts/player/player.gd", "scripts/player/spring_arm_offset.gd", "scripts/player/3d_godot_robot.gd", "scripts/autoload/game_manager.gd", "scripts/autoload/network.gd", "scripts/autoload/item_database.gd", "scripts/safe_zone.gd"]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    parser.add_argument("--platform", choices=["Web", "Linux"], default="Web")
    parser.add_argument("--browser-test", action="store_true", help="Include local browser integration fixture")
    parser.add_argument("--stage-dir", type=Path, help="Reuse an ignored staging directory and its import cache")
    args = parser.parse_args()
    if args.browser_test and args.platform != "Web": parser.error("--browser-test requires Web")
    output = (args.output or ROOT / ("exports/web-pages" if args.platform == "Web" else "exports/linux")).resolve()
    output.mkdir(parents=True, exist_ok=True)
    context = contextlib.nullcontext(str(args.stage_dir.resolve())) if args.stage_dir else tempfile.TemporaryDirectory(prefix="hidenseek-web-")
    with context as temp:
        stage = Path(temp)
        stage.mkdir(parents=True, exist_ok=True)
        # Reused import caches must not retain removed gameplay code.
        for directory in ["scripts", "scenes"]:
            if (stage / directory).exists(): shutil.rmtree(stage / directory)
        for directory in DIRECTORIES:
            shutil.copytree(ROOT / directory, stage / directory, dirs_exist_ok=True,
                            ignore=shutil.ignore_patterns("*.import", "FBX format", "OBJ format"))
        for filename in FILES:
            target = stage / filename
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / filename, target)
            sidecar = ROOT / (filename + ".uid")
            if sidecar.exists(): shutil.copy2(sidecar, stage / (filename + ".uid"))
        if args.browser_test:
            for filename in ["web_browser_test.gd", "web_browser_test.tscn"]:
                shutil.copy2(ROOT / "tests" / filename, stage / filename)
            fixture = stage / "web_browser_test.tscn"
            fixture.write_text(fixture.read_text().replace("res://tests/web_browser_test.gd", "res://web_browser_test.gd"))
        if not args.browser_test:
            for filename in ["web_browser_test.gd", "web_browser_test.tscn"]:
                (stage / filename).unlink(missing_ok=True)
        settings = (ROOT / "project.godot").read_text()
        settings = "\n".join(line for line in settings.splitlines()
                             if not line.startswith("_mcp_game_helper=") and not line.startswith("enabled=PackedStringArray(\"res://addons/"))
        settings = settings.replace('run/main_scene="uid://dugaivbj1o66n"', 'run/main_scene="res://scenes/level/level.tscn"')
        if args.browser_test:
            settings = settings.replace('run/main_scene="res://scenes/level/level.tscn"', 'run/main_scene="res://web_browser_test.tscn"')
        (stage / "project.godot").write_text(settings + "\n")
        presets = (ROOT / "export_presets.cfg").read_text()
        (stage / "export_presets.cfg").write_text(presets)
        godot = os.environ.get("GODOT", "godot")
        subprocess.run([godot, "--headless", "--path", str(stage), "--editor", "--import"], check=True)
        subprocess.run([godot, "--headless", "--path", str(stage), "--export-release", args.platform, str(output / ("index.html" if args.platform == "Web" else "HideSeek.x86_64"))], check=True)
    for sidecar in output.glob("*.import"): sidecar.unlink()
    if args.platform == "Web": (output / ".nojekyll").touch()
    print(f"{args.platform} build ready: {output}")

if __name__ == "__main__":
    main()
