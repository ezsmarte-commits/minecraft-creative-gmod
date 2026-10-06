-- A small stand-in for Garry's Mod, enough to load the mod's real Lua into a simulated
-- server and client (separate environments, like GMod's two Lua states) joined by a fake
-- network. It cannot replace testing in the game: rendering, physics and the engine's
-- own behaviour are stubs. It catches logic errors, nil calls and wrong data flow.
local H = {}
local ROOT = arg and arg[0]:match("^(.*)/tests/") or "."
H.ADDON = ROOT .. "/addon/minecraft_creative"
H.FLOOR = -12800
H.now = 100
H.globals = {}
H.log = {}

local function note(kind, ...) H.log[#H.log + 1] = { kind, ... } end

-- ---------------------------------------------------------------- Vector / Angle
local VM = {}
VM.__index = VM
local function Vector(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, VM) end
VM.__add = function(a, b) return Vector(a.x + b.x, a.y + b.y, a.z + b.z) end
VM.__sub = function(a, b) return Vector(a.x - b.x, a.y - b.y, a.z - b.z) end
VM.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	return Vector(a.x * b, a.y * b, a.z * b)
end
VM.__div = function(a, b) return Vector(a.x / b, a.y / b, a.z / b) end
VM.__unm = function(a) return Vector(-a.x, -a.y, -a.z) end
VM.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
VM.__tostring = function(a) return string.format("Vector(%g,%g,%g)", a.x, a.y, a.z) end
function VM:Length() return math.sqrt(self.x ^ 2 + self.y ^ 2 + self.z ^ 2) end
function VM:LengthSqr() return self.x ^ 2 + self.y ^ 2 + self.z ^ 2 end
function VM:Dot(b) return self.x * b.x + self.y * b.y + self.z * b.z end
function VM:GetNormalized() local l = self:Length() if l == 0 then return Vector() end return self / l end
H.Vector = Vector

local AM = {}
AM.__index = AM
local function Angle(p, y, r) return setmetatable({ p = p or 0, y = y or 0, r = r or 0 }, AM) end
function AM:Forward()
	local p, y = math.rad(self.p), math.rad(self.y)
	return Vector(math.cos(p) * math.cos(y), math.cos(p) * math.sin(y), -math.sin(p))
end
function AM:Right()
	local y = math.rad(self.y)
	return Vector(math.sin(y), -math.cos(y), 0)
end

-- ---------------------------------------------------------------- fake world (flat floor)
local function traceFloor(start, endpos)
	local fz = H.FLOOR
	if start.z >= fz and endpos.z < fz then
		local f = (start.z - fz) / (start.z - endpos.z)
		return { Hit = true, HitSky = false, Fraction = f, HitPos = start + (endpos - start) * f,
			HitNormal = Vector(0, 0, 1), StartSolid = false }
	end
	return { Hit = false, HitSky = false, Fraction = 1, HitPos = endpos, HitNormal = Vector(), StartSolid = false }
end

-- ---------------------------------------------------------------- entities
H.entities = {}
local nextIdx = 1

local BaseEnt = {}
local function newEnt(class, envName, def)
	local e = { class = class, pos = Vector(), ang = Angle(), nw = {}, dt = {}, valid = true, env = envName,
		idx = nextIdx, physics = nil, removed = false }
	nextIdx = nextIdx + 1
	return setmetatable(e, { __index = function(t, k)
		if def and def[k] ~= nil then return def[k] end
		return BaseEnt[k]
	end })
end
function BaseEnt:IsValid() return self.valid end
function BaseEnt:GetClass() return self.class end
function BaseEnt:SetPos(p) self.pos = p end
function BaseEnt:GetPos() return self.pos end
function BaseEnt:WorldSpaceCenter() return self.pos end
function BaseEnt:SetAngles(a) self.ang = a end
function BaseEnt:Spawn() if self.Initialize then self:Initialize() end end
function BaseEnt:Activate() end
function BaseEnt:Remove()
	self.valid = false
	if self.OnRemove then self:OnRemove() end
end
function BaseEnt:SetModel(m) self.model = m end
function BaseEnt:SetNextPrimaryFire(t) self.nextPrimary = t end
function BaseEnt:SetNextSecondaryFire(t) self.nextSecondary = t end
function BaseEnt:DrawShadow() end
function BaseEnt:EnableCustomCollisions() end
function BaseEnt:SetSolid(s) self.solid = s end
function BaseEnt:SetMoveType(m) self.movetype = m end
function BaseEnt:SetCollisionBounds() end
function BaseEnt:SetRenderBounds() end
function BaseEnt:NextThink() end
function BaseEnt:IsNPC() return false end
function BaseEnt:IsVehicle() return false end
function BaseEnt:IsPlayer() return false end
function BaseEnt:TakePhysicsDamage() end
function BaseEnt:GetWorldTransformMatrix() return {} end
function BaseEnt:PhysicsInitMultiConvex(c) self.convexes = c; self.phys = H.newPhys() end
function BaseEnt:PhysicsInitBox(mins, maxs) self.box = { mins, maxs }; self.phys = H.newPhys() end
function BaseEnt:GetPhysicsObject() return self.phys or H.newPhys(true) end
function BaseEnt:NetworkVar(kind, slot, name)
	self["Set" .. name] = function(s, v) s.dt[name] = v end
	self["Get" .. name] = function(s) return s.dt[name] or (kind == "Float" and 0 or 0) end
end

function H.newPhys(invalid)
	local p = { valid = not invalid }
	function p:IsValid() return self.valid end
	function p:SetMass(m) self.mass = m end
	function p:SetMaterial(m) self.material = m end
	function p:Wake() self.awake = true end
	function p:EnableMotion(b) self.motion = b end
	function p:SetVelocity(v) self.vel = v end
	function p:AddAngleVelocity() end
	return p
end

-- ---------------------------------------------------------------- players
function H.newPlayer(env)
	local p = newEnt("player", env.name)
	p.weapons = {}
	p.active = nil
	p.chat = {}
	p.eye = Vector(0, 0, H.FLOOR + 64)
	p.aim = Vector(1, 0, 0)
	p.pos = Vector(0, 0, H.FLOOR)
	function p:IsPlayer() return true end
	function p:Alive() return true end
	function p:InVehicle() return false end
	function p:EyePos() return self.eye end
	function p:GetAimVector() return self.aim end
	function p:Crouching() return self.crouch or false end
	function p:OBBMins() return Vector(-16, -16, 0) end
	function p:OBBMaxs() return Vector(16, 16, 72) end
	function p:ChatPrint(s) self.chat[#self.chat + 1] = s end
	function p:Give(c)
		local w = newEnt(c, env.name, H.entdefs[env.name][c])
		w.owner = self
		w.GetOwner = function() return self end
		if w.Initialize then w.SetHoldType = function() end w:Initialize() end
		self.weapons[c] = w
		return w
	end
	function p:HasWeapon(c) return self.weapons[c] ~= nil end
	function p:SelectWeapon(c) self.active = self.weapons[c] end
	function p:GetActiveWeapon() return self.active or setmetatable({}, { __index = { IsValid = function() return false end } }) end
	function p:SetJumpPower(j) self.jump = j end
	function p:SetNW2Bool(k, v) self.nw[k] = v end
	function p:GetNW2Bool(k) return self.nw[k] or false end
	function p:GetMoveType() return self.movetype or 2 end
	function p:EmitSound(s) note("emit", s) end
	return p
end

-- ---------------------------------------------------------------- environment builder
local function deepcopy(t, seen)
	if type(t) ~= "table" then return t end
	seen = seen or {}
	if seen[t] then return seen[t] end
	local o = {}
	seen[t] = o
	for k, v in pairs(t) do o[deepcopy(k, seen)] = deepcopy(v, seen) end
	return setmetatable(o, getmetatable(t))
end

H.envs = {}

function H.makeEnv(realm)
	local env = { name = realm }
	env._G = env
	setmetatable(env, { __index = _G })
	env.SERVER = realm == "server"
	env.CLIENT = realm == "client"
	env.Vector, env.Angle = Vector, Angle
	env.vector_origin = Vector(0, 0, 0)
	env.angle_zero = Angle()
	env.color_white = { r = 255, g = 255, b = 255, a = 255 }
	env.Color = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
	env.MOVETYPE_WALK, env.MOVETYPE_NONE, env.MOVETYPE_VPHYSICS, env.MOVETYPE_NOCLIP = 2, 0, 6, 8
	env.SOLID_VPHYSICS = 6
	env.MASK_SOLID_BRUSHONLY, env.MASK_PLAYERSOLID, env.CONTENTS_SOLID = 1, 2, 1
	env.IN_JUMP, env.IN_DUCK, env.IN_SPEED = 2, 4, 131072
	env.MATERIAL_QUADS = 4
	env.TRANSMIT_ALWAYS = 0
	env.MOUSE_MIDDLE, env.KEY_E = 109, 15
	env.TEXT_ALIGN_LEFT, env.TEXT_ALIGN_CENTER, env.TEXT_ALIGN_TOP, env.TEXT_ALIGN_BOTTOM = 0, 1, 3, 4
	env.bit = require("bit")
	env.IsValid = function(o) return o ~= nil and type(o) == "table" and o.IsValid ~= nil and o:IsValid() end
	env.CurTime = function() return H.now end
	env.FrameTime = function() return 1 / 66 end
	env.GetGlobalVector = function(k, d) return H.globals[k] or d end
	env.SetGlobalVector = function(k, v) H.globals[k] = v end
	env.VectorRand = function() return Vector(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) end
	env.EffectData = function()
		local d = {}
		function d:SetOrigin(v) self.origin = v end
		function d:SetMagnitude() end
		function d:SetScale() end
		return d
	end
	env.math = setmetatable({ Rand = function(a, b) return a + (b - a) * math.random() end }, { __index = math })
	env.string = setmetatable({ Trim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end }, { __index = string })
	env.table = setmetatable({ Copy = function(t) return deepcopy(t) end }, { __index = table })
	env.util = {
		TraceLine = function(t) return traceFloor(t.start, t.endpos) end,
		TraceHull = function(t)
			-- floor only, using the hull's lowest point
			local s, e = t.start + Vector(0, 0, t.mins.z), t.endpos + Vector(0, 0, t.mins.z)
			local r = traceFloor(s, e)
			if r.Hit then r.HitPos = r.HitPos - Vector(0, 0, t.mins.z) end
			return r
		end,
		PointContents = function(p) return p.z < H.FLOOR and 1 or 0 end,
		Compress = function(s) return "Z" .. s end,
		Decompress = function(s) return s:sub(2) end,
		AddNetworkString = function() end,
		Effect = function(name) note("effect", name) end,
		BlastDamage = function(_, _, pos, r, d) note("blast", pos, r, d) end,
	}
	env.sound = { Play = function(path, pos, lvl, pitch) note("sound", path, pitch) end }
	env.file = { Exists = function(p) return H.files[p] == true end }
	env.timer = { Simple = function(_, f) f() end }
	env.cleanup = { Add = function() end }
	env.game = { GetWorld = function() return newEnt("worldspawn", realm) end }
	env.player = { GetAll = function() return H.players[realm] or {} end }
	env.include = function(path) return H.include(env, path) end
	env.AddCSLuaFile = function() end
	env.DeriveGamemode = function() end
	env.GM = {}
	env.hooks = {}
	env.hook = { Add = function(name, id, fn)
		env.hooks[name] = env.hooks[name] or {}
		env.hooks[name][id] = fn
	end }
	env.ents = {
		Create = function(class)
			local def = H.entdefs[realm][class]
			if not def then return nil end
			local e = newEnt(class, realm, def)
			e:SetupDataTables()
			H.entities[#H.entities + 1] = e
			return e
		end,
		FindByClass = function(c)
			if c == "info_player_start" then
				local s = newEnt(c, realm)
				s.pos = Vector(0, 0, H.FLOOR + 1)
				return { s }
			end
			return {}
		end,
		FindInBox = function() return {} end,
	}
	-- networking
	env.netrecv = {}
	local out
	local inq, inpos
	env.net = {
		Start = function(name) out = { name = name, vals = {} } end,
		WriteInt = function(v) out.vals[#out.vals + 1] = v end,
		WriteUInt = function(v, bits) assert(v >= 0 and v < 2 ^ bits, "uint overflow") out.vals[#out.vals + 1] = v end,
		WriteString = function(v) out.vals[#out.vals + 1] = v end,
		WriteData = function(v, n) assert(#v == n) out.vals[#out.vals + 1] = v end,
		Broadcast = function() H.deliver(realm, out, nil) end,
		Send = function(ply) H.deliver(realm, out, ply) end,
		SendToServer = function() H.deliver(realm, out, nil) end,
		Receive = function(name, fn) env.netrecv[name] = fn end,
		ReadInt = function() inpos = inpos + 1 return inq[inpos] end,
		ReadUInt = function() inpos = inpos + 1 return inq[inpos] end,
		ReadString = function() inpos = inpos + 1 return inq[inpos] end,
		ReadData = function() inpos = inpos + 1 return inq[inpos] end,
	}
	env._netIn = function(msg, from)
		local fn = env.netrecv[msg.name]
		assert(fn, realm .. " has no receiver for " .. msg.name)
		inq, inpos = msg.vals, 0
		fn(#msg.vals, from)
		assert(inpos == #msg.vals, msg.name .. ": read " .. inpos .. " of " .. #msg.vals .. " values")
	end
	if realm == "client" then
		env.LocalPlayer = function() return H.clientPlayer end
		env.Mesh = function()
			local m = { quads = 0, verts = 0 }
			function m:Destroy() self.destroyed = true end
			function m:Draw() H.draws = (H.draws or 0) + 1 end
			return m
		end
		local cur
		env.mesh = {
			Begin = function(m, _, n) cur = m; m.quads = n end,
			Position = function() cur.verts = cur.verts + 1 end,
			TexCoord = function() end,
			Color = function(r, g, b, a)
				assert(r == math.floor(r) and r >= 0 and r <= 255, "bad colour " .. tostring(r))
			end,
			AdvanceVertex = function() end,
			End = function() assert(cur.verts == cur.quads * 4, "mesh vertex count mismatch") cur = nil end,
		}
		local function mat(name)
			return { name = name, IsError = function() return false end, GetTexture = function() return "tex:" .. name end,
				SetTexture = function(self, k, v) self.base = v end }
		end
		env.CreateMaterial = function(name) return mat(name) end
		env.Material = function(name) return mat(name) end
		env.render = { SetMaterial = function() end, DrawWireframeBox = function() note("wire") end, SetBlend = function() end }
		env.cam = { PushModelMatrix = function() end, PopModelMatrix = function() end }
		env.surface = setmetatable({ GetTextSize = function() return 100, 10 end }, { __index = function() return function() end end })
		env.draw = setmetatable({}, { __index = function() return function() end end })
		env.ScrW, env.ScrH = function() return 1920 end, function() return 1080 end
		env.input = { IsMouseDown = function(b) return H.mouseMiddle or false end }
		env.vgui = { CursorVisible = function() return false end, Create = function()
			local p = setmetatable({}, { __index = function(t, k) return function() return t end end })
			p.Add = function() return setmetatable({}, { __index = function() return function() end end }) end
			return p
		end }
	end
	H.envs[realm] = env
	return env
end

H.players = {}
H.files = {}
H.entdefs = { server = {}, client = {} }

function H.deliver(from, msg, ply)
	local to = from == "server" and H.envs.client or H.envs.server
	if to then to._netIn(msg, from == "client" and H.clientServerPlayer or nil) end
end

function H.run(env, path)
	local f = assert(loadfile(path))
	setfenv(f, env)
	return f()
end

function H.include(env, path)
	local p = H.ADDON .. "/lua/" .. path
	local fh = io.open(p)
	if not fh then p = H.ADDON .. "/gamemodes/mccreative/gamemode/" .. path else fh:close() end
	return H.run(env, p)
end

function H.loadEntity(env, class, kind)
	local key = kind == "weapon" and "SWEP" or "ENT"
	local t = {}
	if kind == "weapon" then t.Primary, t.Secondary = {}, {} end
	env[key] = t
	H.run(env, H.ADDON .. "/gamemodes/mccreative/entities/" .. (kind == "weapon" and "weapons/" or "entities/") .. class .. ".lua")
	env[key] = nil
	H.entdefs[env.name][class] = t
	return t
end

function H.boot(realm)
	local env = H.makeEnv(realm)
	H.run(env, H.ADDON .. "/gamemodes/mccreative/gamemode/" .. (realm == "server" and "init.lua" or "cl_init.lua"))
	H.loadEntity(env, "mcc_chunk")
	H.loadEntity(env, "mcc_block_prop")
	H.loadEntity(env, "mcc_hand", "weapon")
	return env
end

function H.callHook(env, name, ...)
	local r
	for id, fn in pairs(env.hooks[name] or {}) do
		local v = fn(...)
		if v ~= nil then r = v end
	end
	return r
end

function H.notes(kind)
	local out = {}
	for _, n in ipairs(H.log) do if n[1] == kind then out[#out + 1] = n end end
	return out
end

return H
