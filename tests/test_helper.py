#!/usr/bin/env python3
"""Runs the real helper (built for Linux) against fake Minecraft installs laid out like the
launcher's: versions/<id>/<id>.json + .jar, assets/indexes/<n>.json, assets/objects/<hh>/<hash>.
The file contents are placeholders; only the layout and names are real."""
import hashlib, json, os, shutil, subprocess, sys, tempfile, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON_SRC = os.path.join(ROOT, "addon", "minecraft_creative")
fails = 0


def check(name, cond, detail=""):
    global fails
    print(("  ok    " if cond else "  FAIL  ") + name + ("" if cond else f"\n        {detail}"))
    fails += 0 if cond else 1


def manifest():
    tex, snd = [], []
    for line in open(os.path.join(ADDON_SRC, "helper", "assets.txt")):
        if line.startswith("texture "): tex.append(line.split()[1])
        if line.startswith("sound "): snd.append(line.split()[1])
    return tex, snd


def make_version(mc, vid, typ, when, index, textures, inherits=None, jar=True):
    d = os.path.join(mc, "versions", vid)
    os.makedirs(d, exist_ok=True)
    meta = {"id": vid, "type": typ, "releaseTime": when}
    if index: meta["assetIndex"] = {"id": index}
    if inherits: meta["inheritsFrom"] = inherits
    json.dump(meta, open(os.path.join(d, vid + ".json"), "w"))
    if jar:
        with zipfile.ZipFile(os.path.join(d, vid + ".jar"), "w") as z:
            for t, folder in textures:
                z.writestr(f"assets/minecraft/textures/{folder}/{t}.png", f"PNG:{vid}:{t}")


def make_sounds(mc, index, sounds):
    objs = {}
    for s in sounds:
        data = f"OGG:{s}".encode()
        h = hashlib.sha1(data).hexdigest()
        p = os.path.join(mc, "assets", "objects", h[:2], h)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        open(p, "wb").write(data)
        objs[f"minecraft/sounds/{s}.ogg"] = {"hash": h, "size": len(data)}
    os.makedirs(os.path.join(mc, "assets", "indexes"), exist_ok=True)
    json.dump({"objects": objs}, open(os.path.join(mc, "assets", "indexes", index + ".json"), "w"))


def run(exe, addon, *args, env=None):
    e = dict(os.environ, HOME="/nonexistent")
    e.update(env or {})
    r = subprocess.run([exe, "-addon", addon, *args], capture_output=True, text=True, env=e)
    return r.returncode, r.stdout + r.stderr


def main():
    work = tempfile.mkdtemp(prefix="mcc-helper-test-")
    exe = os.path.join(work, "mcc-assets")
    subprocess.run(["go", "build", "-o", exe, "."], cwd=os.path.join(ROOT, "helper"), check=True)
    tex, snd = manifest()

    addon = os.path.join(work, "addon")
    shutil.copytree(ADDON_SRC, addon, ignore=shutil.ignore_patterns("materials", "sound", "*.exe", "last_run.txt"))
    mc = os.path.join(work, ".minecraft")
    make_version(mc, "1.21.10", "release", "2025-10-07T09:17:23+00:00", "27", [(t, "block") for t in tex])
    make_version(mc, "26.4-snapshot-3", "snapshot", "2026-09-30T10:00:00+00:00", "30", [(t, "block") for t in tex])
    make_version(mc, "1.12.2", "release", "2017-09-18T08:39:46+00:00", "1.12", [("stone", "blocks")])
    make_version(mc, "fabric-loader-0.17-1.21.10", "release", "2026-01-01T00:00:00+00:00", None, [], inherits="1.21.10", jar=False)
    make_sounds(mc, "27", snd)

    code, out = run(exe, addon, "-minecraft", mc)
    check("copies every texture and sound from the newest release", code == 0 and "textures: 25 copied, 0 missing" in out
          and "sounds: 56 copied, 0 missing" in out, out)
    check("prefers a release over a newer snapshot; a Fabric profile resolves to its vanilla jar",
          "using Minecraft fabric-loader-0.17-1.21.10" in out or "using Minecraft 1.21.10" in out, out)
    p = os.path.join(addon, "materials", "mcc", "block", "grass_block_top.png")
    check("texture lands where the Lua loads it", os.path.exists(p) and open(p).read().startswith("PNG:1.21.10"), p)
    p = os.path.join(addon, "sound", "mcc", "dig", "stone1.ogg")
    check("sound lands where the Lua loads it", os.path.exists(p) and open(p).read() == "OGG:dig/stone1", p)
    check("writes a readable log", os.path.exists(os.path.join(addon, "helper", "last_run.txt")))

    code, out = run(exe, addon, "-minecraft", mc)
    check("second launch is a quick no-op", code == 0 and "already up to date" in out, out)

    os.remove(os.path.join(addon, "sound", "mcc", "dig", "stone1.ogg"))
    code, out = run(exe, addon, "-minecraft", mc)
    check("a deleted file is restored on the next launch", "sounds: 56 copied" in out, out)

    # Found through the APPDATA/HOME default location instead of the flag.
    home = os.path.join(work, "home")
    os.makedirs(home)
    os.symlink(mc, os.path.join(home, ".minecraft"))
    code, out = run(exe, addon, "-force", env={"HOME": home})
    check("finds Minecraft in the default folder with no arguments", code == 0 and "textures: 25 copied" in out, out)

    code, out = run(exe, addon, "-minecraft", os.path.join(work, "nope"))
    check("no Minecraft: explains, and still lets the game start (exit 0)", code == 0 and "not found" in out, out)
    done = os.path.join(work, "done", "ready.txt")
    code, out = run(exe, addon, "-minecraft", os.path.join(work, "nope"), "-done", done)
    check("no Minecraft still writes the done file, so Melty never waits forever",
          code == 0 and os.path.exists(done) and "problems" in open(done).read(), out)
    os.remove(done)
    code, out = run(exe, addon, "-minecraft", mc, "-done", done)
    check("done file says ok after a good run", os.path.exists(done) and ": ok" in open(done).read(), out)
    code, _ = run(exe, addon, "-minecraft", os.path.join(work, "nope"), "-strict")
    check("no Minecraft with -strict: exit code 2", code == 2)

    old = os.path.join(work, "old-mc")
    make_version(old, "1.12.2", "release", "2017-09-18T08:39:46+00:00", "1.12", [("stone", "blocks")])
    code, out = run(exe, addon, "-minecraft", old)
    check("only pre-1.13 installed: says so", code == 0 and "older than 1.13" in out, out)

    partial = os.path.join(work, "partial-mc")
    make_version(partial, "1.20.1", "release", "2023-06-12T00:00:00+00:00", "5", [(t, "block") for t in tex if t != "glowstone"])
    code, out = run(exe, addon, "-minecraft", partial, "-force")
    check("missing pieces are reported, not fatal", code == 0 and "1 missing [glowstone]" in out and "Garry's Mod sounds" in out, out)

    bad = os.path.join(work, "bad-addon")
    shutil.copytree(addon, bad)
    open(os.path.join(bad, "helper", "assets.txt"), "a").write("texture ../../../evil\n")
    code, out = run(exe, bad, "-minecraft", mc, "-strict")
    check("refuses manifest paths that escape the add-on folder", code == 1 and "bad line" in out, out)

    shutil.rmtree(work)
    print(f"\nhelper: {'all passed' if not fails else f'{fails} failed'}")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
