-- One block turned loose as a physics prop (by the physics switch or an explosion).
-- TNT props hiss and explode once lit: by the Block Hand, by gunfire, or by another blast.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Block"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "BlockId")
	self:NetworkVar("Float", 0, "FuseEnd")
end

local function halfSize(shrink)
	return MCC.Cfg.block_size / 2 - (shrink and MCC.Cfg.prop_shrink or 0)
end

function ENT:Initialize()
	if SERVER then
		local h = halfSize(true)
		local mins, maxs = Vector(-h, -h, -h), Vector(h, h, h)
		self:SetModel("models/hunter/blocks/cube075x075x075.mdl")
		self:PhysicsInitBox(mins, maxs)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionBounds(mins, maxs)
		local b = MCC.Blocks[self:GetBlockId()]
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			if b then
				phys:SetMass(b.mass)
				phys:SetMaterial(MCC.SoundGroups[b.sound].phys_material)
			end
			phys:Wake()
		end
	else
		local h = halfSize(false)
		self:SetRenderBounds(Vector(-h, -h, -h), Vector(h, h, h))
	end
end

function ENT:IsTNT()
	local b = MCC.Blocks[self:GetBlockId()]
	return b ~= nil and b.special == "tnt"
end

if SERVER then
	function ENT:Prime(fuse)
		if not self:IsTNT() or self:GetFuseEnd() > 0 then return end
		self:SetFuseEnd(CurTime() + fuse)
		MCC.PlayEffect("tnt_fuse", self:GetPos())
		self:NextThink(CurTime())
	end

	function ENT:OnTakeDamage(dmg)
		self:TakePhysicsDamage(dmg)
		if self:IsTNT() then
			local cfg = MCC.Cfg
			self:Prime(dmg:IsExplosionDamage() and math.Rand(cfg.tnt_chain_fuse_min, cfg.tnt_chain_fuse_max) or cfg.tnt_fuse)
		end
	end

	function ENT:Think()
		local fuse = self:GetFuseEnd()
		if fuse > 0 and CurTime() >= fuse and not self.mccExploded then
			self.mccExploded = true
			local pos = self:WorldSpaceCenter()
			local owner = self.mccOwner
			self:Remove()
			MCC.Explode(pos, game.GetWorld(), owner)
			return
		end
		self:NextThink(CurTime() + 0.05)
		return true
	end
else
	function ENT:Draw()
		MCC.DrawBlockProp(self)
	end
end
