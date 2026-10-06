#!/usr/bin/env python3
"""Sheets -> preflight -> generated Lua -> release zip.

  python3 tools/build.py preflight     # check only
  python3 tools/build.py gen           # preflight, then write generated Lua + helper manifest
  python3 tools/build.py package VER   # gen, build helper exe, zip the add-on into dist/

The sheets in sheets/ are the source of truth. Generated files start with
"-- GENERATED" and must not be edited by hand.
"""
import hashlib, json, os, re, subprocess, sys, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEETS = os.path.join(ROOT, "sheets")
ADDON = os.path.join(ROOT, "addon", "minecraft_creative")
LUA = os.path.join(ADDON, "lua", "mcc")
GM = os.path.join(ADDON, "gamemodes", "mccreative")
HELPER_SRC = os.path.join(ROOT, "helper")
MC_LISTINGS = os.environ.get("MCC_MC_LISTINGS", os.path.join(os.path.dirname(ROOT), "mcassets"))
GMOD_API = os.path.join(ROOT, "tools", "gmod_hooks.txt")

ENUMS = {
    ("blocks", "render"): {"opaque", "cutout"},
    ("blocks", "special"): {"none", "tnt"},
    ("controls", "handled_by"): {"swep", "bind", "poll", "keypress"},
    ("controls", "when"): {"hand", "physgun", "always"},
    ("hooks", "realm"): {"server", "client", "shared"},
    ("hooks", "returns"): {"yes", "no"},
}


def load_sheets():
    out = {}
    for f in sorted(os.listdir(SHEETS)):
        if f.endswith(".json"):
            with open(os.path.join(SHEETS, f)) as fh:
                s = json.load(fh)
            out[s["sheet"]] = s
    return out


def handwritten_lua():
    """All handwritten Lua (not generated), keyed by path relative to the add-on."""
    files = {}
    for base, _, names in os.walk(ADDON):
        for n in names:
            if n.endswith(".lua"):
                p = os.path.join(base, n)
                with open(p, encoding="utf-8") as fh:
                    src = fh.read()
                if not src.startswith("-- GENERATED"):
                    files[os.path.relpath(p, ADDON)] = src
    return files


def mc_listings():
    lists = {}
    if os.path.isdir(MC_LISTINGS):
        for f in sorted(os.listdir(MC_LISTINGS)):
            m = re.match(r"tree-(.+)\.txt$", f)
            if m:
                with open(os.path.join(MC_LISTINGS, f)) as fh:
                    lists[m.group(1)] = set(l.strip() for l in fh)
    return lists


def textures_and_sounds(sh):
    tex, snd = set(), set()
    for r in sh["blocks"]["rows"]:
        tex.update([r["tex_top"], r["tex_side"], r["tex_bottom"]])
    for r in sh["sound_groups"]["rows"]:
        for c in ("break_sounds", "place_sounds", "step_sounds"):
            snd.update(r[c])
    for r in sh["effects"]["rows"]:
        snd.update(r["sounds"])
    return sorted(tex), sorted(snd)


