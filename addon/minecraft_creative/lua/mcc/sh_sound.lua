-- Minecraft Creative: sounds. Uses the player's own Minecraft sounds (copied into sound/mcc/
-- by the helper at launch) and falls back to Garry's Mod sounds for any file that is missing.
MCC = MCC or {}
MCC.SoundCache = MCC.SoundCache or {}

function MCC.ResolveSound(key)
	local c = MCC.SoundCache[key]
	if c == nil then
		local p = "mcc/" .. key .. ".ogg"
		c = file.Exists("sound/" .. p, "GAME") and p or false
		MCC.SoundCache[key] = c
	end
	return c
end

-- Random available Minecraft sound from a list, else the fallback. Second value: true if Minecraft.
function MCC.PickSound(list, fallback)
	local avail = {}
	for _, k in ipairs(list) do
		local p = MCC.ResolveSound(k)
		if p then avail[#avail + 1] = p end
	end
	if #avail > 0 then return avail[math.random(#avail)], true end
	return fallback, false
end

-- kind: "break" or "place". Played at a world position for everyone nearby.
function MCC.PlayBlockSound(blockNum, kind, pos)
	local b = MCC.Blocks[blockNum]
	if not b then return end
	local g = MCC.SoundGroups[b.sound]
	local path = MCC.PickSound(g[kind], g.fallback[kind])
	sound.Play(path, pos, 75, kind == "place" and g.place_pitch or 100, 1)
end

function MCC.PlayEffect(id, pos)
	local e = MCC.Effects[id]
	if not e then return end
	sound.Play((MCC.PickSound(e.sounds, e.fallback)), pos, e.level, e.pitch, 1)
end
