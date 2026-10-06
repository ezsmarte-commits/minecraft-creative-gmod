-- Minecraft Creative: player movement and footsteps (shared; in single player these run server-side).
MCC = MCC or {}

-- Creative flight. While flying we replace the engine's movement entirely (returning true from
-- the Move hook) and do our own hull-trace collision, so there is no gravity and no friction.
function MCC.FlyMove(ply, mv)
	if not ply:GetNW2Bool("mcc_fly") then return end
	if not ply:Alive() or ply:InVehicle() or ply:GetMoveType() ~= MOVETYPE_WALK then
		if SERVER then ply:SetNW2Bool("mcc_fly", false) end
		return
	end

	local cfg = MCC.Cfg
	local ang = mv:GetMoveAngles()
	ang = Angle(0, ang.y, 0)
	local wish = ang:Forward() * mv:GetForwardSpeed() + ang:Right() * mv:GetSideSpeed()
	wish.z = 0
	local len = wish:Length()
	if len > 0 then wish = wish / len end
	local up = 0
	if mv:KeyDown(IN_JUMP) then up = up + 1 end
	if mv:KeyDown(IN_DUCK) then up = up - 1 end
	local speed = mv:KeyDown(IN_SPEED) and cfg.fly_sprint_speed or cfg.fly_speed
	local target = wish * speed + Vector(0, 0, up * cfg.fly_speed)
	local vel = mv:GetVelocity()
	vel = vel + (target - vel) * cfg.fly_accel

	-- Move with collision: up to three slides along whatever we hit.
	local pos = mv:GetOrigin()
	local mins, maxs = ply:OBBMins(), ply:OBBMaxs()
	local left = FrameTime()
	for _ = 1, 3 do
		if left <= 0 or vel:LengthSqr() < 0.01 then break end
		local tr = util.TraceHull({ start = pos, endpos = pos + vel * left, mins = mins, maxs = maxs,
			mask = MASK_PLAYERSOLID, filter = ply })
		if tr.StartSolid then break end
		pos = tr.HitPos
		if not tr.Hit then break end
		left = left * (1 - tr.Fraction)
		local n = tr.HitNormal
		vel = vel - n * vel:Dot(n)
		pos = pos + n * 0.03
	end
	mv:SetVelocity(vel)
	mv:SetOrigin(pos)

	-- Like Minecraft: flying down onto the ground stops flying.
	if SERVER and up < 0 then
		local tr = util.TraceHull({ start = pos, endpos = pos - Vector(0, 0, 4), mins = mins, maxs = maxs,
			mask = MASK_PLAYERSOLID, filter = ply })
		if tr.Hit and tr.HitNormal.z > 0.7 then
			ply:SetNW2Bool("mcc_fly", false)
		end
	end
	return true
end

-- Minecraft footsteps when walking on blocks; GMod's own sounds everywhere else.
function MCC.Footstep(ply, pos, foot, snd, volume, filter)
	local x, y, z = MCC.PosToCell(ply:GetPos() - Vector(0, 0, 2))
	local id = MCC.GetBlock(x, y, z)
	if id == 0 then return end
	if SERVER then
		local g = MCC.SoundGroups[MCC.Blocks[id].sound]
		ply:EmitSound((MCC.PickSound(g.step, g.fallback.step)), 70, 100, 0.35)
	end
	return true
end
