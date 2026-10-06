-- GENERATED from sheets/blocks.json by tools/build.py. Edit the sheet, not this file.
MCC = MCC or {}

MCC.Blocks = {}
MCC.BlockIds = {}
MCC.DefaultHotbar = {}

-- row: grass
MCC.Blocks[1] = { num = 1, key = "grass", name = "Grass Block",
	tex = { top = "grass_block_top", side = "grass_block_side", bottom = "dirt" },
	tint = { top = { 145, 189, 89 }, side = false, bottom = false },
	cutout = false, sound = "grass", fallback = { 93, 155, 58 },
	special = "none", mass = 30 }
MCC.BlockIds["grass"] = 1
MCC.DefaultHotbar[1] = 1
-- row: dirt
MCC.Blocks[2] = { num = 2, key = "dirt", name = "Dirt",
	tex = { top = "dirt", side = "dirt", bottom = "dirt" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "gravel", fallback = { 134, 96, 67 },
	special = "none", mass = 30 }
MCC.BlockIds["dirt"] = 2
MCC.DefaultHotbar[2] = 2
-- row: stone
MCC.Blocks[3] = { num = 3, key = "stone", name = "Stone",
	tex = { top = "stone", side = "stone", bottom = "stone" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "stone", fallback = { 125, 125, 125 },
	special = "none", mass = 60 }
MCC.BlockIds["stone"] = 3
MCC.DefaultHotbar[3] = 3
-- row: cobblestone
MCC.Blocks[4] = { num = 4, key = "cobblestone", name = "Cobblestone",
	tex = { top = "cobblestone", side = "cobblestone", bottom = "cobblestone" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "stone", fallback = { 110, 110, 110 },
	special = "none", mass = 60 }
MCC.BlockIds["cobblestone"] = 4
MCC.DefaultHotbar[4] = 4
-- row: stone_bricks
MCC.Blocks[5] = { num = 5, key = "stone_bricks", name = "Stone Bricks",
	tex = { top = "stone_bricks", side = "stone_bricks", bottom = "stone_bricks" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "stone", fallback = { 122, 122, 122 },
	special = "none", mass = 60 }
MCC.BlockIds["stone_bricks"] = 5
-- row: bricks
MCC.Blocks[6] = { num = 6, key = "bricks", name = "Bricks",
	tex = { top = "bricks", side = "bricks", bottom = "bricks" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "stone", fallback = { 150, 96, 79 },
	special = "none", mass = 50 }
MCC.BlockIds["bricks"] = 6
MCC.DefaultHotbar[8] = 6
-- row: oak_planks
MCC.Blocks[7] = { num = 7, key = "oak_planks", name = "Oak Planks",
	tex = { top = "oak_planks", side = "oak_planks", bottom = "oak_planks" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "wood", fallback = { 162, 131, 79 },
	special = "none", mass = 20 }
MCC.BlockIds["oak_planks"] = 7
MCC.DefaultHotbar[5] = 7
-- row: oak_log
MCC.Blocks[8] = { num = 8, key = "oak_log", name = "Oak Log",
	tex = { top = "oak_log_top", side = "oak_log", bottom = "oak_log_top" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "wood", fallback = { 107, 84, 50 },
	special = "none", mass = 25 }
MCC.BlockIds["oak_log"] = 8
MCC.DefaultHotbar[6] = 8
-- row: oak_leaves
MCC.Blocks[9] = { num = 9, key = "oak_leaves", name = "Oak Leaves",
	tex = { top = "oak_leaves", side = "oak_leaves", bottom = "oak_leaves" },
	tint = { top = { 72, 181, 24 }, side = { 72, 181, 24 }, bottom = { 72, 181, 24 } },
	cutout = true, sound = "grass", fallback = { 58, 138, 30 },
	special = "none", mass = 5 }
MCC.BlockIds["oak_leaves"] = 9
-- row: glass
MCC.Blocks[10] = { num = 10, key = "glass", name = "Glass",
	tex = { top = "glass", side = "glass", bottom = "glass" },
	tint = { top = false, side = false, bottom = false },
	cutout = true, sound = "glass", fallback = { 200, 230, 240 },
	special = "none", mass = 10 }
MCC.BlockIds["glass"] = 10
MCC.DefaultHotbar[7] = 10
-- row: sand
MCC.Blocks[11] = { num = 11, key = "sand", name = "Sand",
	tex = { top = "sand", side = "sand", bottom = "sand" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "sand", fallback = { 219, 207, 163 },
	special = "none", mass = 35 }
MCC.BlockIds["sand"] = 11
-- row: gravel
MCC.Blocks[12] = { num = 12, key = "gravel", name = "Gravel",
	tex = { top = "gravel", side = "gravel", bottom = "gravel" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "gravel", fallback = { 133, 127, 126 },
	special = "none", mass = 35 }
MCC.BlockIds["gravel"] = 12
-- row: white_wool
MCC.Blocks[13] = { num = 13, key = "white_wool", name = "White Wool",
	tex = { top = "white_wool", side = "white_wool", bottom = "white_wool" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "cloth", fallback = { 233, 236, 236 },
	special = "none", mass = 8 }
MCC.BlockIds["white_wool"] = 13
-- row: red_wool
MCC.Blocks[14] = { num = 14, key = "red_wool", name = "Red Wool",
	tex = { top = "red_wool", side = "red_wool", bottom = "red_wool" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "cloth", fallback = { 161, 39, 34 },
	special = "none", mass = 8 }
MCC.BlockIds["red_wool"] = 14
-- row: bookshelf
MCC.Blocks[15] = { num = 15, key = "bookshelf", name = "Bookshelf",
	tex = { top = "oak_planks", side = "bookshelf", bottom = "oak_planks" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "wood", fallback = { 111, 84, 53 },
	special = "none", mass = 25 }
MCC.BlockIds["bookshelf"] = 15
-- row: iron_block
MCC.Blocks[16] = { num = 16, key = "iron_block", name = "Block of Iron",
	tex = { top = "iron_block", side = "iron_block", bottom = "iron_block" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "stone", fallback = { 220, 220, 220 },
	special = "none", mass = 150 }
MCC.BlockIds["iron_block"] = 16
-- row: gold_block
MCC.Blocks[17] = { num = 17, key = "gold_block", name = "Block of Gold",
	tex = { top = "gold_block", side = "gold_block", bottom = "gold_block" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "stone", fallback = { 246, 208, 61 },
	special = "none", mass = 150 }
MCC.BlockIds["gold_block"] = 17
-- row: diamond_block
MCC.Blocks[18] = { num = 18, key = "diamond_block", name = "Block of Diamond",
	tex = { top = "diamond_block", side = "diamond_block", bottom = "diamond_block" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "stone", fallback = { 98, 219, 213 },
	special = "none", mass = 150 }
MCC.BlockIds["diamond_block"] = 18
-- row: obsidian
MCC.Blocks[19] = { num = 19, key = "obsidian", name = "Obsidian",
	tex = { top = "obsidian", side = "obsidian", bottom = "obsidian" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "stone", fallback = { 21, 16, 30 },
	special = "none", mass = 200 }
MCC.BlockIds["obsidian"] = 19
-- row: glowstone
MCC.Blocks[20] = { num = 20, key = "glowstone", name = "Glowstone",
	tex = { top = "glowstone", side = "glowstone", bottom = "glowstone" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "glass", fallback = { 217, 168, 92 },
	special = "none", mass = 20 }
MCC.BlockIds["glowstone"] = 20
-- row: tnt
MCC.Blocks[21] = { num = 21, key = "tnt", name = "TNT",
	tex = { top = "tnt_top", side = "tnt_side", bottom = "tnt_bottom" },
	tint = { top = false, side = false, bottom = false },
	cutout = false, sound = "grass", fallback = { 219, 47, 47 },
	special = "tnt", mass = 20 }
MCC.BlockIds["tnt"] = 21
MCC.DefaultHotbar[9] = 21
