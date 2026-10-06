-- Minecraft Creative: client. Mirrors the block world and draws it as meshes, one per chunk and
-- texture. Textures are the player's own Minecraft PNGs (copied to materials/mcc/block/ by the
-- helper at launch); any that are missing are drawn in a flat colour from the blocks sheet.
MCC = MCC or {}
MCC.ChunkMeshes = MCC.ChunkMeshes or {}
MCC.DirtyCL = MCC.DirtyCL or {}
MCC.ChunkEntsCL = MCC.ChunkEntsCL or {}
MCC.Mats = MCC.Mats or {}

local floor = math.floor

-- Faces: neighbour direction, which texture, Minecraft's fixed per-face shading, and 4 corners
-- as { x, y, z, u, v } in block units (v = 0 is the top of the texture).
MCC.FACES = {
	{ n = { 0, 0, 1 }, tex = "top", shade = 1.0, v = { { 0, 0, 1, 0, 1 }, { 1, 0, 1, 1, 1 }, { 1, 1, 1, 1, 0 }, { 0, 1, 1, 0, 0 } } },
	{ n = { 0, 0, -1 }, tex = "bottom", shade = 0.5, v = { { 0, 1, 0, 0, 0 }, { 1, 1, 0, 1, 0 }, { 1, 0, 0, 1, 1 }, { 0, 0, 0, 0, 1 } } },
	{ n = { 1, 0, 0 }, tex = "side", shade = 0.6, v = { { 1, 0, 1, 0, 0 }, { 1, 1, 1, 1, 0 }, { 1, 1, 0, 1, 1 }, { 1, 0, 0, 0, 1 } } },
	{ n = { -1, 0, 0 }, tex = "side", shade = 0.6, v = { { 0, 1, 1, 0, 0 }, { 0, 0, 1, 1, 0 }, { 0, 0, 0, 1, 1 }, { 0, 1, 0, 0, 1 } } },
	{ n = { 0, 1, 0 }, tex = "side", shade = 0.8, v = { { 1, 1, 1, 0, 0 }, { 0, 1, 1, 1, 0 }, { 0, 1, 0, 1, 1 }, { 1, 1, 0, 0, 1 } } },
	{ n = { 0, -1, 0 }, tex = "side", shade = 0.8, v = { { 0, 0, 1, 0, 0 }, { 1, 0, 1, 1, 0 }, { 1, 0, 0, 1, 1 }, { 0, 0, 0, 0, 1 } } },
}

-- ---------------------------------------------------------------- materials
function MCC.TexturePath(tex)
	return "mcc/block/" .. tex .. ".png"
end

function MCC.HasTexture(tex)
	return file.Exists("materials/" .. MCC.TexturePath(tex), "GAME")
end

-- True when the helper has copied the player's Minecraft textures in.
function MCC.HasMinecraftTextures()
	if MCC.mcTexCheck == nil then
		MCC.mcTexCheck = MCC.HasTexture(MCC.Blocks[1].tex.side)
	end
	return MCC.mcTexCheck
end

-- Unlit, vertex-coloured, point-sampled material for one block texture. Returns mat, isMinecraft.
function MCC.BlockMaterial(tex, cutout)
	local key = tex .. (cutout and "_c" or "")
	local m = MCC.Mats[key]
	if m then return m.mat, m.real end
	local kv = { ["$basetexture"] = "color/white", ["$vertexcolor"] = "1", ["$nocull"] = "1" }
	if cutout then
		kv["$alphatest"] = "1"
		kv["$alphatestreference"] = "0.5"
	end
	local mat = CreateMaterial("mcc_" .. key, "UnlitGeneric", kv)
	local real = false
	if MCC.HasTexture(tex) then
		local png = Material(MCC.TexturePath(tex), "noclamp") -- no "smooth": keeps Minecraft's pixels sharp
		if png and not png:IsError() then
			mat:SetTexture("$basetexture", png:GetTexture("$basetexture"))
			real = true
		end
	end
	MCC.Mats[key] = { mat = mat, real = real }
	return mat, real
end

local function faceColor(b, side, shade, real)
	local r, g, bl = 255, 255, 255
	if not real then
		r, g, bl = b.fallback[1], b.fallback[2], b.fallback[3]
	elseif b.tint[side] then
		local t = b.tint[side]
		r, g, bl = t[1], t[2], t[3]
	end
	return floor(r * shade), floor(g * shade), floor(bl * shade)
