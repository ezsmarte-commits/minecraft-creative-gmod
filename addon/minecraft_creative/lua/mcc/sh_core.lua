-- Minecraft Creative: the block world, shared by server and client.
-- The server's copy is authoritative; clients keep a mirror updated over the network.
MCC = MCC or {}
MCC.Actions = MCC.Actions or {}
MCC.World = MCC.World or { chunks = {}, count = 0 }

local floor = math.floor

local function CS() return MCC.Cfg.chunk_size end
local function BS() return MCC.Cfg.block_size end

-- ---------------------------------------------------------------- grid
function MCC.Origin()
	return GetGlobalVector("mcc_origin", vector_origin)
end

function MCC.ChunkKey(cx, cy, cz)
	return cx .. "," .. cy .. "," .. cz
end

-- Block cell -> chunk coords + coords inside the chunk (0..chunk_size-1).
function MCC.CellToChunk(x, y, z)
	local cs = CS()
	local cx, cy, cz = floor(x / cs), floor(y / cs), floor(z / cs)
	return cx, cy, cz, x - cx * cs, y - cy * cs, z - cz * cs
end

function MCC.LocalIndex(lx, ly, lz)
	local cs = CS()
	return lx + ly * cs + lz * cs * cs + 1
end

function MCC.IndexToLocal(i)
	local cs = CS()
	local li = i - 1
	return li % cs, floor(li / cs) % cs, floor(li / (cs * cs))
end

function MCC.CellMins(x, y, z)
	local o, bs = MCC.Origin(), BS()
	return Vector(o.x + x * bs, o.y + y * bs, o.z + z * bs)
end

function MCC.CellCenter(x, y, z)
	local o, bs = MCC.Origin(), BS()
	return Vector(o.x + (x + 0.5) * bs, o.y + (y + 0.5) * bs, o.z + (z + 0.5) * bs)
end

function MCC.PosToCell(pos)
	local o, bs = MCC.Origin(), BS()
	return floor((pos.x - o.x) / bs), floor((pos.y - o.y) / bs), floor((pos.z - o.z) / bs)
end

-- ---------------------------------------------------------------- storage
function MCC.ResetWorldData()
	MCC.World = { chunks = {}, count = 0 }
end

function MCC.GetChunk(cx, cy, cz)
	return MCC.World.chunks[MCC.ChunkKey(cx, cy, cz)]
end

function MCC.GetBlock(x, y, z)
	local cx, cy, cz, lx, ly, lz = MCC.CellToChunk(x, y, z)
	local ch = MCC.World.chunks[MCC.ChunkKey(cx, cy, cz)]
	if not ch then return 0 end
	return ch.data[MCC.LocalIndex(lx, ly, lz)] or 0
end

-- Sets one cell with no networking. Returns the chunk table (nil if none) and the previous id.
-- An emptied chunk is dropped from the world and flagged removed.
function MCC.SetBlockRaw(x, y, z, id)
	local cx, cy, cz, lx, ly, lz = MCC.CellToChunk(x, y, z)
	local key = MCC.ChunkKey(cx, cy, cz)
	local w = MCC.World
	local ch = w.chunks[key]
	if not ch then
		if id == 0 then return nil, 0 end
		ch = { key = key, cx = cx, cy = cy, cz = cz, data = {}, count = 0 }
		w.chunks[key] = ch
	end
	local i = MCC.LocalIndex(lx, ly, lz)
	local old = ch.data[i] or 0
	if old == id then return ch, old end
	if id == 0 then
		ch.data[i] = nil
		ch.count = ch.count - 1
		w.count = w.count - 1
	else
		ch.data[i] = id
		if old == 0 then
			ch.count = ch.count + 1
			w.count = w.count + 1
		end
	end
	if ch.count <= 0 then
		w.chunks[key] = nil
		ch.removed = true
	end
	return ch, old
end

-- One byte per cell, chunk_size^3 bytes.
function MCC.SerializeChunk(ch)
	local cs = CS()
	local t, data, char = {}, ch.data, string.char
	for i = 1, cs * cs * cs do
		t[i] = char(data[i] or 0)
	end
	return table.concat(t)
end

