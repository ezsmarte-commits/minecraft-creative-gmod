AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

for _, f in ipairs(MCC.SharedFiles) do AddCSLuaFile(f) end
for _, f in ipairs(MCC.ClientFiles) do AddCSLuaFile(f) end
AddCSLuaFile("mcc/sh_gen_hooks.lua")

include("mcc/sv_world.lua")
include("mcc/sh_gen_hooks.lua") -- generated from sheets/hooks.json; added last
