-- Invisible collision for one 16x16x16 chunk of blocks. Drawing is done by MCC.DrawWorld.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Block chunk"
ENT.Spawnable = false
ENT.PhysgunDisabled = true
ENT.m_tblToolsAllowed = {}

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "ChunkX")
	self:NetworkVar("Int", 1, "ChunkY")
	self:NetworkVar("Int", 2, "ChunkZ")
end

function ENT:Key()
	return MCC.ChunkKey(self:GetChunkX(), self:GetChunkY(), self:GetChunkZ())
end

function ENT:Initialize()
	self:DrawShadow(false)
	self:EnableCustomCollisions(true)
	if CLIENT then self:RegisterClient() end
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:BuildCollision(ch)
	local convexes = MCC.ChunkConvexes(ch)
	if #convexes == 0 then return end
	self:PhysicsInitMultiConvex(convexes)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:EnableCustomCollisions(true)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(false) end
	local size = MCC.Cfg.chunk_size * MCC.Cfg.block_size
	if CLIENT then self:SetRenderBounds(Vector(0, 0, 0), Vector(size, size, size)) end
end

if CLIENT then
	-- Client copy of the collision, so movement prediction agrees with the server.
	function ENT:RegisterClient()
		local key = self:Key()
		self.mccKey = key
		MCC.ChunkEntsCL[key] = self
		local ch = MCC.World.chunks[key]
		if ch then self:BuildCollision(ch) end
	end

	function ENT:Think()
		if self.mccKey ~= self:Key() then self:RegisterClient() end
	end

	function ENT:OnRemove()
		if self.mccKey and MCC.ChunkEntsCL[self.mccKey] == self then MCC.ChunkEntsCL[self.mccKey] = nil end
	end

	function ENT:Draw() end
end