function MCC.LoadChunkString(cx, cy, cz, s)
	local key = MCC.ChunkKey(cx, cy, cz)
	local w = MCC.World
	local old = w.chunks[key]
	if old then
		w.count = w.count - old.count
		w.chunks[key] = nil
		old.removed = true
	end
	local ch = { key = key, cx = cx, cy = cy, cz = cz, data = {}, count = 0 }
	local byte = string.byte
	for i = 1, #s do
		local b = byte(s, i)
		if b ~= 0 and MCC.Blocks[b] then
			ch.data[i] = b
			ch.count = ch.count + 1
		end
	end
	if ch.count > 0 then
		w.chunks[key] = ch
		w.count = w.count + ch.count
		return ch
	end
	return nil
end

-- ---------------------------------------------------------------- raycast
-- Voxel walk (Amanatides & Woo) from start along unit dir, up to maxDist source units.
-- Returns { x, y, z, nx, ny, nz, dist, id } for the first filled cell, or nil.
function MCC.Raycast(start, dir, maxDist)
	if MCC.World.count == 0 then return nil end
	local o, bs = MCC.Origin(), BS()
	local px, py, pz = (start.x - o.x) / bs, (start.y - o.y) / bs, (start.z - o.z) / bs
	local dx, dy, dz = dir.x, dir.y, dir.z
	local x, y, z = floor(px), floor(py), floor(pz)
	local huge = math.huge

	local id = MCC.GetBlock(x, y, z)
	if id ~= 0 then
		return { x = x, y = y, z = z, nx = 0, ny = 0, nz = 0, dist = 0, id = id }
	end

	local sx = dx > 0 and 1 or -1
	local sy = dy > 0 and 1 or -1
	local sz = dz > 0 and 1 or -1
	local tdx = dx ~= 0 and math.abs(1 / dx) or huge
	local tdy = dy ~= 0 and math.abs(1 / dy) or huge
	local tdz = dz ~= 0 and math.abs(1 / dz) or huge
	local tmx = dx > 0 and (x + 1 - px) * tdx or (dx < 0 and (px - x) * tdx or huge)
	local tmy = dy > 0 and (y + 1 - py) * tdy or (dy < 0 and (py - y) * tdy or huge)
	local tmz = dz > 0 and (z + 1 - pz) * tdz or (dz < 0 and (pz - z) * tdz or huge)
	local maxT = maxDist / bs
	local nx, ny, nz, t = 0, 0, 0, 0

	for _ = 1, 4096 do
		if tmx < tmy and tmx < tmz then
			x = x + sx; t = tmx; tmx = tmx + tdx; nx, ny, nz = -sx, 0, 0
		elseif tmy < tmz then
			y = y + sy; t = tmy; tmy = tmy + tdy; nx, ny, nz = 0, -sy, 0
		else
			z = z + sz; t = tmz; tmz = tmz + tdz; nx, ny, nz = 0, 0, -sz
		end
		if t > maxT then return nil end
		id = MCC.GetBlock(x, y, z)
		if id ~= 0 then
			return { x = x, y = y, z = z, nx = nx, ny = ny, nz = nz, dist = t * bs, id = id }
		end
	end
	return nil
end

-- What the player is aiming at within reach.
--   kind "block": a block cell (x,y,z,id) and the empty cell in front of the hit face (px,py,pz)
--   kind "world": a map surface; (px,py,pz) is the cell a block would go in
function MCC.GetTarget(ply)
	local start = ply:EyePos()
	local dir = ply:GetAimVector()
	local reach = MCC.Cfg.reach_blocks * BS()
	local tr = util.TraceLine({ start = start, endpos = start + dir * reach, mask = MASK_SOLID_BRUSHONLY })
	local brushDist = tr.Hit and (tr.Fraction * reach) or reach
	local hit = MCC.Raycast(start, dir, brushDist)
	if hit then
		hit.kind = "block"
		hit.px, hit.py, hit.pz = hit.x + hit.nx, hit.y + hit.ny, hit.z + hit.nz
		return hit
	end
	if tr.Hit and not tr.HitSky then
		local x, y, z = MCC.PosToCell(tr.HitPos + tr.HitNormal * (BS() * 0.5))
		return { kind = "world", px = x, py = y, pz = z, dist = brushDist }
	end
	return nil
