# Hide & Seek Cloudflare relay

Production: `wss://relay.arjunrao.dev/room/<code>`.
Each room has one authoritative browser host (Godot peer ID 1), up to nine
guests, and an independent SQLite-backed Durable Object. A room closes when
the host leaves. Room codes are shared identifiers, not authentication.

Run `npm ci`, `npm run dev`, or `npm run deploy` in this directory.
Run `node test.mjs` against localhost, or set `RELAY_URL=wss://relay.arjunrao.dev`.
Tests create and close temporary rooms.

Control messages are JSON (`welcome`, `joined`, `left`, host-only `kick` and
`refuse`). Godot packets are binary: 12-byte little-endian header followed by
opaque RPC bytes. Header fields are signed target peer, unsigned transfer
channel, and unsigned transfer mode. Target 0 broadcasts; negative targets
exclude that peer. The relay replaces target with the authenticated socket's
sender ID before delivery. WebSockets preserve order and reliable delivery
for all transfer modes. Sender IDs and membership survive DO hibernation in
socket attachments; no world state is persisted by the relay.

Limits: 10 players/room, 64 KiB/frame including header, 600 messages and 2 MiB
per second per socket. Production browser origins are allowlisted, but native
clients may omit Origin. The host simulates the world and is trusted by its
guests. There is no host migration or background-tab execution guarantee.
