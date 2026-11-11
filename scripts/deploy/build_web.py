#!/usr/bin/env python3
"""Export the active game, excluding editor plugins and archived prototypes."""
import argparse
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
    parser.add_argument("--output", type=Path, default=ROOT / "exports/web-pages")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="hidenseek-web-") as temp:
        stage = Path(temp)
        for directory in DIRECTORIES:
            shutil.copytree(ROOT / directory, stage / directory,
                            ignore=shutil.ignore_patterns("*.import", "FBX format", "OBJ format"))
        for filename in FILES:
            target = stage / filename
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / filename, target)
            sidecar = ROOT / (filename + ".uid")
            if sidecar.exists(): shutil.copy2(sidecar, stage / (filename + ".uid"))
        settings = (ROOT / "project.godot").read_text()
        settings = "\n".join(line for line in settings.splitlines()
                             if not line.startswith("_mcp_game_helper=") and not line.startswith("enabled=PackedStringArray(\"res://addons/"))
        settings = settings.replace('run/main_scene="uid://dugaivbj1o66n"', 'run/main_scene="res://scenes/level/level.tscn"')
        (stage / "project.godot").write_text(settings + "\n")
        presets = (ROOT / "export_presets.cfg").read_text()
        (stage / "export_presets.cfg").write_text(presets)
        godot = os.environ.get("GODOT", "godot")
        subprocess.run([godot, "--headless", "--path", str(stage), "--editor", "--import"], check=True)
        subprocess.run([godot, "--headless", "--path", str(stage), "--export-release", "Web", str(output / "index.html")], check=True)
    for sidecar in output.glob("*.import"): sidecar.unlink()
    (output / ".nojekyll").touch()
    print(f"Web build ready: {output}")

if __name__ == "__main__":
    main()
