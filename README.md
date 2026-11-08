# Huss Valley · Based edition

A separate Huss Valley build using the supplied Based Hub's actual UI engine and media. The Giorgio/HussValley repository, loader and local source are not changed.

## Run in Potassium

~~~lua
local response = request({
    Url = "https://raw.githubusercontent.com/Daewid1/BasedRecreation/main/Loader.lua",
    Method = "GET",
})
assert(response.StatusCode == 200, "Could not download the installer")
assert(loadstring(response.Body, "=BasedRecreationLoader"))()
~~~

RightShift opens/closes the menu. K opens the Huss server browser. Ctrl+K opens search. Right-click a toggle/button to bind it; the Keys page manages bindings and the compact on-screen key list. First launch retains Based's interface picker; Settings can switch between Based, Unnamed and Novoline looks and replay the original intros.

All 72 original Huss feature controls remain. Immortal and its advanced options stay in one expandable group. The original Based Home film, intro choices, glass, springs, hover/click feedback, sounds, search, settings and alternate looks are reused rather than approximated. Unrelated Based gameplay modules are not included.

## Files and installation

- src/UI/: 20 extracted original UI modules, in src/order.json order.
- src/Menu/Adapter.lua: maps the existing Huss control contract onto native Based sections and controls.
- src/Game/HussValley.lua: existing Huss backend and menu definitions without the embedded Giorgio library.
- src/Manifest.lua: original icon/font/film metadata.
- BasedRecreation/: original fonts, images, soundtracks and effects assets; packs/: original packed film frames.
- BasedRecreation.lua: generated executable; Loader.lua: adapted original installer.
- licenses/ and CREDITS.md: retained source asset attribution.

The installer writes only BasedRecreation.lua and BasedRecreation/ in the executor workspace. It does not touch HussValley/ or BasedHub/. Preferences, profiles and download records are isolated in the new folder. Run one Huss gameplay edition at a time; two simultaneous gameplay backends are not a supported mode.

The original media collection contains 303 packs (about 1.32 GB total); a normal first install selects the appropriate film resolution instead of downloading every variant. Downloads use request(), an immutable commit pin, byte lengths and SHA-256 before writing. Completed packs are retained for resume. The films play after installation, not over the download screen. The runtime can start from an existing installation when offline.

## Build and check

Python 3.13 and the Luau CLI/compiler are used only by maintainers, not players.

~~~powershell
py -3.13 tools/build.py
py -3.13 tools/check.py --luau PATH_TO_LUAU --compiler PATH_TO_LUAU_COMPILE
~~~

After changing the runtime or assets, update the BUILD value in src/Manifest.lua and matching build value in tools/build.py, build/check, commit and push those files. Then run tools/build.py --pin FULL_COMMIT_SHA to write install.json referencing that immutable commit, and commit/push install.json. Never pin to a commit that does not contain the generated runtime and all referenced assets.

Saved preferences/profile behavior follows Based's own Config engine (including share-code import/export), not the Giorgio slot format. Existing Giorgio configurations are not migrated or overwritten.

Original Based code and third-party media remain their respective authors' work; see CREDITS.md and licenses/. No new license for third-party code or films is asserted here.
