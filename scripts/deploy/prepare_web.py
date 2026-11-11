"""Prepare Godot's single-threaded Web export for Workers Static Assets."""
import gzip,hashlib,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[2]
source=root/'exports/web';target=root/'exports/cloudflare'
if target.exists():shutil.rmtree(target)
shutil.copytree(source,target)
wasm=target/'index.wasm';original=wasm.read_bytes()
compressed=gzip.compress(original,compresslevel=9,mtime=0)
assert gzip.decompress(compressed)==original
wasm.write_bytes(compressed)
(target/'_headers').write_text('/index.wasm\n  Content-Type: application/wasm\n  Content-Encoding: gzip\n  Cache-Control: no-cache\n\n/*\n  X-Content-Type-Options: nosniff\n  Referrer-Policy: strict-origin-when-cross-origin\n')
for file in target.rglob('*'):
 if file.is_file() and file.stat().st_size>25*1024*1024:raise SystemExit(f'Cloudflare asset limit exceeded: {file}')
print(f'Prepared {target}; WASM {len(original)} -> {len(compressed)} bytes, roundtrip SHA256 {hashlib.sha256(original).hexdigest()}')