def preflight(sh, quiet=False):
    errors, pending = [], []

    def err(sheet, row, col, msg):
        errors.append(f"{sheet}[{row}].{col}: {msg}")

    # 1. Every row x column cell is filled; ids unique; enums valid.
    for name, s in sh.items():
        seen = set()
        for r in s["rows"]:
            rid = r.get("id", "?")
            if rid in seen:
                err(name, rid, "id", "duplicate id")
            seen.add(rid)
            for c in s["columns"]:
                v = r.get(c)
                if v is None or v == "" or v == []:
                    err(name, rid, c, "unfilled")
                allowed = ENUMS.get((name, c))
                if allowed and v not in allowed:
                    err(name, rid, c, f"{v!r} not one of {sorted(allowed)}")
            for c in r:
                if c not in s["columns"]:
                    err(name, rid, c, "column not declared in sheet")

    hexre = re.compile(r"^[0-9A-Fa-f]{6}$")
    groups = {r["id"] for r in sh["sound_groups"]["rows"]}
    slots = {}
    for r in sh["blocks"]["rows"]:
        for c in ("tint_top", "tint_side", "tint_bottom"):
            if r[c] != "none" and not hexre.match(str(r[c])):
                err("blocks", r["id"], c, "not a hex colour or none")
        if not hexre.match(str(r["fallback_color"])):
            err("blocks", r["id"], "fallback_color", "not a hex colour")
        if r["sound_group"] not in groups:
            err("blocks", r["id"], "sound_group", f"no sound_groups row {r['sound_group']!r}")
        if not (isinstance(r["mass"], (int, float)) and r["mass"] > 0):
            err("blocks", r["id"], "mass", "must be a positive number")
        s = r["hotbar_slot"]
        if not (isinstance(s, int) and 0 <= s <= 9):
            err("blocks", r["id"], "hotbar_slot", "must be 0-9")
        elif s:
            if s in slots:
                err("blocks", r["id"], "hotbar_slot", f"slot {s} also used by {slots[s]}")
            slots[s] = r["id"]
    for s in range(1, 10):
        if s not in slots:
            errors.append(f"blocks: no block starts in hotbar slot {s}")
    for r in sh["sound_groups"]["rows"]:
        if not (isinstance(r["place_pitch"], int) and 50 <= r["place_pitch"] <= 200):
            err("sound_groups", r["id"], "place_pitch", "must be 50-200")

    # 2. Code references: actions, hook functions, settings.
    code = handwritten_lua()
    allcode = "\n".join(code.values())
    actions = set(re.findall(r"function\s+MCC\.Actions\.(\w+)", allcode))
    for r in sh["controls"]["rows"]:
        if r["action"] not in actions:
            err("controls", r["id"], "action", f"MCC.Actions.{r['action']} is not defined in the code")
        if r["arg"] != "none" and not isinstance(r["arg"], int):
            err("controls", r["id"], "arg", "must be an integer or none")

    def defined_in(fn):
        realms = set()
        for path, src in code.items():
            if re.search(r"function\s+MCC\.%s\s*\(" % re.escape(fn), src):
                base = os.path.basename(path)
                realms.add("server" if base.startswith("sv_") else "client" if base.startswith("cl_") else "shared")
        return realms

    gmod_hooks = None
    if os.path.exists(GMOD_API):
        with open(GMOD_API) as fh:
            gmod_hooks = {l.split("#")[0].strip() for l in fh if l.split("#")[0].strip()}
    for r in sh["hooks"]["rows"]:
        realms = defined_in(r["fn"])
        need = r["realm"]
        ok = ("shared" in realms) or (need in realms) or (need == "shared" and {"server", "client"} <= realms)
        if not ok:
            err("hooks", r["id"], "fn", f"MCC.{r['fn']} not defined for realm {need} (found: {sorted(realms) or 'nowhere'})")
        if gmod_hooks is None:
            pending.append(f"hooks[{r['id']}].hook: {r['hook']} not checked (tools/gmod_hooks.txt missing)")
        elif r["hook"] not in gmod_hooks:
            err("hooks", r["id"], "hook", f"{r['hook']} is not a Garry's Mod hook listed in tools/gmod_hooks.txt")

    cfg_ids = {r["id"] for r in sh["settings"]["rows"]}
    used = set(re.findall(r"(?:MCC\.Cfg|\bcfg)\.(\w+)", allcode))
    for u in sorted(used - cfg_ids):
        errors.append(f"code uses MCC.Cfg.{u} but settings has no such row")
    for u in sorted(cfg_ids - used):
        err("settings", u, "id", "not used anywhere in the code")
    for r in sh["settings"]["rows"]:
        if not isinstance(r["value"], (int, float)):
            err("settings", r["id"], "value", "must be a number")

    # 3. Minecraft file names verified against real version listings.
    tex, snd = textures_and_sounds(sh)
    lists = mc_listings()
    if not lists:
        for t in tex:
            pending.append(f"texture {t}: not verified (no Minecraft listings at {MC_LISTINGS})")
        for s in snd:
            pending.append(f"sound {s}: not verified (no Minecraft listings at {MC_LISTINGS})")
    else:
        for ver, files in lists.items():
            for t in tex:
                if f"assets/minecraft/textures/block/{t}.png" not in files:
                    errors.append(f"texture {t}.png missing in Minecraft {ver}")
            for s in snd:
                if f"assets/minecraft/sounds/{s}.ogg" not in files:
                    errors.append(f"sound {s}.ogg missing in Minecraft {ver}")

    # 4. Things only the running game can confirm.
    for r in sh["sound_groups"]["rows"]:
        for c in ("fallback_break", "fallback_place", "fallback_step"):
            pending.append(f"sound_groups[{r['id']}].{c}: {r[c]} exists in Garry's Mod (check in game)")
    for r in sh["effects"]["rows"]:
        pending.append(f"effects[{r['id']}].fallback: {r['fallback']} exists in Garry's Mod (check in game)")

    if not quiet:
        print(f"preflight: {sum(len(s['rows']) for s in sh.values())} rows in {len(sh)} sheets, "
              f"{len(tex)} textures, {len(snd)} sounds checked against Minecraft {', '.join(sorted(lists)) or '(none)'}")
        for e in errors:
            print("  FAIL ", e)
        if pending:
            print(f"  {len(pending)} cells can only be confirmed in the running game (see build/pending.txt)")
        print("preflight:", "CLEAN" if not errors else f"{len(errors)} problem(s) - fix the sheets or code first")
    os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
    with open(os.path.join(ROOT, "build", "pending.txt"), "w") as fh:
        fh.write("\n".join(pending) + "\n")
    return errors


