-- Minecraft Creative: server. Owns the block world, its collision entities, and every action
-- that changes the world (place, break, physics switch, TNT).
MCC = MCC or {}
MCC.DirtyChunks = MCC.DirtyChunks or {}
MCC.ChunkEnts = MCC.ChunkEnts or {}
MCC.LooseProps = MCC.LooseProps or {}

for _, n in ipairs({ "mcc_set", "mcc_bulk", "mcc_chunk", "mcc_reset", "mcc_select", "mcc_action" }) do
	util.AddNetworkString(n)
end

local function BS() return MCC.Cfg.block_size end

-- ---------------------------------------------------------------- world lifecycle
-- Put the grid's floor exactly on the ground under the spawn point, so blocks sit flush on it.
function MCC.SetupWorld()
	local spawn
	for _, cls in ipairs({ "info_player_start", "info_player_deathmatch", "info_player_combine", "info_player_rebel" }) do
		spawn = ents.FindByClass(cls)[1]
		if IsValid(spawn) then break end
	end
	local pos = IsValid(spawn) and spawn:GetPos() or vector_origin
	local tr = util.TraceLine({ start = pos + Vector(0, 0, 16), endpos = pos - Vector(0, 0, 4096), mask = MASK_SOLID_BRUSHONLY })
	SetGlobalVector("mcc_origin", Vector(0, 0, tr.Hit and tr.HitPos.z or pos.z))
end

function MCC.ResetWorld()
	for _, e in pairs(MCC.ChunkEnts) do
		if IsValid(e) then e:Remove() end
	end
	MCC.ChunkEnts = {}
	MCC.DirtyChunks = {}
	MCC.LooseProps = {}
	MCC.ResetWorldData()
	net.Start("mcc_reset")
	net.Broadcast()
end

