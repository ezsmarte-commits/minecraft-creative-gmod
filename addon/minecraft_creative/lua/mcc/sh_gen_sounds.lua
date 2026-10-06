-- GENERATED from sheets/sound_groups.json by tools/build.py. Edit the sheet, not this file.
MCC = MCC or {}
-- and sheets/effects.json
MCC.SoundGroups = {}
MCC.Effects = {}

-- row: stone
MCC.SoundGroups["stone"] = { ['break'] = { "dig/stone1", "dig/stone2", "dig/stone3", "dig/stone4" }, place = { "dig/stone1", "dig/stone2", "dig/stone3", "dig/stone4" }, step = { "step/stone1", "step/stone2", "step/stone3", "step/stone4" },
	place_pitch = 80, fallback = { ['break'] = "physics/concrete/concrete_break2.wav", place = "physics/concrete/concrete_impact_hard1.wav", step = "player/footsteps/concrete1.wav" },
	phys_material = "concrete" }
-- row: wood
MCC.SoundGroups["wood"] = { ['break'] = { "dig/wood1", "dig/wood2", "dig/wood3", "dig/wood4" }, place = { "dig/wood1", "dig/wood2", "dig/wood3", "dig/wood4" }, step = { "step/wood1", "step/wood2", "step/wood3", "step/wood4" },
	place_pitch = 80, fallback = { ['break'] = "physics/wood/wood_box_break1.wav", place = "physics/wood/wood_box_impact_hard1.wav", step = "player/footsteps/wood1.wav" },
	phys_material = "wood" }
-- row: gravel
MCC.SoundGroups["gravel"] = { ['break'] = { "dig/gravel1", "dig/gravel2", "dig/gravel3", "dig/gravel4" }, place = { "dig/gravel1", "dig/gravel2", "dig/gravel3", "dig/gravel4" }, step = { "step/gravel1", "step/gravel2", "step/gravel3", "step/gravel4" },
	place_pitch = 80, fallback = { ['break'] = "player/footsteps/gravel1.wav", place = "player/footsteps/gravel2.wav", step = "player/footsteps/gravel3.wav" },
	phys_material = "gravel" }
-- row: grass
MCC.SoundGroups["grass"] = { ['break'] = { "dig/grass1", "dig/grass2", "dig/grass3", "dig/grass4" }, place = { "dig/grass1", "dig/grass2", "dig/grass3", "dig/grass4" }, step = { "step/grass1", "step/grass2", "step/grass3", "step/grass4" },
	place_pitch = 80, fallback = { ['break'] = "player/footsteps/grass1.wav", place = "player/footsteps/grass2.wav", step = "player/footsteps/grass3.wav" },
	phys_material = "dirt" }
-- row: sand
MCC.SoundGroups["sand"] = { ['break'] = { "dig/sand1", "dig/sand2", "dig/sand3", "dig/sand4" }, place = { "dig/sand1", "dig/sand2", "dig/sand3", "dig/sand4" }, step = { "step/sand1", "step/sand2", "step/sand3", "step/sand4" },
	place_pitch = 80, fallback = { ['break'] = "player/footsteps/sand1.wav", place = "player/footsteps/sand2.wav", step = "player/footsteps/sand3.wav" },
	phys_material = "sand" }
-- row: cloth
MCC.SoundGroups["cloth"] = { ['break'] = { "dig/cloth1", "dig/cloth2", "dig/cloth3", "dig/cloth4" }, place = { "dig/cloth1", "dig/cloth2", "dig/cloth3", "dig/cloth4" }, step = { "step/cloth1", "step/cloth2", "step/cloth3", "step/cloth4" },
	place_pitch = 80, fallback = { ['break'] = "physics/cardboard/cardboard_box_impact_soft1.wav", place = "physics/cardboard/cardboard_box_impact_soft2.wav", step = "physics/cardboard/cardboard_box_impact_soft3.wav" },
	phys_material = "carpet" }
-- row: glass
MCC.SoundGroups["glass"] = { ['break'] = { "random/glass1", "random/glass2", "random/glass3" }, place = { "dig/stone1", "dig/stone2", "dig/stone3", "dig/stone4" }, step = { "step/stone1", "step/stone2", "step/stone3", "step/stone4" },
	place_pitch = 80, fallback = { ['break'] = "physics/glass/glass_sheet_break1.wav", place = "physics/glass/glass_impact_hard1.wav", step = "player/footsteps/tile1.wav" },
	phys_material = "glass" }
-- row: tnt_fuse
MCC.Effects["tnt_fuse"] = { sounds = { "random/fuse" }, fallback = "ambient/fire/ignite.wav", level = 75, pitch = 100 }
-- row: explosion
MCC.Effects["explosion"] = { sounds = { "random/explode1", "random/explode2", "random/explode3", "random/explode4" }, fallback = "weapons/explode3.wav", level = 100, pitch = 100 }
