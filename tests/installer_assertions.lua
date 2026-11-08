
assert(plain("fonts/Inter.ttf"))
for _, path in ipairs({ "../other", "/absolute", "a//b", "prefs.json", "config/old.json", "cache/record.json", "C:/outside", "a\\b" }) do
	assert(not plain(path), path)
end
assert(verified("abc", 3, string.rep("a", 64)))
assert(not verified("abd", 3, string.rep("a", 64)))
assert(not verified("abc", 4, string.rep("a", 64)))
assert(not verified("abc", 3, "invalid"))
assert(verified("a\0b", 3, string.rep("b", 64)))
assert(hashedData == "a\0b")
hashAvailable = false
assert(not verified("abc", 3, string.rep("a", 64)))
hashAvailable = true
local pack = { at = "packs/test.pack", size = 17, stamp = "test", prefix = "film/hd/test_", from = 0, to = 1, digits = 4, ext = ".jpg" }
assert(soundPack(pack))
local bad = table.clone(pack)
bad.prefix = "film/../../escape_"
assert(not soundPack(bad))
assert(unpack(pack, "BHPK1 2\n1 2\nabc"))
assert(memory["BasedRecreation/film/hd/test_0000.jpg"] == "a")
assert(memory["BasedRecreation/film/hd/test_0001.jpg"] == "bc")
assert(not unpack(pack, "BHPK1 2\n1 2\nab"))
assert(not unpack(pack, "BHPK1 3\n1 1 1\nabc"))
local film = { sets = {
	{ name = "ultra", minHeight = 800, packs = { pack } },
	{ name = "hd", minHeight = 0, packs = { { at = "packs/hd.pack", size = 17, stamp = "hd", prefix = "film/hd/missing_", from = 0, to = 1, digits = 4, ext = ".jpg" } } },
} }
local plan = filmPlan(film, { files = {}, packs = {} }, "fixture")
assert(plan == nil)
memory = {}
plan = filmPlan(film, { files = {}, packs = {} }, "fixture")
assert(plan and plan.count == 1)
assert(plan.last[1].pack.at == "packs/hd.pack")
decoded = { format = 1, build = "20261108.1900", commit = string.rep("a", 40), hub = { size = 3 }, files = {} }
assert(readList("fixture"))
decoded.commit = "main"
assert(not readList("fixture"))
print("PASS installer: paths, protected preferences, SHA-256, corrupt frames, pack boundaries, commit pins, resolution")

