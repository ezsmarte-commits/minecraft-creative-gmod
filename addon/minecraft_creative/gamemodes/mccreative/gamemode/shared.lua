-- Minecraft Creative: Sandbox plus Minecraft-style creative building.
GM.Name = "Minecraft Creative"
GM.Author = "Minecraft Creative"
GM.TeamBased = false

DeriveGamemode("sandbox")

MCC = MCC or {}
MCC.SharedFiles = {
	"mcc/sh_gen_settings.lua", -- generated from sheets/settings.json
	"mcc/sh_gen_blocks.lua",   -- generated from sheets/blocks.json
	"mcc/sh_gen_sounds.lua",   -- generated from sheets/sound_groups.json + effects.json
	"mcc/sh_gen_controls.lua", -- generated from sheets/controls.json
	"mcc/sh_core.lua",
	"mcc/sh_sound.lua",
	"mcc/sh_player.lua",
}
MCC.ClientFiles = { "mcc/cl_world.lua", "mcc/cl_ui.lua" }

for _, f in ipairs(MCC.SharedFiles) do include(f) end
