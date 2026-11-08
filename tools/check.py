import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from build import metadata

ROOT = Path(__file__).resolve().parents[1]


def run(binary, *args):
    subprocess.run([str(binary), *map(str, args)], cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", type=Path, required=True)
    parser.add_argument("--compiler", type=Path, required=True)
    args = parser.parse_args()
    run(args.compiler, "--null", ROOT / "BasedRecreation.lua")
    run(args.compiler, "--null", ROOT / "Loader.lua")
    folder = ROOT / ".test"
    folder.mkdir(exist_ok=True)
    fixture = folder / "line_endings.lua"
    fixture.write_bytes(b"return true\r\n")
    assert metadata(fixture) == {"size": 12, "sha256": hashlib.sha256(b"return true\n").hexdigest()}
    fixture = folder / "adapter.lua"
    sources = ["tests/adapter_setup.lua", "src/UI/05_config.lua", "src/Menu/Adapter.lua", "tests/adapter_assertions.lua"]
    fixture.write_text("\n".join((ROOT / path).read_text(encoding="utf-8") for path in sources), encoding="utf-8")
    run(args.luau, fixture)
    loader = (ROOT / "Loader.lua").read_text(encoding="utf-8")
    fixture = folder / "installer.lua"
    fixture.write_text((ROOT / "tests/installer_setup.lua").read_text(encoding="utf-8") + "\n" + loader[:loader.index("local BASE, INK")] + "\n" + (ROOT / "tests/installer_assertions.lua").read_text(encoding="utf-8"), encoding="utf-8")
    run(args.luau, fixture)
    runtime = (ROOT / "BasedRecreation.lua").read_text(encoding="utf-8")
    assert "game:HttpGet(" not in runtime
    assert "Giorgio / Lumen" not in runtime
    assert "genv.BASED =" not in runtime
    assert 'root = "BasedHub"' not in runtime
    assert "do -- dahood" not in runtime
    assert "do -- 26_flight.lua" not in runtime
    assert "bh_flight_pack" not in runtime and "fly.key." not in runtime and "B.Flight" not in runtime
    assert 'own:keybind({ id = "fly.key.boost"' not in (ROOT / "src/UI/51_keys.lua").read_text(encoding="utf-8")
    assert "Config.capturing" in runtime and "GetFocusedTextBox" in runtime
    expected = set(json.loads((ROOT / "tests/feature_flags.json").read_text(encoding="utf-8")))
    game_source = (ROOT / "src/Game/HussValley.lua").read_text(encoding="utf-8")
    actual = set(re.findall(r'Flag\s*=\s*"([^"]+)"', game_source))
    assert actual == expected and len(actual) == 72, (expected - actual, actual - expected)
    source = (ROOT / "tools/install.reference.json").read_text(encoding="utf-8")
    reference = json.loads(source)
    release = json.loads((ROOT / "install.json").read_text(encoding="utf-8"))
    assert not any(name.startswith(("fx/", "sfx/bh_fly_", "sfx/bh_hit_")) for name in release["files"])
    for name, item in release["files"].items():
        assert metadata(ROOT / "BasedRecreation" / name) == {"size": item["size"], "sha256": item["sha256"]}, name
    count = 0
    for key in ("film", "board", "reel", "lock", "prates", "brand", "richard"):
        for size in reference[key]["sets"]:
            for pack in size["packs"]:
                data = (ROOT / pack["at"]).read_bytes()
                assert len(data) == pack["size"], pack["at"]
                header, sizes, body = data.split(b"\n", 2)
                frames = int(header.removeprefix(b"BHPK1 "))
                lengths = list(map(int, sizes.split(b",")))
                assert frames == len(lengths) == pack["to"] - pack["from"] + 1
                assert sum(lengths) == len(body)
                count += 1
    assert count == 303
    print(f"PASS source isolation and all {count} original film packs")


if __name__ == "__main__":
    main()

