-- GENERATED from sheets/controls.json by tools/build.py. Edit the sheet, not this file.
MCC = MCC or {}

MCC.Controls = {}

-- row: break
MCC.Controls[#MCC.Controls + 1] = { id = "break", input = "+attack", handled_by = "swep", when = "hand", action = "Break", arg = nil, key = "Left mouse", hint = "Break block (crouch to break TNT without lighting it)" }
-- row: place
MCC.Controls[#MCC.Controls + 1] = { id = "place", input = "+attack2", handled_by = "swep", when = "hand", action = "Place", arg = nil, key = "Right mouse", hint = "Place block" }
-- row: pick
MCC.Controls[#MCC.Controls + 1] = { id = "pick", input = "mouse_middle", handled_by = "poll", when = "hand", action = "PickBlock", arg = nil, key = "Middle mouse", hint = "Pick the block you're looking at" }
-- row: hotbar1
MCC.Controls[#MCC.Controls + 1] = { id = "hotbar1", input = "slot1", handled_by = "bind", when = "hand", action = "HotbarSlot", arg = 1, key = "1", hint = "Choose hotbar slot (also 2-9 and mouse wheel)" }
-- row: hotbar2
MCC.Controls[#MCC.Controls + 1] = { id = "hotbar2", input = "slot2", handled_by = "bind", when = "hand", action = "HotbarSlot", arg = 2, key = "2", hint = false }
-- row: hotbar3
MCC.Controls[#MCC.Controls + 1] = { id = "hotbar3", input = "slot3", handled_by = "bind", when = "hand", action = "HotbarSlot", arg = 3, key = "3", hint = false }
-- row: hotbar4
MCC.Controls[#MCC.Controls + 1] = { id = "hotbar4", input = "slot4", handled_by = "bind", when = "hand", action = "HotbarSlot", arg = 4, key = "4", hint = false }
-- row: hotbar5
MCC.Controls[#MCC.Controls + 1] = { id = "hotbar5", input = "slot5", handled_by = "bind", when = "hand", action = "HotbarSlot", arg = 5, key = "5", hint = false }
-- row: hotbar6
MCC.Controls[#MCC.Controls + 1] = { id = "hotbar6", input = "slot6", handled_by = "bind", when = "hand", action = "HotbarSlot", arg = 6, key = "6", hint = false }
-- row: hotbar7
MCC.Controls[#MCC.Controls + 1] = { id = "hotbar7", input = "slot7", handled_by = "bind", when = "hand", action = "HotbarSlot", arg = 7, key = "7", hint = false }
-- row: hotbar8
MCC.Controls[#MCC.Controls + 1] = { id = "hotbar8", input = "slot8", handled_by = "bind", when = "hand", action = "HotbarSlot", arg = 8, key = "8", hint = false }
-- row: hotbar9
MCC.Controls[#MCC.Controls + 1] = { id = "hotbar9", input = "slot9", handled_by = "bind", when = "hand", action = "HotbarSlot", arg = 9, key = "9", hint = false }
-- row: hotbar_next
MCC.Controls[#MCC.Controls + 1] = { id = "hotbar_next", input = "invnext", handled_by = "bind", when = "hand", action = "HotbarScroll", arg = 1, key = "Wheel down", hint = false }
-- row: hotbar_prev
MCC.Controls[#MCC.Controls + 1] = { id = "hotbar_prev", input = "invprev", handled_by = "bind", when = "hand", action = "HotbarScroll", arg = -1, key = "Wheel up", hint = false }
-- row: picker
MCC.Controls[#MCC.Controls + 1] = { id = "picker", input = "+use", handled_by = "bind", when = "hand", action = "OpenPicker", arg = nil, key = "E", hint = "Open all blocks" }
-- row: physics
MCC.Controls[#MCC.Controls + 1] = { id = "physics", input = "impulse 100", handled_by = "bind", when = "hand", action = "MakePhysics", arg = nil, key = "F", hint = "Turn the build you're looking at into physics" }
-- row: swap
MCC.Controls[#MCC.Controls + 1] = { id = "swap", input = "+reload", handled_by = "bind", when = "hand", action = "SwapTool", arg = nil, key = "R", hint = "Switch to the Physics Gun (press 1 to come back)" }
-- row: back_to_hand
MCC.Controls[#MCC.Controls + 1] = { id = "back_to_hand", input = "slot1", handled_by = "bind", when = "physgun", action = "SwapTool", arg = nil, key = "1", hint = false }
-- row: fly
MCC.Controls[#MCC.Controls + 1] = { id = "fly", input = "double_jump", handled_by = "keypress", when = "always", action = "ToggleFly", arg = nil, key = "Space twice", hint = "Fly (Space up, Ctrl down, Shift faster)" }