# ---------------------------------------------------------------- generation
def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def lua_val(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, list):
        return "{ " + ", ".join(lua_val(x) for x in v) + " }"
    return lua_str(v)


def lua_color(h):
    if h == "none":
        return "false"
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return "{ %d, %d, %d }" % (r, g, b)


def header(sheet):
    return f"-- GENERATED from sheets/{sheet}.json by tools/build.py. Edit the sheet, not this file.\nMCC = MCC or {{}}\n"


def gen(sh):
    out = {}
    L = [header("blocks"), "MCC.Blocks = {}", "MCC.BlockIds = {}", "MCC.DefaultHotbar = {}", ""]
    for i, r in enumerate(sh["blocks"]["rows"], 1):
        L.append(f"-- row: {r['id']}")
        L.append(f"MCC.Blocks[{i}] = {{ num = {i}, key = {lua_str(r['id'])}, name = {lua_str(r['name'])},")
        L.append(f"\ttex = {{ top = {lua_str(r['tex_top'])}, side = {lua_str(r['tex_side'])}, bottom = {lua_str(r['tex_bottom'])} }},")
        L.append(f"\ttint = {{ top = {lua_color(r['tint_top'])}, side = {lua_color(r['tint_side'])}, bottom = {lua_color(r['tint_bottom'])} }},")
        L.append(f"\tcutout = {lua_val(r['render'] == 'cutout')}, sound = {lua_str(r['sound_group'])}, fallback = {lua_color(r['fallback_color'])},")
        L.append(f"\tspecial = {lua_str(r['special'])}, mass = {lua_val(r['mass'])} }}")
        L.append(f"MCC.BlockIds[{lua_str(r['id'])}] = {i}")
        if r["hotbar_slot"]:
            L.append(f"MCC.DefaultHotbar[{r['hotbar_slot']}] = {i}")
    out["sh_gen_blocks.lua"] = "\n".join(L) + "\n"

    L = [header("sound_groups") + "-- and sheets/effects.json", "MCC.SoundGroups = {}", "MCC.Effects = {}", ""]
    for r in sh["sound_groups"]["rows"]:
        L.append(f"-- row: {r['id']}")
        L.append(f"MCC.SoundGroups[{lua_str(r['id'])}] = {{ ['break'] = {lua_val(r['break_sounds'])}, place = {lua_val(r['place_sounds'])}, step = {lua_val(r['step_sounds'])},")
        L.append(f"\tplace_pitch = {r['place_pitch']}, fallback = {{ ['break'] = {lua_str(r['fallback_break'])}, place = {lua_str(r['fallback_place'])}, step = {lua_str(r['fallback_step'])} }},")
        L.append(f"\tphys_material = {lua_str(r['phys_material'])} }}")
    for r in sh["effects"]["rows"]:
        L.append(f"-- row: {r['id']}")
        L.append(f"MCC.Effects[{lua_str(r['id'])}] = {{ sounds = {lua_val(r['sounds'])}, fallback = {lua_str(r['fallback'])}, level = {r['level']}, pitch = {r['pitch']} }}")
    out["sh_gen_sounds.lua"] = "\n".join(L) + "\n"

    L = [header("controls"), "MCC.Controls = {}", ""]
    for r in sh["controls"]["rows"]:
        arg = "nil" if r["arg"] == "none" else lua_val(r["arg"])
        hint = "false" if r["hint"] == "none" else lua_str(r["hint"])
        L.append(f"-- row: {r['id']}")
        L.append(f"MCC.Controls[#MCC.Controls + 1] = {{ id = {lua_str(r['id'])}, input = {lua_str(r['input'])}, handled_by = {lua_str(r['handled_by'])}, "
                 f"when = {lua_str(r['when'])}, action = {lua_str(r['action'])}, arg = {arg}, key = {lua_str(r['default_key'])}, hint = {hint} }}")
    out["sh_gen_controls.lua"] = "\n".join(L) + "\n"

    L = [header("settings"), "MCC.Cfg = {"]
    for r in sh["settings"]["rows"]:
        L.append(f"\t{r['id']} = {lua_val(r['value'])}, -- {r['unit']}: {r['description']}")
    L.append("}")
    out["sh_gen_settings.lua"] = "\n".join(L) + "\n"

    L = [header("hooks"), "local function call(fn, keep)", "\treturn function(...)",
         "\t\tlocal f = MCC[fn]", "\t\tif not f then return end",
         "\t\tif keep then return f(...) end", "\t\tf(...)", "\tend", "end", ""]
    for r in sh["hooks"]["rows"]:
        cond = {"server": "SERVER", "client": "CLIENT", "shared": "true"}[r["realm"]]
        L.append(f"-- row: {r['id']} ({r['purpose']})")
        L.append(f"if {cond} then hook.Add({lua_str(r['hook'])}, {lua_str('mcc_' + r['id'])}, call({lua_str(r['fn'])}, {lua_val(r['returns'] == 'yes')})) end")
    out["sh_gen_hooks.lua"] = "\n".join(L) + "\n"

    os.makedirs(LUA, exist_ok=True)
    for name, src in out.items():
        with open(os.path.join(LUA, name), "w", newline="\n") as fh:
            fh.write(src)

    tex, snd = textures_and_sounds(sh)
    os.makedirs(os.path.join(ADDON, "helper"), exist_ok=True)
    with open(os.path.join(ADDON, "helper", "assets.txt"), "w", newline="\n") as fh:
        fh.write("# GENERATED by tools/build.py: files the helper copies from the player's Minecraft Java install.\n")
        fh.writelines(f"texture {t}\n" for t in tex)
        fh.writelines(f"sound {s}\n" for s in snd)
    print(f"gen: wrote {len(out)} Lua files, helper manifest ({len(tex)} textures, {len(snd)} sounds)")