end

-- ---------------------------------------------------------------- collision boxes
-- Greedy-merges a chunk's filled cells into as few boxes as possible.
-- Each box is { x0, y0, z0, x1, y1, z1 } in local cell units, max exclusive.
function MCC.ChunkBoxes(ch)
	local cs = CS()
	local cs2 = cs * cs
	local data, used, boxes = ch.data, {}, {}
	local function free(x, y, z)
		local i = x + y * cs + z * cs2 + 1
		return data[i] ~= nil and not used[i]
	end
	for z = 0, cs - 1 do
		for y = 0, cs - 1 do
			for x = 0, cs - 1 do
				if free(x, y, z) then
					local x1 = x
					while x1 + 1 < cs and free(x1 + 1, y, z) do x1 = x1 + 1 end
					local y1 = y
					while y1 + 1 < cs do
						local ok = true
						for xx = x, x1 do
							if not free(xx, y1 + 1, z) then ok = false break end
						end
						if not ok then break end
						y1 = y1 + 1
					end
					local z1 = z
					while z1 + 1 < cs do
						local ok = true
						for yy = y, y1 do
							for xx = x, x1 do
								if not free(xx, yy, z1 + 1) then ok = false break end
							end
							if not ok then break end
						end
						if not ok then break end
						z1 = z1 + 1
					end
					for zz = z, z1 do
						for yy = y, y1 do
							for xx = x, x1 do used[xx + yy * cs + zz * cs2 + 1] = true end
						end
					end
					boxes[#boxes + 1] = { x, y, z, x1 + 1, y1 + 1, z1 + 1 }
				end
			end
		end
	end
	return boxes
end

-- Convex hulls (8 corners, local to the chunk entity) for PhysicsInitMultiConvex.
function MCC.ChunkConvexes(ch)
	local bs = BS()
	local out = {}
	for _, b in ipairs(MCC.ChunkBoxes(ch)) do
		local x0, y0, z0 = b[1] * bs, b[2] * bs, b[3] * bs
		local x1, y1, z1 = b[4] * bs, b[5] * bs, b[6] * bs
		out[#out + 1] = {
			Vector(x0, y0, z0), Vector(x1, y0, z0), Vector(x0, y1, z0), Vector(x1, y1, z0),
			Vector(x0, y0, z1), Vector(x1, y0, z1), Vector(x0, y1, z1), Vector(x1, y1, z1),
		}
	end
	return out
end

-- Connected filled cells from a start cell (6-neighbour), nearest first, at most max.
-- Returns a list of { x, y, z, id }.
function MCC.FloodFill(x, y, z, max)
	local out = {}
	if MCC.GetBlock(x, y, z) == 0 then return out end
	local seen = { [x .. "," .. y .. "," .. z] = true }
	local q, head = { { x, y, z } }, 1
	local dirs = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }
	while head <= #q and #out < max do
		local c = q[head]
		head = head + 1
		out[#out + 1] = { c[1], c[2], c[3], MCC.GetBlock(c[1], c[2], c[3]) }
		for _, d in ipairs(dirs) do
			local nx, ny, nz = c[1] + d[1], c[2] + d[2], c[3] + d[3]
			local k = nx .. "," .. ny .. "," .. nz
			if not seen[k] and MCC.GetBlock(nx, ny, nz) ~= 0 then
				seen[k] = true
				q[#q + 1] = { nx, ny, nz }
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------- protection
local function isChunk(ent)
	return IsValid(ent) and ent:GetClass() == "mcc_chunk"
end

function MCC.BlockChunkPickup(ply, ent)
	if isChunk(ent) then return false end
end

function MCC.BlockChunkTool(ply, tr)
	if tr and isChunk(tr.Entity) then return false end
end

function MCC.BlockChunkProperty(ply, property, ent)
	if isChunk(ent) then return false end
end

function MCC.IsHoldingHand(ply)
	if not IsValid(ply) then return false end
	local w = ply:GetActiveWeapon()
	return IsValid(w) and w:GetClass() == "mcc_hand"
end
