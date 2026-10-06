#!/usr/bin/env python3
"""The preflight must catch each kind of broken sheet. Mutates in-memory copies only."""
import copy, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools"))
import build

base = build.load_sheets()
cases = [
    ("unfilled cell", lambda s: s["blocks"]["rows"][0].__setitem__("mass", None), "unfilled"),
    ("unknown sound group", lambda s: s["blocks"]["rows"][0].__setitem__("sound_group", "metal"), "no sound_groups row"),
    ("duplicate hotbar slot", lambda s: s["blocks"]["rows"][1].__setitem__("hotbar_slot", 1), "slot 1 also used"),
    ("empty hotbar slot", lambda s: s["blocks"]["rows"][0].__setitem__("hotbar_slot", 0), "hotbar slot 1"),
    ("action with no code", lambda s: s["controls"]["rows"][0].__setitem__("action", "Teleport"), "MCC.Actions.Teleport"),
    ("hook fn with no code", lambda s: s["hooks"]["rows"][0].__setitem__("fn", "Nope"), "MCC.Nope"),
    ("not a GMod hook", lambda s: s["hooks"]["rows"][0].__setitem__("hook", "OnBlockPlaced"), "not a Garry's Mod hook"),
    ("texture not in Minecraft", lambda s: s["blocks"]["rows"][0].__setitem__("tex_top", "grass_top"), "texture grass_top"),
    ("sound not in Minecraft", lambda s: s["effects"]["rows"][0].__setitem__("sounds", ["random/fuse9"]), "sound random/fuse9"),
    ("setting the code never reads", lambda s: s["settings"]["rows"].append({"id": "x", "value": 1, "unit": "u", "description": "d"}), "not used"),
    ("setting the code needs", lambda s: s["settings"]["rows"].pop(0), "MCC.Cfg.block_size"),
    ("bad enum", lambda s: s["blocks"]["rows"][0].__setitem__("render", "glowy"), "not one of"),
]
fails = 0
assert build.preflight(base, quiet=True) == [], "real sheets must be clean"
for name, mutate, expect in cases:
    s = copy.deepcopy(base)
    mutate(s)
    errs = build.preflight(s, quiet=True)
    ok = any(expect in e for e in errs)
    fails += not ok
    print(("  ok    " if ok else "  FAIL  ") + "catches " + name + ("" if ok else f"\n        got {errs}"))
build.preflight(base, quiet=True)  # restore build/pending.txt
print(f"\npreflight: {'all passed' if not fails else f'{fails} failed'}")
sys.exit(1 if fails else 0)
