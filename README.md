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

## Host and join by address

1. In the desktop game, enter `127.0.0.1:8080` and click **Host**.
2. Another desktop or browser client on the same computer enters
   `127.0.0.1:8080` and clicks **Join**.
3. For other computers, use the host computer's LAN/public address instead
   of `127.0.0.1` (which always means the player's own computer).

All clients now use WebSocket multiplayer. No invite/reply codes or pairing
panels are involved. The host uses the port from the address field.

A dedicated server can also be started from this project:

```sh
./run_headless_server.sh --port=8080
```

Browsers cannot open a listening server port. Browser **Host** connects to the
entered game server and starts a game there; **Join** connects to its existing
game. A desktop Host or dedicated server must be running at that address.
Browser Host reports an existing session and asks you to use Join instead.

The GitHub Pages HTTPS build can join loopback addresses directly in supported
browsers. Public internet servers must provide a secure `wss://` endpoint,
typically through a TLS reverse proxy. GitHub Pages serves the game files;
it does not run the game server. Local HTTP web builds can use plain `ws://`
LAN servers. Explicit `ws://` and `wss://` URLs are accepted as well as IP:port.

Quit is absent in web menus. Escape opens Pause; Resume and Main Menu work.

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
Build the Linux desktop/server executable with the same clean staging process:

```sh
python3 scripts/deploy/build_web.py --platform Linux
# Desktop UI: exports/linux/HideSeek.x86_64
# Dedicated: exports/linux/HideSeek.x86_64 --headless -- --port=8080
```

The `gh-pages` branch contains the generated browser build; `main` contains source.

## Credits

Based on the 3D multiplayer template; see the original MIT [LICENSE](LICENSE).
Kenney assets and sounds retain their bundled license and attribution files in
`assets/`. Additional shooter asset credits are in [ATTRIBUTIONS-SHOOTER.md](ATTRIBUTIONS-SHOOTER.md).
Earlier prototype scripts/scenes are retained in the source repository; the web
export manifest deliberately excludes them.