function MCC.SendWorld(ply)
	timer.Simple(1, function()
		if not IsValid(ply) then return end
		for _, ch in pairs(MCC.World.chunks) do
			local c = util.Compress(MCC.SerializeChunk(ch))
			net.Start("mcc_chunk")
			net.WriteInt(ch.cx, 32)
			net.WriteInt(ch.cy, 32)
			net.WriteInt(ch.cz, 32)
			net.WriteUInt(#c, 16)
			net.WriteData(c, #c)
			net.Send(ply)
		end
	end)
end

-- ---------------------------------------------------------------- changing blocks
local function writeCell(x, y, z, id)
	net.WriteInt(x, 32)
	net.WriteInt(y, 32)
	net.WriteInt(z, 32)
	net.WriteUInt(id, 8)
end

-- Returns true if the cell changed.
function MCC.SetBlock(x, y, z, id, nosend)
	local ch, old = MCC.SetBlockRaw(x, y, z, id)
	if old == id then return false end
	if ch then MCC.DirtyChunks[ch.key] = ch end
	if not nosend then
		net.Start("mcc_set")
		writeCell(x, y, z, id)
		net.Broadcast()
	end
	return true
end

-- list of { x, y, z, id }; one network message per 1000 changes.
function MCC.SetBlocksBulk(list)
	local changed = {}
	for _, c in ipairs(list) do
		if MCC.SetBlock(c[1], c[2], c[3], c[4], true) then changed[#changed + 1] = c end
	end
	for i = 1, #changed, 1000 do
		local n = math.min(1000, #changed - i + 1)
		net.Start("mcc_bulk")
		net.WriteUInt(n, 16)
		for j = i, i + n - 1 do
			local c = changed[j]
			writeCell(c[1], c[2], c[3], c[4])
		end
		net.Broadcast()
	end
end

-- Rebuild collision for every chunk changed since the last tick.
function MCC.FlushDirty()
	local cs = MCC.Cfg.chunk_size
	for key, ch in pairs(MCC.DirtyChunks) do
		MCC.DirtyChunks[key] = nil
		local ent = MCC.ChunkEnts[key]
		if ch.removed or ch.count <= 0 then
			if IsValid(ent) then ent:Remove() end
			MCC.ChunkEnts[key] = nil
		else
			if not IsValid(ent) then
				ent = ents.Create("mcc_chunk")
				ent:SetPos(MCC.CellMins(ch.cx * cs, ch.cy * cs, ch.cz * cs))
				ent:SetAngles(Angle(0, 0, 0))
				ent:SetChunkX(ch.cx)
				ent:SetChunkY(ch.cy)
				ent:SetChunkZ(ch.cz)
				ent:Spawn()
				MCC.ChunkEnts[key] = ent
			end
			ent:BuildCollision(ch)
		end
	end
end

function MCC.ServerThink()
	if next(MCC.DirtyChunks) then MCC.FlushDirty() end
end

-- Nothing solid in the way: map brushes, players, NPCs or props.
function MCC.CellIsFree(x, y, z)
	local bs = BS()
	local mins = MCC.CellMins(x, y, z)
	local maxs = mins + Vector(bs, bs, bs)
	if bit.band(util.PointContents(MCC.CellCenter(x, y, z)), CONTENTS_SOLID) ~= 0 then return false end
	local eps = 0.5
	for _, p in ipairs(player.GetAll()) do
		if p:Alive() then
			local pmin, pmax = p:GetPos() + p:OBBMins(), p:GetPos() + p:OBBMaxs()
			if pmin.x < maxs.x - eps and pmax.x > mins.x + eps and pmin.y < maxs.y - eps and pmax.y > mins.y + eps
				and pmin.z < maxs.z - eps and pmax.z > mins.z + eps then
				return false
			end
		end
	end
	for _, e in ipairs(ents.FindInBox(mins + Vector(eps, eps, eps), maxs - Vector(eps, eps, eps))) do
		local cls = e:GetClass()
		if e:IsNPC() or cls == "mcc_block_prop" or cls == "prop_physics" or e:IsVehicle() then return false end
	end
	return true
end

-- ---------------------------------------------------------------- props (blocks turned into physics)
function MCC.TrackProp(e)
	local list = MCC.LooseProps
	list[#list + 1] = e
	if #list > MCC.Cfg.max_loose_props then
		local keep = {}
		for _, p in ipairs(list) do
			if IsValid(p) then keep[#keep + 1] = p end
		end
		while #keep > MCC.Cfg.max_loose_props do
			local oldest = table.remove(keep, 1)
			if IsValid(oldest) then oldest:Remove() end
		end
		MCC.LooseProps = keep
	end
end

function MCC.SpawnBlockProp(id, x, y, z, owner)
	local e = ents.Create("mcc_block_prop")
	if not IsValid(e) then return nil end
	e:SetBlockId(id)
	e:SetPos(MCC.CellCenter(x, y, z))
	e:SetAngles(Angle(0, 0, 0))
	e.mccOwner = owner
	e:Spawn()
	e:Activate()
	if IsValid(owner) and owner:IsPlayer() and cleanup then cleanup.Add(owner, "props", e) end
	MCC.TrackProp(e)
	return e
end

-- Remove cells from the world and make sure their collision is gone before props appear there.
local function clearCells(cells)
	local changes = {}
	for i, c in ipairs(cells) do changes[i] = { c[1], c[2], c[3], 0 } end
	MCC.SetBlocksBulk(changes)
	MCC.FlushDirty()
end

function MCC.Explode(pos, inflictor, attacker)
	local cfg = MCC.Cfg
	local ed = EffectData()
	ed:SetOrigin(pos)
	ed:SetMagnitude(1)
	ed:SetScale(1)
	util.Effect("Explosion", ed, true, true)
	MCC.PlayEffect("explosion", pos)
	local world = game.GetWorld()
	util.BlastDamage(IsValid(inflictor) and inflictor or world, IsValid(attacker) and attacker or world,
		pos, cfg.tnt_radius * BS(), cfg.tnt_damage)

	local r = cfg.tnt_radius
	local cx, cy, cz = MCC.PosToCell(pos)
	local cells = {}
	for x = cx - r, cx + r do
		for y = cy - r, cy + r do
			for z = cz - r, cz + r do
				local d2 = (x - cx) ^ 2 + (y - cy) ^ 2 + (z - cz) ^ 2
				if d2 <= r * r then
					local id = MCC.GetBlock(x, y, z)
					if id ~= 0 then cells[#cells + 1] = { x, y, z, id, d2 } end
				end
			end
		end
	end
	if #cells == 0 then return end
	table.sort(cells, function(a, b) return a[5] < b[5] end)
	clearCells(cells)

	local flung = 0
	for _, c in ipairs(cells) do
		if MCC.Blocks[c[4]].special == "tnt" then
			local e = MCC.SpawnBlockProp(c[4], c[1], c[2], c[3], attacker)
			if IsValid(e) then e:Prime(math.Rand(cfg.tnt_chain_fuse_min, cfg.tnt_chain_fuse_max)) end
		elseif flung < cfg.tnt_max_props then
			flung = flung + 1
			local e = MCC.SpawnBlockProp(c[4], c[1], c[2], c[3], attacker)
			if IsValid(e) then
				local phys = e:GetPhysicsObject()
				if IsValid(phys) then
					local dir = (e:GetPos() - pos):GetNormalized() + Vector(0, 0, 0.5)
					phys:SetVelocity(dir * cfg.tnt_fling_speed * math.Rand(0.6, 1))
					phys:AddAngleVelocity(VectorRand() * 200)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- actions
function MCC.Actions.Break(ply)
	local t = MCC.GetTarget(ply)
	if not t or t.kind ~= "block" then return end
	if MCC.Blocks[t.id].special == "tnt" and not ply:Crouching() then
		clearCells({ { t.x, t.y, t.z } })
		local e = MCC.SpawnBlockProp(t.id, t.x, t.y, t.z, ply)
		if IsValid(e) then e:Prime(MCC.Cfg.tnt_fuse) end
		return
	end
	MCC.SetBlock(t.x, t.y, t.z, 0)
	MCC.PlayBlockSound(t.id, "break", MCC.CellCenter(t.x, t.y, t.z))
end

function MCC.Actions.Place(ply)
	local id = ply.mccBlock
	if not MCC.Blocks[id] then return end
	if MCC.World.count >= MCC.Cfg.max_blocks then
		ply:ChatPrint("This world has reached its block limit (" .. MCC.Cfg.max_blocks .. ").")
		return
	end
	local t = MCC.GetTarget(ply)
	if not t then return end
	local x, y, z = t.px, t.py, t.pz
	if MCC.GetBlock(x, y, z) ~= 0 or not MCC.CellIsFree(x, y, z) then return end
	MCC.SetBlock(x, y, z, id)
	MCC.PlayBlockSound(id, "place", MCC.CellCenter(x, y, z))
end

-- Everything connected to the block you're looking at becomes loose physics blocks.
function MCC.Actions.MakePhysics(ply)
	if not MCC.IsHoldingHand(ply) then return end
	local t = MCC.GetTarget(ply)
	if not t or t.kind ~= "block" then return end
	local cells = MCC.FloodFill(t.x, t.y, t.z, MCC.Cfg.max_physics_blocks)
	clearCells(cells)
	for _, c in ipairs(cells) do
		MCC.SpawnBlockProp(c[4], c[1], c[2], c[3], ply)
	end
	MCC.PlayBlockSound(t.id, "break", MCC.CellCenter(t.x, t.y, t.z))
end

function MCC.Actions.SwapTool(ply)
	local w = ply:GetActiveWeapon()
	if IsValid(w) and w:GetClass() == "mcc_hand" then
		if ply:HasWeapon("weapon_physgun") then ply:SelectWeapon("weapon_physgun") end
	else
		ply:SelectWeapon("mcc_hand")
	end
end

function MCC.Actions.ToggleFly(ply)
	if not ply:Alive() or ply:InVehicle() or ply:GetMoveType() ~= MOVETYPE_WALK then return end
	ply:SetNW2Bool("mcc_fly", not ply:GetNW2Bool("mcc_fly"))
end

function MCC.KeyPress(ply, key)
	if key ~= IN_JUMP then return end
	local now = CurTime()
	if ply.mccLastJump and now - ply.mccLastJump < MCC.Cfg.double_tap_window then
		ply.mccLastJump = nil
		MCC.Actions.ToggleFly(ply)
	else
		ply.mccLastJump = now
	end
end

function MCC.PlayerLoadout(ply)
	ply:Give("mcc_hand")
	ply:Give("weapon_physgun")
	ply:Give("gmod_tool")
	ply:Give("gmod_camera")
	ply:SelectWeapon("mcc_hand")
	ply:SetJumpPower(MCC.Cfg.jump_power)
	ply:SetNW2Bool("mcc_fly", false)
	ply.mccBlock = ply.mccBlock or MCC.DefaultHotbar[1]
	return true
end

-- ---------------------------------------------------------------- requests from clients
net.Receive("mcc_select", function(_, ply)
	local id = net.ReadUInt(8)
	if MCC.Blocks[id] then ply.mccBlock = id end
end)

local remoteActions = { MakePhysics = true, SwapTool = true }
net.Receive("mcc_action", function(_, ply)
	local name = net.ReadString()
	if not remoteActions[name] then return end
	if (ply.mccNextAction or 0) > CurTime() then return end
	ply.mccNextAction = CurTime() + 0.25
	MCC.Actions[name](ply)
end)
