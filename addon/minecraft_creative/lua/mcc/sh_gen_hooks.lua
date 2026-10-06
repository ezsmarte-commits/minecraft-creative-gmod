-- GENERATED from sheets/hooks.json by tools/build.py. Edit the sheet, not this file.
MCC = MCC or {}

local function call(fn, keep)
	return function(...)
		local f = MCC[fn]
		if not f then return end
		if keep then return f(...) end
		f(...)
	end
end

-- row: setup_world (Anchor the block grid to the floor under the map's spawn point)
if SERVER then hook.Add("InitPostEntity", "mcc_setup_world", call("SetupWorld", false)) end
-- row: cleanup (Sandbox 'clean up everything' also clears blocks)
if SERVER then hook.Add("PostCleanupMap", "mcc_cleanup", call("ResetWorld", false)) end
-- row: send_world (Send existing blocks to a player who joins)
if SERVER then hook.Add("PlayerInitialSpawn", "mcc_send_world", call("SendWorld", false)) end
-- row: loadout (Give the Block Hand, physics gun and tool gun; set Minecraft jump height)
if SERVER then hook.Add("PlayerLoadout", "mcc_loadout", call("PlayerLoadout", true)) end
-- row: server_think (Rebuild changed chunk collision once per tick)
if SERVER then hook.Add("Think", "mcc_server_think", call("ServerThink", false)) end
-- row: jump_tap (Double-tap jump toggles flying)
if SERVER then hook.Add("KeyPress", "mcc_jump_tap", call("KeyPress", false)) end
-- row: fly_move (Creative-style flight: replaces engine movement while flying, with our own collision)
if true then hook.Add("Move", "mcc_fly_move", call("FlyMove", true)) end
-- row: footsteps (Minecraft footstep sounds on blocks)
if true then hook.Add("PlayerFootstep", "mcc_footsteps", call("Footstep", true)) end
-- row: no_physgun_chunks (Physics gun cannot grab the block world itself)
if true then hook.Add("PhysgunPickup", "mcc_no_physgun_chunks", call("BlockChunkPickup", true)) end
-- row: no_gravgun_chunks (Gravity gun cannot grab the block world itself)
if true then hook.Add("GravGunPickupAllowed", "mcc_no_gravgun_chunks", call("BlockChunkPickup", true)) end
-- row: no_tool_chunks (Tool gun cannot weld or remove the block world itself)
if true then hook.Add("CanTool", "mcc_no_tool_chunks", call("BlockChunkTool", true)) end
-- row: no_property_chunks (Context menu cannot edit the block world itself)
if true then hook.Add("CanProperty", "mcc_no_property_chunks", call("BlockChunkProperty", true)) end
-- row: binds (Hotbar, block picker, physics switch and tool swap keys)
if CLIENT then hook.Add("PlayerBindPress", "mcc_binds", call("BindPress", true)) end
-- row: client_think (Rebuild changed chunk meshes; middle-click pick block)
if CLIENT then hook.Add("Think", "mcc_client_think", call("ClientThink", false)) end
-- row: draw_world (Draw the block meshes)
if CLIENT then hook.Add("PostDrawOpaqueRenderables", "mcc_draw_world", call("DrawWorld", false)) end
-- row: draw_highlight (Outline the targeted block)
if CLIENT then hook.Add("PostDrawTranslucentRenderables", "mcc_draw_highlight", call("DrawHighlight", false)) end
-- row: hud (Hotbar, crosshair, help and missing-Minecraft warning)
if CLIENT then hook.Add("HUDPaint", "mcc_hud", call("DrawHUD", false)) end
-- row: hud_hide (Hide GMod crosshair and weapon picker while holding the Block Hand)
if CLIENT then hook.Add("HUDShouldDraw", "mcc_hud_hide", call("HUDShouldDraw", true)) end