def package(version):
    exe = os.path.join(ADDON, "helper", "mcc-assets.exe")
    env = dict(os.environ, GOOS="windows", GOARCH="amd64", CGO_ENABLED="0")
    subprocess.run(["go", "build", "-trimpath", "-ldflags", f"-s -w -X main.version={version}", "-o", exe, "."],
                   cwd=HELPER_SRC, env=env, check=True)
    os.makedirs(os.path.join(ROOT, "dist"), exist_ok=True)
    out = os.path.join(ROOT, "dist", f"minecraft_creative-{version}.zip")
    skip_dirs = {"materials", "sound"}  # filled at launch from the player's own Minecraft
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for base, dirs, names in os.walk(ADDON):
            rel = os.path.relpath(base, ADDON)
            if rel.split(os.sep)[0] in skip_dirs:
                continue
            for n in sorted(names):
                if n in ("last_run.txt",):
                    continue
                p = os.path.join(base, n)
                z.write(p, os.path.join("minecraft_creative", os.path.relpath(p, ADDON)))
    data = open(out, "rb").read()
    print(f"package: {out} {len(data)} bytes sha256 {hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "preflight"
    sh = load_sheets()
    # Preflight first: nothing is generated or built unless it is clean.
    errs = preflight(sh)
    if errs:
        sys.exit(1)
    if cmd in ("gen", "package"):
        gen(sh)
    if cmd == "package":
        package(sys.argv[2] if len(sys.argv) > 2 else "0.1.0")
