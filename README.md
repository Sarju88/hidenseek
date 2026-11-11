# Hide & Seek Arena

A third-person Godot game set in a furnished office and courtyard, with Kenney
models and sounds. Hide in closets, tree canopies, under desks, inside large
storage boxes, and in low cabinets. Seekers inspect spots to find hiders.

## Play

Browser build: https://sarju88.github.io/hidenseek/

- WASD: move; mouse: look; Space: jump; Escape: pause.
- E: hide, exit, or check the object you are looking at.
- R (or F6 on desktop): switch between hider and seeker in solo play.
- White outline + hand + E keycap: an interactable hiding spot.

The browser version is solo. Desktop builds support LAN multiplayer using ENet
(port 8080). Static GitHub Pages hosting does not provide a multiplayer server.

## Develop and export

Open `project.godot` in Godot 4.7.2 with the Compatibility renderer. Run the main
scene. Select Host to play locally or Join for a desktop LAN session.

Install the matching Godot Web export templates, then run:

```sh
python3 scripts/deploy/build_web.py
python3 -m http.server 8765 --directory exports/web-pages
```

The exporter stages the active game, imports assets cleanly, and omits the MCP
editor plugin and unused prototype scenes/scripts. Output is a single-threaded
WebGL 2 build that works on GitHub Pages without cross-origin isolation headers.

See [deployment instructions](deploy/README.md) and [hiding/audio/camera notes](HIDING_SYSTEM.md).
The `gh-pages` branch contains the generated browser build; `main` contains source.

## Credits

Based on the 3D multiplayer template; see the original MIT [LICENSE](LICENSE).
Kenney assets and sounds retain their bundled license and attribution files in
`assets/`. Additional shooter asset credits are in [ATTRIBUTIONS-SHOOTER.md](ATTRIBUTIONS-SHOOTER.md).
Earlier prototype scripts/scenes are retained in the source repository; the web
export manifest deliberately excludes them.
