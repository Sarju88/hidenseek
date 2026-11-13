# GitHub Pages web deployment

Source repository: https://github.com/Sarju88/hidenseek
Published game: https://hidenseek.arjunrao.dev

Build with the installed Godot 4.7.2 engine and matching single-threaded Web
export templates:

```sh
python3 scripts/deploy/build_web.py
```

Publish the contents of `exports/web-pages` to the root of the `gh-pages` branch.
GitHub Pages is configured to deploy that branch. Preserve `.nojekyll` and, once
a custom domain is configured, its `CNAME` file in subsequent deployments.
Use raw `index.wasm` on GitHub Pages; the older Cloudflare preparation script is
for a different host and must not gzip the Pages artifact in place.

The release uses WebGL 2 and does not require SharedArrayBuffer or special HTTP
headers. The editor-only MCP autoload and prototype scenes are excluded. Asset
references use source images, so exports do not depend on a developer's cache.

## Multiplayer server

Desktop and browser clients use the same Godot WebSocket multiplayer protocol.
The menu takes a server address such as `127.0.0.1:8080`; no signaling codes or
pairing panels are used. Desktop Host listens on that port. Browser Host
requests a new game on the running server, and Join connects to it.

Start the game server from source:

```sh
./run_headless_server.sh --port=8080
```

Or build the desktop/server executable, then run it headlessly:

```sh
python3 scripts/deploy/build_web.py --platform Linux
exports/linux/HideSeek.x86_64 --headless -- --port=8080
```

Docker uses that freshly exported executable and TCP port 8080:

```sh
docker build -t hidenseek-server .
docker run --rm -p 8080:8080 hidenseek-server
```

`127.0.0.1` is only the current computer. For remote players, expose this server
through a public WSS endpoint and enter that hostname/address in the menu.
GitHub Pages hosts static files only; it cannot listen for game connections.
Do not disable certificate verification. TLS is terminated by a secure reverse
proxy, with WebSocket upgrades forwarded to the Godot TCP listener.

## Verification

```sh
godot --headless --path . res://tests/web_menu_test.tscn
python3 scripts/deploy/build_web.py --browser-test --output exports/web-test
python3 -m http.server 8765 --directory exports/web-test
```

With a separate game server on port 18580 and two Paradev browser panes:

```sh
godot --headless --path . -- --port=18580 --bind=127.0.0.1
python3 tests/run_web_browser_test.py --workspace WORKSPACE_ID --host-pane HOST_PANE --guest-pane GUEST_PANE --server 127.0.0.1:18580
```

The fixture verifies real address-based connections, replicated movement, remote
60-second rounds, lobby movement locks, random roles, hiding/discovery, and menus. Inactive embedded panes throttle
RAF, so the fixture explicitly polls Godot networking/timers while controlling
both clients. It is excluded from production exports.

## Cloudflare custom domain

The live hostname is `hidenseek.arjunrao.dev`, with HTTPS enforced by GitHub Pages.
Cloudflare DNS has a DNS-only CNAME from `hidenseek` to `sarju88.github.io`.
Preserve `gh-pages/CNAME` and `deploy/CNAME` in future web exports.
The separate `relay.arjunrao.dev` hostname is a Cloudflare Worker custom domain.

The optional dedicated Godot server can still be exposed through ngrok:
run `ngrok http 8080` beside it and enter the assigned hostname as
`wss://YOUR-HOST.ngrok-free.dev` in the game. Normal browser rooms use the
Cloudflare relay below and do not require that server or tunnel.

## Cloudflare browser rooms

The production game uses `wss://relay.arjunrao.dev/room/ROOM_CODE`.
Enter a short room code (letters, numbers, `_` or `-`, up to 32 characters).
Host creates a room; up to nine friends enter the same code and Join.
A blank code uses `friends`. Use an uncommon code for a private group; codes
are not passwords. Rooms are case insensitive.

The host browser is Godot peer 1 and runs the authoritative gameplay logic.
Cloudflare Durable Objects forward Godot binary RPC packets and track room
membership. They do not run Godot or simulate the world. No home computer,
ngrok, Docker, or separate game server is needed for this mode. The host must
keep the game tab open and active; closing it disconnects the room. A new
host creates a new session rather than recovering the old round.

Explicit `ws://` / `wss://` server addresses still support dedicated Godot
servers. The relay is a separate protocol and uses `CloudflarePeer`, a
`MultiplayerPeerExtension`, instead of `WebSocketMultiplayerPeer`.

Relay source and deployment config live in `relay/`. Deploy with:

```sh
cd relay
npm ci
npm run deploy
```

Verify the relay locally or after deployment:

```sh
node relay/test.mjs
RELAY_URL=wss://relay.arjunrao.dev node relay/test.mjs
```

The test creates temporary isolated rooms, checks membership, binary packet
routing, sender IDs, duplicate hosts, room isolation, kicks, and host departure.
For local testing use `npm run dev` in `relay/`, then enter
`ws://127.0.0.1:8787/room/test-room` in the game.

Rebuild production with `python3 scripts/deploy/build_web.py` and publish
`exports/web-pages` to `gh-pages`, preserving `CNAME` and `.nojekyll`.
Cloudflare usage is subject to the account's Workers/Durable Objects limits.
