-- The Block Hand: left click breaks, right click places. All world changes happen on the server.
AddCSLuaFile()

SWEP.PrintName = "Block Hand"
SWEP.Author = "Minecraft Creative"
SWEP.Instructions = "Left click: break. Right click: place. E: blocks. F: make physics. R: physics gun."
SWEP.Spawnable = false
SWEP.Slot = 0
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.WorldModel = ""
SWEP.UseHands = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
	self:SetHoldType("normal")
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + MCC.Cfg.break_delay)
	if SERVER then MCC.Actions.Break(self:GetOwner()) end
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + MCC.Cfg.place_delay)
	if SERVER then MCC.Actions.Place(self:GetOwner()) end
end

function SWEP:Reload() end

function SWEP:ShouldDrawViewModel()
	return false
end

function SWEP:DrawWorldModel() end
