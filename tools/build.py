import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def build():
    order = json.loads((ROOT / "src/order.json").read_text(encoding="utf-8"))
    parts = [(ROOT / "src/Manifest.lua").read_text(encoding="utf-8")]
    parts += [(ROOT / "src/UI" / name).read_text(encoding="utf-8") for name in order]
    parts += [(ROOT / "src/Menu/Adapter.lua").read_text(encoding="utf-8")]
    game = (ROOT / "src/Game/HussValley.lua").read_text(encoding="utf-8")
    parts += ["local function startHuss()\n" + game + "\nend\nB.Huss = startHuss()\nreturn B\n"]
    runtime = "\n".join(parts)
    assert "game:HttpGet(" not in runtime
    assert 'root = "BasedRecreation"' in runtime
    assert "genv.HUSS_BASED = B" in runtime
    assert "Giorgio / Lumen" not in runtime
    (ROOT / "BasedRecreation.lua").write_text(runtime, encoding="utf-8", newline="\n")
    return runtime


def metadata(path):
    data = path.read_bytes()
    if path.suffix == ".lua":
        data = data.replace(b"\r\n", b"\n")
    return {"size": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def manifest(pin):
    assert re.fullmatch(r"[0-9a-f]{40}", pin), "Expected a complete commit SHA"
    result = json.loads((ROOT / "tools/install.reference.json").read_text(encoding="utf-8"))
    result["build"] = "20261108.1901"
    result["commit"] = pin
    result["hub"] = metadata(ROOT / "BasedRecreation.lua")
    source = (ROOT / "src/Manifest.lua").read_text(encoding="utf-8")
    files = re.search(r'B\.MANIFEST = \{\["files"\]=\{(.*?)\}', source).group(1)
    included = set(re.findall(r'\["([^"]+)"\]=', files))
    result["files"] = {name: entry for name, entry in result["files"].items() if name in included}
    assert set(result["files"]) == included
    for name, entry in result["files"].items():
        entry.update(metadata(ROOT / "BasedRecreation" / name))
    for name in ("film", "board", "reel", "lock", "prates", "brand", "richard"):
        for path, entry in result[name]["files"].items():
            entry.update(metadata(ROOT / "BasedRecreation" / path))
        for size in result[name]["sets"]:
            for pack in size["packs"]:
                pack.update(metadata(ROOT / pack["at"]))
    (ROOT / "install.json").write_text(json.dumps(result, separators=(",", ":")) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--pin")
    args = parser.parse_args()
    runtime = build()
    if args.pin:
        manifest(args.pin)
    print(f"Built {len(runtime.encode('utf-8')):,} bytes from original UI modules and Huss Valley backend.")

