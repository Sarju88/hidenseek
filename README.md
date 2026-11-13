# Hide & Seek Arena

A third-person Godot game set in a furnished office and courtyard, with Kenney
models and sounds. Hide in closets, tree canopies, under desks, inside large
storage boxes, and in low cabinets. Seekers inspect spots to find hiders.

## Play

Browser build: https://hidenseek.arjunrao.dev

- WASD: move; mouse: look; Space: jump; Escape: pause.
- E: hide, exit, or check the object you are looking at.
- Host clicks Start Game with at least two players; everyone waits frozen in the lobby.
- One random seeker stays blind and frozen for 60 seconds while hiders hide.
- After the countdown, the seeker can move and check hiding spots.
- Caught players and late joins wait for the next round.
- White outline + hand + E keycap: an interactable hiding spot.

## Play together with Cloudflare rooms

1. Everyone opens https://hidenseek.arjunrao.dev.
2. Enter a shared room code, such as `friends42`, in **Room code / server**.
3. One player clicks **Host**; everyone else enters the same code and clicks **Join**.
4. With at least two players connected, the host clicks **Start Game**.

Cloudflare relays the multiplayer packets at `relay.arjunrao.dev`; the host
browser runs the game session. No ngrok, home server, or desktop installation
is needed. Keep the host tab open and active: closing it ends the room.
Up to 10 players can join each room. Codes are case insensitive, accept letters,
numbers, `_` and `-`, and have a 32-character limit. A blank code uses `friends`.
Choose an uncommon code for your group; room codes are not passwords.

The relay source, configuration, and tests are in [relay/](relay/README.md).

## Optional dedicated server by address

1. In the desktop game, enter `127.0.0.1:8080` and click **Host**.
2. Another desktop or browser client on the same computer enters
   `127.0.0.1:8080` and clicks **Join**.
3. For other computers, use the host computer's LAN/public address instead
   of `127.0.0.1` (which always means the player's own computer).

Explicit server addresses use WebSocket multiplayer. A desktop Host uses the
port from the address field; short room codes use the Cloudflare relay instead.

A dedicated server can also be started from this project:

```sh
./run_headless_server.sh --port=8080
```

When an explicit server address is entered, browser **Host** connects to that
Godot server and starts a game there; **Join** connects to its existing game.
This optional mode requires a desktop Host or dedicated server at that address.
With a room code, the browser hosts through Cloudflare instead.

The GitHub Pages HTTPS build can join loopback addresses directly in supported
browsers. Public internet servers must provide a secure `wss://` endpoint,
typically through a TLS reverse proxy. GitHub Pages serves the game files;
it does not run the game server. Local HTTP web builds can use plain `ws://`
LAN servers. Explicit `ws://` and `wss://` URLs are accepted as well as IP:port.

Quit is absent in web menus. Escape opens Pause; Resume and Main Menu work.

## Develop and export

Open `project.godot` in Godot 4.7.2 with the Compatibility renderer. Run the main
scene. Enter a room code and select Host or Join for Cloudflare multiplayer,
or enter an explicit server address for a desktop LAN session.

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
