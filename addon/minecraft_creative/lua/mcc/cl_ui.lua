-- Minecraft Creative: client controls and HUD (hotbar, block picker, outline, help).
-- Which key does what comes from the controls sheet (MCC.Controls).
MCC = MCC or {}
MCC.Hotbar = MCC.Hotbar or table.Copy(MCC.DefaultHotbar)
MCC.Slot = MCC.Slot or 1

local function holding(when)
	local ply = LocalPlayer()
	if when == "always" then return true end
	if not IsValid(ply) then return false end
	local w = ply:GetActiveWeapon()
	local cls = IsValid(w) and w:GetClass() or ""
	if when == "hand" then return cls == "mcc_hand" end
	if when == "physgun" then return cls == "weapon_physgun" end
	return false
end

-- ---------------------------------------------------------------- hotbar
function MCC.SelectedBlock()
	return MCC.Hotbar[MCC.Slot]
end

function MCC.SendSelection()
	net.Start("mcc_select")
	net.WriteUInt(MCC.SelectedBlock() or 0, 8)
	net.SendToServer()
	MCC.nameUntil = CurTime() + 2
end

function MCC.Actions.HotbarSlot(n)
	MCC.Slot = n
	MCC.SendSelection()
end

function MCC.Actions.HotbarScroll(d)
	MCC.Slot = (MCC.Slot - 1 + d) % 9 + 1
	MCC.SendSelection()
end

-- Middle click: choose the block you're looking at (jump to it if it's already in the hotbar).
function MCC.Actions.PickBlock()
	local t = MCC.GetTarget(LocalPlayer())
	if not t or t.kind ~= "block" then return end
	for i = 1, 9 do
		if MCC.Hotbar[i] == t.id then
			MCC.Slot = i
			MCC.SendSelection()
			return
		end
	end
	MCC.Hotbar[MCC.Slot] = t.id
	MCC.SendSelection()
end

local function askServer(name)
	net.Start("mcc_action")
	net.WriteString(name)
	net.SendToServer()
end

function MCC.Actions.MakePhysics() askServer("MakePhysics") end
function MCC.Actions.SwapTool() askServer("SwapTool") end

-- ---------------------------------------------------------------- icons and picker
function MCC.DrawBlockIcon(id, x, y, w, h)
	local b = MCC.Blocks[id]
	if not b then return end
	if MCC.HasTexture(b.tex.side) then
		MCC.iconMats = MCC.iconMats or {}
		local m = MCC.iconMats[b.tex.side]
		if not m then
			m = Material(MCC.TexturePath(b.tex.side), "noclamp")
			MCC.iconMats[b.tex.side] = m
		end
		local t = b.tint.side or { 255, 255, 255 }
		surface.SetDrawColor(t[1], t[2], t[3], 255)
		surface.SetMaterial(m)
		surface.DrawTexturedRect(x, y, w, h)
	else
		surface.SetDrawColor(b.fallback[1], b.fallback[2], b.fallback[3], 255)
		surface.DrawRect(x, y, w, h)
	end
end

function MCC.Actions.OpenPicker()
	if IsValid(MCC.PickerFrame) then
		MCC.PickerFrame:Close()
		return
	end
	local cols, cell = 7, 56
	local rows = math.ceil(#MCC.Blocks / cols)
	local f = vgui.Create("DFrame")
	f:SetTitle("Blocks: click one to put it in hotbar slot " .. MCC.Slot .. "  (E to close)")
	f:SetSize(cols * cell + 16, rows * cell + 40)
	f:Center()
	f:MakePopup()
	f.OnKeyCodePressed = function(self, code)
		if code == KEY_E then self:Close() end
	end
	local grid = vgui.Create("DIconLayout", f)
	grid:Dock(FILL)
	grid:SetSpaceX(4)
	grid:SetSpaceY(4)
	for i, b in ipairs(MCC.Blocks) do
		local btn = grid:Add("DButton")
		btn:SetSize(cell - 4, cell - 4)
		btn:SetText("")
		btn:SetTooltip(b.name)
		btn.Paint = function(self, w, h)
			draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(255, 255, 255, 70) or Color(0, 0, 0, 140))
			MCC.DrawBlockIcon(i, 6, 6, w - 12, h - 12)
		end
		btn.DoClick = function()
			MCC.Hotbar[MCC.Slot] = i
			MCC.SendSelection()
			f:Close()
		end
	end
	MCC.PickerFrame = f
end

-- ---------------------------------------------------------------- input
function MCC.BindPress(ply, bind, pressed)
	if not pressed then return end
	bind = string.lower(string.Trim(bind))
	for _, c in ipairs(MCC.Controls) do
		if c.handled_by == "bind" and c.input == bind and holding(c.when) then
			MCC.Actions[c.action](c.arg)
			return true
		end
	end
