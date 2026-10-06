include("shared.lua")
for _, f in ipairs(MCC.ClientFiles) do include(f) end
include("mcc/sh_gen_hooks.lua") -- generated from sheets/hooks.json; added last
