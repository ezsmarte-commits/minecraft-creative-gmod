-- luajit tests/run_tests.lua   (run from the project folder)
package.path = (arg[0]:match("^(.*)/tests/") or ".") .. "/tests/?.lua;" .. package.path
local H = require("harness")
local V = H.Vector

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
		print("  ok    " .. name)
	else
		failed = failed + 1
		print("  FAIL  " .. name .. "\n        " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

-- Pretend the helper already copied every Minecraft file in.
local manifest = io.open(H.ADDON .. "/helper/assets.txt")
for line in manifest:lines() do
	local kind, name = line:match("^(%w+) (.+)$")
	if kind == "texture" then H.files["materials/mcc/block/" .. name .. ".png"] = true end
	if kind == "sound" then H.files["sound/mcc/" .. name .. ".ogg"] = true end
end
manifest:close()

local S = H.boot("server")
local C = H.boot("client")
local MS, MC = S.MCC, C.MCC
local BS = MS.Cfg.block_size

-- One player, seen as a server player and as the client's LocalPlayer.
local sply = H.newPlayer(S)
H.players.server = { sply }
H.clientServerPlayer = sply
local cply = H.newPlayer(C)
H.clientPlayer = cply

print("Loading")
test("every hook row resolves to a function in its realm", function()
	local sheet = assert(io.open(H.ADDON .. "/../../sheets/hooks.json")):read("*a")
	local n = 0
	for id, hook, realm, fn in sheet:gmatch('"id": "([^"]+)",%s*"hook": "([^"]+)",%s*"realm": "([^"]+)",%s*"fn": "([^"]+)"') do
		n = n + 1
		for _, env in ipairs({ S, C }) do
			local wants = realm == "shared" or realm == env.name
			local added = env.hooks[hook] and env.hooks[hook]["mcc_" .. id]
			eq(added ~= nil, wants, env.name .. " hook " .. id)
			if wants then assert(type(env.MCC[fn]) == "function", env.name .. " missing MCC." .. fn) end
		end
	end
	eq(n, 18, "hook rows parsed")
end)

test("every control action exists where it is handled", function()
	for _, c in ipairs(MC.Controls) do
		if c.handled_by == "bind" or c.handled_by == "poll" then
			assert(MC.Actions[c.action], "client missing action " .. c.action)
		else
			assert(MS.Actions[c.action], "server missing action " .. c.action)
		end
	end
end)

test("generated tables match the sheets", function()
	eq(#MS.Blocks, 21, "blocks")
	for i = 1, 9 do assert(MS.DefaultHotbar[i], "hotbar slot " .. i) end
	eq(MS.Blocks[MS.BlockIds.tnt].special, "tnt")
	eq(MS.Blocks[MS.BlockIds.glass].cutout, true)
end)

print("World setup")
H.callHook(S, "InitPostEntity")
test("grid floor sits on the map floor under spawn", function()
	eq(MS.Origin().z, H.FLOOR)
	eq(MC.Origin().z, H.FLOOR, "client sees the same origin")
end)

H.callHook(S, "PlayerInitialSpawn", sply)
eq(H.callHook(S, "PlayerLoadout", sply), true)
test("loadout gives the Block Hand first and sets jump height", function()
	eq(sply.active:GetClass(), "mcc_hand")
	assert(sply:HasWeapon("weapon_physgun") and sply:HasWeapon("gmod_tool"))
	eq(sply.jump, MS.Cfg.jump_power)
	eq(sply.mccBlock, MS.DefaultHotbar[1])
end)
cply.weapons.mcc_hand = cply:Give("mcc_hand")
cply:SelectWeapon("mcc_hand")

local function lookAt(cell, ply)
	-- Stand back 3 blocks on -x and aim at the cell centre.
	local c = MS.CellCenter(cell[1], cell[2], cell[3])
	local eye = c + V(-3 * BS, 0, BS * 0.6)
	for _, p in ipairs({ sply, cply }) do
		p.eye = eye
		p.aim = (c - eye):GetNormalized()
	end
end
local function lookFromAbove(cell)
	local c = MS.CellCenter(cell[1], cell[2], cell[3])
	local eye = c + V(1, 1, 3 * BS)
	for _, p in ipairs({ sply, cply }) do
		p.eye = eye
		p.aim = (c - eye):GetNormalized()
	end
end
local function lookDownAtFloor(x, y, side)
	local target = MS.CellMins(x, y, 0) + V(BS / 2, BS / 2, 0)
	local eye = target + V((side or -1) * 2 * BS, 0, 2 * BS)
	for _, p in ipairs({ sply, cply }) do
		p.eye = eye
		p.aim = (target - eye):GetNormalized()
	end
end
local function serverTick() H.callHook(S, "Think") end
local function clientFrame() for _ = 1, 20 do H.callHook(C, "Think") end end
local function quads(key)
	local n = 0
	for _, p in ipairs(MC.ChunkMeshes[key] or {}) do n = n + p.mesh.quads end
	return n
end
local function chunkEnt(key) return MS.ChunkEnts[key] end
local function weaponPrimary() local w = sply.active; w.Owner = sply; w.GetOwner = function() return sply end; w:PrimaryAttack() end
local function weaponSecondary() local w = sply.active; w.GetOwner = function() return sply end; w:SecondaryAttack() end

print("Placing and breaking")
lookDownAtFloor(2, 0)
weaponSecondary()
serverTick()
clientFrame()
test("right click on the bare floor places the selected block at floor level", function()
	eq(MS.GetBlock(2, 0, 0), MS.DefaultHotbar[1])
	eq(MC.GetBlock(2, 0, 0), MS.DefaultHotbar[1], "client mirror")
	eq(quads("0,0,0"), 6, "one cube = 6 faces")
	eq(#chunkEnt("0,0,0").convexes, 1)
	assert(#H.notes("sound") > 0, "place sound")
end)

test("place sound comes from the Minecraft files at the sheet's pitch", function()
	local s = H.notes("sound")
	local last = s[#s]
	assert(last[2]:match("^mcc/dig/grass%d%.ogg$"), last[2])
	eq(last[3], 80)
end)

lookAt({ 2, 0, 0 })
-- aim at the top face from above instead
do
	local c = MS.CellCenter(2, 0, 0)
	local eye = c + V(-BS, 0, 2 * BS)
	for _, p in ipairs({ sply, cply }) do p.eye = eye; p.aim = (c + V(0, 0, BS / 2) - eye):GetNormalized() end
end
weaponSecondary()
serverTick() clientFrame()
test("placing on a block's top face stacks on it; collision merges into one box", function()
	eq(MS.GetBlock(2, 0, 1), MS.DefaultHotbar[1])
	eq(quads("0,0,0"), 10, "two stacked cubes = 10 visible faces")
	eq(#chunkEnt("0,0,0").convexes, 1, "1x1x2 column is one convex")
end)

test("a block cannot be placed inside the player", function()
	local before = MS.World.count
	sply.pos = MS.CellMins(5, 0, 0) + V(BS / 2, BS / 2, 0)
	lookDownAtFloor(5, 0)
	weaponSecondary()
	eq(MS.World.count, before)
	sply.pos = V(0, 0, H.FLOOR)
end)

-- glass next to the column
cply.weapons.mcc_hand = cply.active
H.callHook(C, "PlayerBindPress", cply, "slot7", true) -- glass is in hotbar slot 7
test("number key picks the hotbar slot and tells the server", function()
	eq(MC.Slot, 7)
	eq(sply.mccBlock, MS.BlockIds.glass)
end)
lookDownAtFloor(3, 0, 1) -- from the +x side so the grass column is not in the way
weaponSecondary()
serverTick() clientFrame()
test("faces next to see-through glass stay visible", function()
	eq(MS.GetBlock(3, 0, 0), MS.BlockIds.glass)
	-- grass column 10 faces (none hidden by glass) + glass cube 5 faces (its -x side touches grass)
	eq(quads("0,0,0"), 15)
end)

lookFromAbove({ 3, 0, 0 })
weaponPrimary()
serverTick() clientFrame()
test("left click breaks the targeted block", function()
	eq(MS.GetBlock(3, 0, 0), 0)
	eq(MC.GetBlock(3, 0, 0), 0)
	eq(quads("0,0,0"), 10)
end)

print("Chunk edges and negative coordinates")
test("cells map to chunks correctly on both sides of zero", function()
	local cx, cy, cz, lx, ly, lz = MS.CellToChunk(-1, 15, 16)
	eq(cx, -1) eq(lx, 15) eq(cy, 0) eq(ly, 15) eq(cz, 1) eq(lz, 0)
end)
test("a block at a chunk edge hides its neighbour chunk's face", function()
	MS.SetBlock(-1, 0, 0, MS.BlockIds.stone)
	MS.SetBlock(0, 0, 0, MS.BlockIds.stone)
	serverTick() clientFrame()
	eq(quads("-1,0,0"), 5)
	eq(quads("0,0,0"), 15) -- 10 grass + stone with its -x face hidden
	MS.SetBlock(-1, 0, 0, 0)
	serverTick() clientFrame()
	eq(quads("0,0,0"), 16, "face reappears after neighbour removed")
	eq(MS.ChunkEnts["-1,0,0"], nil, "empty chunk's collision entity removed")
	MS.SetBlock(0, 0, 0, 0)
	serverTick() clientFrame()
end)

test("raycast hits the near face and reports its normal", function()
	local start = MS.CellCenter(-5, 0, 1)
	local hit = MS.Raycast(start, V(1, 0, 0), 20 * BS)
	assert(hit, "no hit")
	eq(hit.x, 2) eq(hit.z, 1) eq(hit.nx, -1)
	eq(MS.Raycast(start, V(-1, 0, 0), 20 * BS), nil, "nothing behind")
	eq(MS.Raycast(start, V(1, 0, 0), 2 * BS), nil, "out of reach")
end)

test("greedy collision boxes cover exactly the filled cells", function()
	math.randomseed(7)
	local ch = { data = {}, count = 0 }
	local cs = MS.Cfg.chunk_size
	for i = 1, cs ^ 3 do if math.random() < 0.45 then ch.data[i] = 1 end end
	local cover = {}
	for _, b in ipairs(MS.ChunkBoxes(ch)) do
		for z = b[3], b[6] - 1 do for y = b[2], b[5] - 1 do for x = b[1], b[4] - 1 do
			local i = MS.LocalIndex(x, y, z)
			assert(not cover[i], "boxes overlap")
			cover[i] = true
		end end end
	end
	for i = 1, cs ^ 3 do eq(cover[i] == true, ch.data[i] ~= nil, "cell " .. i) end
	local full = { data = {} }
	for i = 1, cs ^ 3 do full.data[i] = 1 end
	eq(#MS.ChunkBoxes(full), 1, "full chunk is one box")
end)

test("a full chunk draws only its outer surface", function()
	for i = 1, 16 ^ 3 do
		local lx, ly, lz = MS.IndexToLocal(i)
		MS.SetBlock(lx, 16 + ly, lz, MS.BlockIds.stone, true)
	end
	serverTick()
	-- not networked per cell above; send it the way a joining player gets it
	MS.SendWorld(sply)
	clientFrame()
	eq(quads("0,1,0"), 6 * 256)
	eq(#chunkEnt("0,1,0").convexes, 1)
end)

print("Physics switch")
test("F turns the whole connected build into physics blocks", function()
	local before = #H.entities
	lookAt({ 2, 0, 1 })
	H.callHook(C, "PlayerBindPress", cply, "impulse 100", true)
	serverTick() clientFrame()
	eq(MS.GetBlock(2, 0, 0), 0) eq(MS.GetBlock(2, 0, 1), 0)
	eq(MC.GetBlock(2, 0, 1), 0, "client mirror")
	local props = 0
	for i = before + 1, #H.entities do
		local e = H.entities[i]
		if e.class == "mcc_block_prop" and e.valid then
			props = props + 1
			assert(e.phys and e.phys.awake, "prop physics awake")
			eq(e.phys.material, "dirt", "grass props get the grass group's surface")
		end
	end
	eq(props, 2)
	eq(quads("0,0,0"), 0)
end)

test("the physics switch stops at the cap", function()
	MS.Cfg.max_physics_blocks = 100
	for i = 1, 300 do MS.SetBlock(i, 40, 0, MS.BlockIds.stone, true) end
	local cells = MS.FloodFill(1, 40, 0, MS.Cfg.max_physics_blocks)
	eq(#cells, 100)
	eq(cells[1][1], 1, "nearest first")
	for i = 1, 300 do MS.SetBlock(i, 40, 0, 0, true) end
	MS.Cfg.max_physics_blocks = 256
	serverTick()
end)

print("TNT")
local tntCell = { 10, 0, 0 }
test("left click lights TNT; it explodes, blasting nearby blocks loose and lighting other TNT", function()
	for x = 8, 12 do MS.SetBlock(x, 0, 0, MS.BlockIds.stone) end
	MS.SetBlock(10, 0, 0, MS.BlockIds.tnt)
	MS.SetBlock(12, 0, 1, MS.BlockIds.tnt)
	MS.SetBlock(30, 0, 0, MS.BlockIds.stone) -- far away, must survive
	serverTick()
	lookFromAbove(tntCell)
	local before = #H.entities
	weaponPrimary()
	eq(MS.GetBlock(10, 0, 0), 0, "lit TNT leaves the grid")
	local tnt = H.entities[#H.entities]
	eq(tnt.class, "mcc_block_prop")
	assert(tnt:GetFuseEnd() > H.now, "fuse running")
	H.now = H.now + MS.Cfg.tnt_fuse + 0.1
	tnt:Think()
	assert(not tnt.valid, "TNT removed after exploding")
	eq(#H.notes("blast"), 1)
	for x = 8, 12 do eq(MS.GetBlock(x, 0, 0), 0, "blasted x=" .. x) end
	eq(MS.GetBlock(30, 0, 0), MS.BlockIds.stone, "far block survives")
	local flung, chained = 0, nil
	for i = before + 2, #H.entities do
		local e = H.entities[i]
		if e.class == "mcc_block_prop" then
			if e:GetBlockId() == MS.BlockIds.tnt then chained = e else flung = flung + 1 end
		end
	end
	eq(flung, 4)
	assert(chained and chained:GetFuseEnd() > H.now, "neighbouring TNT is lit with a short fuse")
	assert(chained:GetFuseEnd() - H.now <= MS.Cfg.tnt_chain_fuse_max)
	MS.SetBlock(30, 0, 0, 0)
end)

test("crouching breaks TNT without lighting it", function()
	MS.SetBlock(10, 0, 0, MS.BlockIds.tnt)
	serverTick()
	lookFromAbove(tntCell)
	local before = #H.entities
	sply.crouch = true
	weaponPrimary()
	sply.crouch = false
	eq(MS.GetBlock(10, 0, 0), 0)
	eq(#H.entities, before, "no TNT prop")
end)

test("shooting a TNT prop lights it", function()
	local e = MS.SpawnBlockProp(MS.BlockIds.tnt, 0, 10, 0, sply)
	e:OnTakeDamage({ IsExplosionDamage = function() return false end })
	assert(math.abs(e:GetFuseEnd() - (H.now + MS.Cfg.tnt_fuse)) < 1e-6)
end)

test("old loose props are removed past the cap", function()
	MS.Cfg.max_loose_props = 5
	local first = MS.SpawnBlockProp(1, 0, 50, 0, sply)
	for i = 1, 10 do MS.SpawnBlockProp(1, i, 50, 0, sply) end
	assert(not first.valid, "oldest removed")
	local alive = 0
	for _, p in ipairs(MS.LooseProps) do if p.valid then alive = alive + 1 end end
	eq(alive, 5)
	MS.Cfg.max_loose_props = 400
end)

print("Movement")
test("double-tapping jump toggles flying; a single tap does not", function()
	H.callHook(S, "KeyPress", sply, S.IN_JUMP)
	eq(sply:GetNW2Bool("mcc_fly"), false)
	H.now = H.now + 0.1
	H.callHook(S, "KeyPress", sply, S.IN_JUMP)
	eq(sply:GetNW2Bool("mcc_fly"), true)
	H.now = H.now + 1
	H.callHook(S, "KeyPress", sply, S.IN_JUMP)
	eq(sply:GetNW2Bool("mcc_fly"), true, "slow taps do nothing")
end)

local function moveData(keys, fwd)
	local mv = { origin = V(0, 0, H.FLOOR + 200), vel = V() }
	function mv:GetMoveAngles() return H.envs.server.Angle(0, 0, 0) end
	function mv:GetForwardSpeed() return fwd or 0 end
	function mv:GetSideSpeed() return 0 end
	function mv:KeyDown(k) return keys[k] or false end
	function mv:GetVelocity() return self.vel end
	function mv:SetVelocity(v) self.vel = v end
	function mv:GetOrigin() return self.origin end
	function mv:SetOrigin(v) self.origin = v end
	return mv
end

test("flying moves forward and up without gravity, replacing engine movement", function()
	sply.pos = V(0, 0, H.FLOOR + 200)
	local mv = moveData({ [S.IN_JUMP] = true }, 400)
	local z0 = mv.origin.z
	for _ = 1, 30 do eq(H.callHook(S, "Move", sply, mv), true) end
	assert(mv.origin.x > 50, "moved forward " .. mv.origin.x)
	assert(mv.origin.z > z0, "moved up")
	assert(mv.vel.x <= MS.Cfg.fly_speed + 1e-6, "capped at fly speed")
end)

test("flying down onto the floor lands and stops flying", function()
	local mv = moveData({ [S.IN_DUCK] = true })
	mv.origin = V(0, 0, H.FLOOR + 30)
	for _ = 1, 120 do H.callHook(S, "Move", sply, mv) end
	eq(sply:GetNW2Bool("mcc_fly"), false)
	assert(mv.origin.z >= H.FLOOR - 1e-6, "did not sink through the floor: " .. mv.origin.z)
	eq(H.callHook(S, "Move", sply, mv), nil, "engine movement back")
end)

test("footsteps on blocks use Minecraft step sounds", function()
	MS.SetBlock(0, 5, 0, MS.BlockIds.oak_planks)
	sply.pos = MS.CellMins(0, 5, 1) + V(BS / 2, BS / 2, 0)
	local r = H.callHook(S, "PlayerFootstep", sply)
	eq(r, true)
	local e = H.notes("emit")
	assert(e[#e][2]:match("^mcc/step/wood%d%.ogg$"), e[#e][2])
	sply.pos = V(0, 0, H.FLOOR)
	eq(H.callHook(S, "PlayerFootstep", sply), nil, "map floor keeps GMod footsteps")
end)

print("Client UI")
test("mouse wheel cycles the hotbar and wraps", function()
	MC.Slot = 9
	H.callHook(C, "PlayerBindPress", cply, "invnext", true)
	eq(MC.Slot, 1)
	H.callHook(C, "PlayerBindPress", cply, "invprev", true)
	eq(MC.Slot, 9)
end)

test("binds pass through when not holding the Block Hand", function()
	cply.active = cply:Give("weapon_physgun")
	sply:SelectWeapon("weapon_physgun")
	sply.mccNextAction = 0
	eq(H.callHook(C, "PlayerBindPress", cply, "slot3", true), nil)
	eq(H.callHook(C, "PlayerBindPress", cply, "+reload", true), nil, "R stays GMod's unfreeze on the physics gun")
	eq(H.callHook(C, "PlayerBindPress", cply, "slot1", true), true, "1 goes back to the Block Hand")
	cply.active = cply.weapons.mcc_hand
	eq(sply.active:GetClass(), "mcc_hand")
end)

test("R on the Block Hand switches to the physics gun", function()
	sply.mccNextAction = 0
	H.callHook(C, "PlayerBindPress", cply, "+reload", true)
	eq(sply.active:GetClass(), "weapon_physgun")
	sply:SelectWeapon("mcc_hand")
end)

test("middle click picks the targeted block into the hotbar", function()
	MS.SetBlock(2, 0, 0, MS.BlockIds.obsidian)
	clientFrame()
	lookAt({ 2, 0, 0 })
	MC.Slot = 4
	H.mouseMiddle = true
	H.callHook(C, "Think")
	H.mouseMiddle = false
	H.callHook(C, "Think")
	eq(MC.Hotbar[4], MS.BlockIds.obsidian)
	eq(sply.mccBlock, MS.BlockIds.obsidian)
end)

test("HUD, picker, outline, world and prop drawing run without errors", function()
	H.callHook(C, "HUDPaint")
	H.callHook(C, "PostDrawOpaqueRenderables", false, false)
	H.callHook(C, "PostDrawTranslucentRenderables", false, false)
	assert(#H.notes("wire") > 0, "outline drawn")
	eq(H.callHook(C, "HUDShouldDraw", "CHudCrosshair"), false)
	H.callHook(C, "PlayerBindPress", cply, "+use", true)
	local prop = C.ents.Create("mcc_block_prop")
	prop:SetBlockId(MS.BlockIds.tnt)
	prop:SetFuseEnd(H.now + 1)
	prop:Initialize()
	prop:Draw()
	local ch = C.ents.Create("mcc_chunk")
	ch:SetChunkX(0) ch:SetChunkY(0) ch:SetChunkZ(0)
	ch:Initialize()
	assert(ch.convexes and #ch.convexes > 0, "client chunk entity builds collision")
end)

test("missing Minecraft files fall back to plain colours and GMod sounds", function()
	local saved = H.files
	H.files = {}
	local C2 = H.boot("client")
	local M2 = C2.MCC
	eq(M2.HasMinecraftTextures(), false)
	local mat, real = M2.BlockMaterial("stone", false)
	eq(real, false)
	local path, mc = S.MCC.PickSound({ "dig/doesnotexist" }, "physics/concrete/concrete_break2.wav")
	eq(mc, false) eq(path, "physics/concrete/concrete_break2.wav")
	H.callHook(C2, "HUDPaint")
	H.files = saved
	H.envs.client = C
end)

print("Cleanup")
test("Sandbox clean-up clears every block on server and client", function()
	H.callHook(S, "PostCleanupMap")
	clientFrame()
	eq(MS.World.count, 0)
	eq(MC.World.count, 0)
	eq(next(MC.ChunkMeshes), nil)
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