end

function MCC.ClientThink()
	MCC.ProcessDirty()
	if MCC.firstSelectionSent ~= true and IsValid(LocalPlayer()) then
		MCC.firstSelectionSent = true
		MCC.SendSelection()
	end
	local down = input.IsMouseDown(MOUSE_MIDDLE) and not vgui.CursorVisible()
	if down and not MCC.mmbWasDown then
		for _, c in ipairs(MCC.Controls) do
			if c.handled_by == "poll" and c.input == "mouse_middle" and holding(c.when) then
				MCC.Actions[c.action](c.arg)
			end
		end
	end
	MCC.mmbWasDown = down
end

-- ---------------------------------------------------------------- drawing
function MCC.DrawHighlight(depth, skybox)
	if skybox or not holding("hand") then return end
	local t = MCC.GetTarget(LocalPlayer())
	if not t then return end
	local bs = MCC.Cfg.block_size
	if t.kind == "block" then
		render.DrawWireframeBox(MCC.CellMins(t.x, t.y, t.z), Angle(0, 0, 0), Vector(-0.5, -0.5, -0.5),
			Vector(bs + 0.5, bs + 0.5, bs + 0.5), Color(0, 0, 0, 230), true)
	else
		-- On bare map surfaces show where the block will land.
		render.DrawWireframeBox(MCC.CellMins(t.px, t.py, t.pz), Angle(0, 0, 0), Vector(0, 0, 0),
			Vector(bs, bs, bs), Color(255, 255, 255, 60), true)
	end
end

local function shadowText(text, font, x, y, col, ax, ay)
	draw.SimpleText(text, font, x + 2, y + 2, Color(0, 0, 0, 200), ax, ay)
	draw.SimpleText(text, font, x, y, col, ax, ay)
end

function MCC.DrawHUD()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end
	local sw, sh = ScrW(), ScrH()
	MCC.helpUntil = MCC.helpUntil or (CurTime() + MCC.Cfg.help_seconds)

	if holding("hand") then
		-- Minecraft-style crosshair.
		surface.SetDrawColor(255, 255, 255, 220)
		surface.DrawRect(sw / 2 - 9, sh / 2 - 1, 18, 2)
		surface.DrawRect(sw / 2 - 1, sh / 2 - 9, 2, 18)

		-- Hotbar.
		local size, gap = 44, 4
		local total = 9 * size + 8 * gap
		local x0, y0 = (sw - total) / 2, sh - size - 24
		draw.RoundedBox(4, x0 - 6, y0 - 6, total + 12, size + 12, Color(0, 0, 0, 150))
		for i = 1, 9 do
			local x = x0 + (i - 1) * (size + gap)
			surface.SetDrawColor(80, 80, 80, 200)
			surface.DrawRect(x, y0, size, size)
			if MCC.Hotbar[i] then MCC.DrawBlockIcon(MCC.Hotbar[i], x + 6, y0 + 6, size - 12, size - 12) end
			if i == MCC.Slot then
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawOutlinedRect(x - 2, y0 - 2, size + 4, size + 4, 3)
			end
		end
		local sel = MCC.Blocks[MCC.SelectedBlock() or 0]
		if sel and (MCC.nameUntil or 0) > CurTime() then
			shadowText(sel.name, "DermaLarge", sw / 2, y0 - 22, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		end
	end

	if ply:GetNW2Bool("mcc_fly") then
		shadowText("Flying", "DermaDefaultBold", 20, sh - 120, Color(170, 220, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	if not MCC.HasMinecraftTextures() then
		local msg = "Minecraft textures not found: blocks are shown in plain colours. Install Minecraft Java Edition, play it once, then reinstall this mashup in Melty."
		surface.SetFont("DermaDefaultBold")
		local tw = surface.GetTextSize(msg)
		draw.RoundedBox(4, sw / 2 - tw / 2 - 10, 14, tw + 20, 26, Color(120, 30, 30, 200))
		draw.SimpleText(msg, "DermaDefaultBold", sw / 2, 27, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	if MCC.helpUntil > CurTime() then
		local y = 60
		shadowText("Minecraft Creative", "DermaLarge", 20, y, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 34
		for _, c in ipairs(MCC.Controls) do
			if c.hint then
				shadowText(c.key .. ": " .. c.hint, "DermaDefaultBold", 20, y, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				y = y + 18
			end
		end
	end
end

function MCC.HUDShouldDraw(name)
	if (name == "CHudCrosshair" or name == "CHudWeaponSelection") and holding("hand") then return false end
end