end

-- ---------------------------------------------------------------- meshes
local function addQuad(buckets, b, f, ox, oy, oz)
	local tex = b.tex[f.tex]
	local key = tex .. (b.cutout and "_c" or "")
	local bk = buckets[key]
	if not bk then
		local mat, real = MCC.BlockMaterial(tex, b.cutout)
		bk = { mat = mat, real = real, quads = {} }
		buckets[key] = bk
	end
	local r, g, bl = faceColor(b, f.tex, f.shade, bk.real)
	bk.quads[#bk.quads + 1] = { ox, oy, oz, f, r, g, bl }
end

local MAX_QUADS = 8000 -- per IMesh; keeps each well under the vertex limit

-- buckets -> list of { mat, mesh }
function MCC.BucketsToMeshes(buckets, bs)
	local out = {}
	for _, bk in pairs(buckets) do
		local quads = bk.quads
		for first = 1, #quads, MAX_QUADS do
			local last = math.min(#quads, first + MAX_QUADS - 1)
			local m = Mesh()
			mesh.Begin(m, MATERIAL_QUADS, last - first + 1)
			for i = first, last do
				local q = quads[i]
				local ox, oy, oz, f, r, g, b = q[1], q[2], q[3], q[4], q[5], q[6], q[7]
				for _, v in ipairs(f.v) do
					mesh.Position(Vector(ox + v[1] * bs, oy + v[2] * bs, oz + v[3] * bs))
					mesh.TexCoord(0, v[4], v[5])
					mesh.Color(r, g, b, 255)
					mesh.AdvanceVertex()
				end
			end
			mesh.End()
			out[#out + 1] = { mat = bk.mat, mesh = m }
		end
	end
	return out
end

-- A face is drawn when the neighbour is air, or a different see-through block.
local function faceVisible(id, nid)
	if nid == 0 then return true end
	if nid == id then return false end
	local nb = MCC.Blocks[nid]
	return nb and nb.cutout or false
end

-- Returns buckets (exposed for tests) and the meshes for one chunk, in world coordinates.
function MCC.ChunkBuckets(ch)
	local cs, bs = MCC.Cfg.chunk_size, MCC.Cfg.block_size
	local o = MCC.Origin()
	local buckets = {}
	local bx, by, bz = ch.cx * cs, ch.cy * cs, ch.cz * cs
	for i, id in pairs(ch.data) do
		local b = MCC.Blocks[id]
		if b then
			local lx, ly, lz = MCC.IndexToLocal(i)
			local x, y, z = bx + lx, by + ly, bz + lz
			for _, f in ipairs(MCC.FACES) do
				if faceVisible(id, MCC.GetBlock(x + f.n[1], y + f.n[2], z + f.n[3])) then
					addQuad(buckets, b, f, o.x + x * bs, o.y + y * bs, o.z + z * bs)
				end
			end
		end
	end
	return buckets
end

local function destroyMeshes(list)
	if not list then return end
	for _, p in ipairs(list) do
		if p.mesh then p.mesh:Destroy() end
	end
end

function MCC.RebuildClientChunk(key)
	destroyMeshes(MCC.ChunkMeshes[key])
	MCC.ChunkMeshes[key] = nil
	local ch = MCC.World.chunks[key]
	if ch then
		MCC.ChunkMeshes[key] = MCC.BucketsToMeshes(MCC.ChunkBuckets(ch), MCC.Cfg.block_size)
		local ent = MCC.ChunkEntsCL[key]
		if IsValid(ent) then ent:BuildCollision(ch) end
	end
end

-- Whole-cube meshes for one block id, centred on 0,0,0 (used by physics block props).
MCC.CubeMeshes = MCC.CubeMeshes or {}
function MCC.GetCubeMeshes(id)
	local m = MCC.CubeMeshes[id]
	if m then return m end
	local b = MCC.Blocks[id]
	if not b then return nil end
	local bs = MCC.Cfg.block_size
	local buckets = {}
	for _, f in ipairs(MCC.FACES) do addQuad(buckets, b, f, -bs / 2, -bs / 2, -bs / 2) end
	m = MCC.BucketsToMeshes(buckets, bs)
	MCC.CubeMeshes[id] = m
	return m
end

function MCC.FlashParts()
	if MCC.flashParts then return MCC.flashParts end
	local bs = MCC.Cfg.block_size
	local mat = CreateMaterial("mcc_flash", "UnlitGeneric", { ["$basetexture"] = "color/white",
		["$vertexcolor"] = "1", ["$vertexalpha"] = "1", ["$translucent"] = "1", ["$nocull"] = "1" })
	local bk = { mat = mat, quads = {} }
	local h = bs / 2 + 0.2
	for _, f in ipairs(MCC.FACES) do bk.quads[#bk.quads + 1] = { -h, -h, -h, f, 255, 255, 255 } end
	MCC.flashParts = MCC.BucketsToMeshes({ bk }, bs + 0.4)
	return MCC.flashParts
end

function MCC.DrawBlockProp(ent)
	local parts = MCC.GetCubeMeshes(ent:GetBlockId())
	if not parts then return end
	cam.PushModelMatrix(ent:GetWorldTransformMatrix())
	for _, p in ipairs(parts) do
		render.SetMaterial(p.mat)
		p.mesh:Draw()
	end
	local fuse = ent:GetFuseEnd()
	if fuse > 0 and (CurTime() * 4) % 1 < 0.5 then
		render.SetBlend(0.6)
		for _, p in ipairs(MCC.FlashParts()) do
			render.SetMaterial(p.mat)
			p.mesh:Draw()
		end
		render.SetBlend(1)
	end
	cam.PopModelMatrix()
end

function MCC.DrawWorld(depth, skybox)
	if depth or skybox then return end
	for _, list in pairs(MCC.ChunkMeshes) do
		for _, p in ipairs(list) do
			render.SetMaterial(p.mat)
			p.mesh:Draw()
		end
	end
end

-- ---------------------------------------------------------------- network
local function markChunk(cx, cy, cz)
	MCC.DirtyCL[MCC.ChunkKey(cx, cy, cz)] = true
end

-- A changed cell on a chunk edge also changes which faces its neighbour chunk shows.
function MCC.MarkDirtyAround(x, y, z)
	local cs = MCC.Cfg.chunk_size
	local cx, cy, cz, lx, ly, lz = MCC.CellToChunk(x, y, z)
	markChunk(cx, cy, cz)
	if lx == 0 then markChunk(cx - 1, cy, cz) elseif lx == cs - 1 then markChunk(cx + 1, cy, cz) end
	if ly == 0 then markChunk(cx, cy - 1, cz) elseif ly == cs - 1 then markChunk(cx, cy + 1, cz) end
	if lz == 0 then markChunk(cx, cy, cz - 1) elseif lz == cs - 1 then markChunk(cx, cy, cz + 1) end
end

function MCC.ClientSet(x, y, z, id)
	MCC.SetBlockRaw(x, y, z, id)
	MCC.MarkDirtyAround(x, y, z)
end

local function readCell()
	return net.ReadInt(32), net.ReadInt(32), net.ReadInt(32), net.ReadUInt(8)
end

net.Receive("mcc_set", function()
	MCC.ClientSet(readCell())
end)

net.Receive("mcc_bulk", function()
	for _ = 1, net.ReadUInt(16) do MCC.ClientSet(readCell()) end
end)

net.Receive("mcc_chunk", function()
	local cx, cy, cz = net.ReadInt(32), net.ReadInt(32), net.ReadInt(32)
	local s = util.Decompress(net.ReadData(net.ReadUInt(16)))
	if not s then return end
	MCC.LoadChunkString(cx, cy, cz, s)
	markChunk(cx, cy, cz)
	markChunk(cx - 1, cy, cz) markChunk(cx + 1, cy, cz)
	markChunk(cx, cy - 1, cz) markChunk(cx, cy + 1, cz)
	markChunk(cx, cy, cz - 1) markChunk(cx, cy, cz + 1)
end)

net.Receive("mcc_reset", function()
	for key, list in pairs(MCC.ChunkMeshes) do destroyMeshes(list) end
	MCC.ChunkMeshes = {}
	MCC.DirtyCL = {}
	MCC.ResetWorldData()
end)

function MCC.ProcessDirty()
	local n = 0
	for key in pairs(MCC.DirtyCL) do
		MCC.DirtyCL[key] = nil
		MCC.RebuildClientChunk(key)
		n = n + 1
		if n >= MCC.Cfg.mesh_rebuilds_per_frame then break end
	end
end
