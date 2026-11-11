# GitHub Pages web deployment

Source repository: https://github.com/Sarju88/hidenseek
Published game: https://sarju88.github.io/hidenseek/

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

## Limits

The static web release supports direct browser-to-browser WebRTC multiplayer.
Host and Join exchange an invite and a reply manually; the host's browser is the
authoritative game server. Public STUN servers discover routes. Restricted NATs
may require a TURN relay; none is configured. The host must keep the game tab
open and active. Automatic short room codes would need a signaling service;
GitHub Pages does not run such a service. Desktop ENet sessions are separate.

For local browser integration tests:

```sh
python3 scripts/deploy/build_web.py --browser-test --output exports/web-test
python3 -m http.server 8765 --directory exports/web-test
```

This fixture exposes commands for two controlled browser instances to exchange
codes and inspect replicated state. It is excluded from production builds.
Normal export deliberately removes the fixture from a reused staging cache.

With two Paradev browser panes available, run the complete browser test using
those pane IDs and the workspace ID:

```sh
python3 tests/run_web_browser_test.py --workspace WORKSPACE_ID --host-pane HOST_PANE --guest-pane GUEST_PANE
```

The test exchanges real WebRTC invites/replies, checks replicated movement,
remote hiding and discovery, menu controls, and disconnect cleanup. Inactive
embedded panes throttle RAF, so the fixture explicitly polls Godot networking
and timers while the test controls both peers.

## Cloudflare custom domain

Desired hostname: `hidenseek.arjunrao.dev`.

Create a DNS-only CNAME record in the `arjunrao.dev` zone:

- Name: `hidenseek`
- Target: `sarju88.github.io`
- Proxy status: DNS only (grey cloud)
- TTL: Auto

Set the same hostname as the repository's Pages custom domain, preserve it in
`gh-pages/CNAME`, then enable HTTPS after GitHub provisions its certificate.
Do not change the domain's nameservers, root records, or unrelated subdomains.

Automation only needs a Cloudflare API token with Zone / DNS / Edit and Zone /
Zone / Read, restricted to the `arjunrao.dev` zone. Store it in a local file with
0600 permissions or a local environment variable. Do not put the token in this
repository or send it in chat. Domain configuration is pending that access or a
manual DNS record change by the owner.
