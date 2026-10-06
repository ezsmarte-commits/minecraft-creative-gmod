// mcc-assets copies the block textures and sounds Minecraft Creative needs from the
// player's own Minecraft Java Edition install into the add-on folder, so Garry's Mod
// can load them. Nothing from Minecraft is shipped with the mod; every player brings
// their own copy. Run it before Garry's Mod starts; it is quick when already up to date.
//
//	mcc-assets.exe [-minecraft DIR] [-addon DIR] [-done FILE] [-force] [-strict]
//
// -done names a file written when the helper finishes, whatever happened (Melty waits for it
// before starting the game). Without Minecraft the game still runs, with plain-coloured blocks.
package main

import (
	"archive/zip"
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"time"
)

var version = "dev"

var doneFile string // written on every finish, so a launcher waiting for it never hangs

type manifest struct {
	textures []string
	sounds   []string
	hash     string
}

type mcVersion struct {
	ID           string `json:"id"`
	Type         string `json:"type"`
	ReleaseTime  string `json:"releaseTime"`
	InheritsFrom string `json:"inheritsFrom"`
	AssetIndex   struct {
		ID string `json:"id"`
	} `json:"assetIndex"`

	dir     string
	jar     string
	index   string
	release time.Time
}

func main() {
	mcFlag := flag.String("minecraft", "", "Minecraft folder (default: the standard .minecraft folder)")
	addonFlag := flag.String("addon", "", "Add-on folder (default: the folder above this program)")
	force := flag.Bool("force", false, "copy again even if up to date")
	strict := flag.Bool("strict", false, "exit with an error if anything is missing")
	flag.StringVar(&doneFile, "done", "", "file to write when finished (any outcome)")
	flag.Parse()

	addon := *addonFlag
	if addon == "" {
		exe, err := os.Executable()
		if err != nil {
			fail(*strict, "cannot find own location: %v", err)
		}
		addon = filepath.Dir(filepath.Dir(exe))
	}
	log := newLog(filepath.Join(addon, "helper", "last_run.txt"))
	defer log.close()
	log.printf("mcc-assets %s, add-on folder %s", version, addon)

	m, err := readManifest(filepath.Join(addon, "helper", "assets.txt"))
	if err != nil {
		log.printf("ERROR reading assets.txt: %v", err)
		exit(*strict, 1)
	}

	mcDir, tried := findMinecraft(*mcFlag)
	if mcDir == "" {
		log.printf("Minecraft Java Edition not found (looked in: %s).", strings.Join(tried, "; "))
		log.printf("The mod still runs with plain-coloured blocks. Install Minecraft Java Edition and play it once, then start again.")
		exit(*strict, 2)
	}
	v, err := pickVersion(mcDir)
	if err != nil {
		log.printf("Minecraft found at %s but no usable version: %v", mcDir, err)
		log.printf("Open the Minecraft Launcher and play any version from 1.13 on once, then start again.")
		exit(*strict, 3)
	}
	log.printf("using Minecraft %s from %s", v.ID, mcDir)

	stampPath := filepath.Join(addon, "materials", "mcc", "source.txt")
	stamp := "version=" + v.ID + "\nmanifest=" + m.hash + "\n"
	if !*force && upToDate(addon, m, stampPath, stamp) {
		log.printf("already up to date")
		exit(*strict, 0)
	}

	missing := 0
	n, miss, err := copyTextures(v.jar, m.textures, filepath.Join(addon, "materials", "mcc", "block"))
	if err != nil {
		log.printf("ERROR reading %s: %v", v.jar, err)
		exit(*strict, 4)
	}
	log.printf("textures: %d copied, %d missing %v", n, len(miss), miss)
	missing += len(miss)

	n, miss, err = copySounds(mcDir, v.index, m.sounds, filepath.Join(addon, "sound", "mcc"))
	if err != nil {
		log.printf("sounds: unavailable (%v); Garry's Mod sounds will be used", err)
		missing += len(m.sounds)
	} else {
		log.printf("sounds: %d copied, %d missing %v", n, len(miss), miss)
		missing += len(miss)
	}

	if missing == 0 {
		if err := writeFile(stampPath, []byte(stamp)); err != nil {
			log.printf("could not write %s: %v", stampPath, err)
		}
		log.printf("done")
		exit(*strict, 0)
	}
	log.printf("done with %d missing files; those use plain colours or Garry's Mod sounds", missing)
	exit(*strict, 5)
}

func exit(strict bool, code int) {
	if doneFile != "" {
		status := "ok"
		if code != 0 {
			status = fmt.Sprintf("finished with problems (code %d); see helper/last_run.txt", code)
		}
		_ = writeFile(doneFile, []byte("mcc-assets "+version+": "+status+"\n"))
	}
	if strict {
		os.Exit(code)
	}
	os.Exit(0)
}

func fail(strict bool, f string, a ...any) {
	fmt.Fprintf(os.Stderr, f+"\n", a...)
	exit(strict, 1)
}

// ---------------------------------------------------------------- manifest

func readManifest(path string) (*manifest, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	m := &manifest{}
	h := sha256.New()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		h.Write([]byte(line + "\n"))
		kind, name, ok := strings.Cut(line, " ")
		name = strings.TrimSpace(name)
		if !ok || !safeName(name) {
			return nil, fmt.Errorf("bad line %q", line)
		}
		switch kind {
		case "texture":
			m.textures = append(m.textures, name)
		case "sound":
			m.sounds = append(m.sounds, name)
		default:
			return nil, fmt.Errorf("bad line %q", line)
		}
	}
	m.hash = hex.EncodeToString(h.Sum(nil))[:16]
	return m, sc.Err()
}

// Names are short relative paths like "dig/stone1" or "oak_log_top": no "..", no absolute paths.
func safeName(s string) bool {
	if s == "" || strings.HasPrefix(s, "/") || strings.Contains(s, "\\") || strings.Contains(s, ":") {
		return false
	}
	for _, part := range strings.Split(s, "/") {
		if part == "" || part == "." || part == ".." {
			return false
		}
	}
	return true
}

// ---------------------------------------------------------------- finding Minecraft

func findMinecraft(flagDir string) (string, []string) {
	var cands []string
	if flagDir != "" {
		cands = append(cands, flagDir)
	}
	if env := os.Getenv("MCC_MINECRAFT_DIR"); env != "" {
		cands = append(cands, env)
	}
	home, _ := os.UserHomeDir()
	switch runtime.GOOS {
	case "windows":
		if appdata := os.Getenv("APPDATA"); appdata != "" {
			cands = append(cands, filepath.Join(appdata, ".minecraft"))
		}
	case "darwin":
		cands = append(cands, filepath.Join(home, "Library", "Application Support", "minecraft"))
	default:
		cands = append(cands, filepath.Join(home, ".minecraft"))
	}
	for _, c := range cands {
		if st, err := os.Stat(filepath.Join(c, "versions")); err == nil && st.IsDir() {
			return c, cands
		}
	}
	return "", cands
}

func loadVersion(mcDir, id string) (*mcVersion, error) {
	dir := filepath.Join(mcDir, "versions", id)
	raw, err := os.ReadFile(filepath.Join(dir, id+".json"))
	if err != nil {
		return nil, err
	}
	v := &mcVersion{}
	if err := json.Unmarshal(raw, v); err != nil {
		return nil, err
	}
	if v.ID == "" {
		v.ID = id
	}
	v.dir = dir
	if t, err := time.Parse(time.RFC3339, v.ReleaseTime); err == nil {
		v.release = t
	}
	if j := filepath.Join(dir, id+".jar"); fileExists(j) {
		v.jar = j
	}
	v.index = v.AssetIndex.ID
	// Modded profiles (Fabric, Forge...) point at the vanilla version they build on.
	if (v.jar == "" || v.index == "") && v.InheritsFrom != "" && v.InheritsFrom != id {
		if parent, err := loadVersion(mcDir, v.InheritsFrom); err == nil {
			if v.jar == "" {
				v.jar = parent.jar
			}
			if v.index == "" {
				v.index = parent.index
			}
		}
	}
	return v, nil
}

// Newest installed release (then snapshot) whose jar has 1.13+ block textures.
func pickVersion(mcDir string) (*mcVersion, error) {
	entries, err := os.ReadDir(filepath.Join(mcDir, "versions"))
	if err != nil {
		return nil, err
	}
	var vs []*mcVersion
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		if v, err := loadVersion(mcDir, e.Name()); err == nil && v.jar != "" {
			vs = append(vs, v)
		}
	}
	sort.SliceStable(vs, func(i, j int) bool {
		ri, rj := vs[i].Type == "release", vs[j].Type == "release"
		if ri != rj {
			return ri
		}
		return vs[i].release.After(vs[j].release)
	})
	for _, v := range vs {
		if jarHas(v.jar, "assets/minecraft/textures/block/stone.png") {
			return v, nil
		}
	}
	if len(vs) == 0 {
		return nil, errors.New("no installed versions with a game jar")
	}
	return nil, errors.New("installed versions are all older than 1.13")
}

func jarHas(jar, name string) bool {
	z, err := zip.OpenReader(jar)
	if err != nil {
		return false
	}
	defer z.Close()
	for _, f := range z.File {
		if f.Name == name {
			return true
		}
	}
	return false
}

// ---------------------------------------------------------------- copying

func upToDate(addon string, m *manifest, stampPath, stamp string) bool {
	if b, err := os.ReadFile(stampPath); err != nil || string(b) != stamp {
		return false
	}
	for _, t := range m.textures {
		if !fileExists(filepath.Join(addon, "materials", "mcc", "block", filepath.FromSlash(t)+".png")) {
			return false
		}
	}
	for _, s := range m.sounds {
		if !fileExists(filepath.Join(addon, "sound", "mcc", filepath.FromSlash(s)+".ogg")) {
			return false
		}
	}
	return true
}

func copyTextures(jar string, names []string, outDir string) (int, []string, error) {
	z, err := zip.OpenReader(jar)
	if err != nil {
		return 0, nil, err
	}
	defer z.Close()
	byName := map[string]*zip.File{}
	for _, f := range z.File {
		byName[f.Name] = f
	}
	copied, missing := 0, []string{}
	for _, t := range names {
		f := byName["assets/minecraft/textures/block/"+t+".png"]
		if f == nil {
			missing = append(missing, t)
			continue
		}
		rc, err := f.Open()
		if err != nil {
			missing = append(missing, t)
			continue
		}
		data, err := io.ReadAll(io.LimitReader(rc, 4<<20))
		rc.Close()
		if err != nil || writeFile(filepath.Join(outDir, filepath.FromSlash(t)+".png"), data) != nil {
			missing = append(missing, t)
			continue
		}
		copied++
	}
	return copied, missing, nil
}

func copySounds(mcDir, index string, names []string, outDir string) (int, []string, error) {
	if index == "" {
		return 0, nil, errors.New("version has no asset index")
	}
	raw, err := os.ReadFile(filepath.Join(mcDir, "assets", "indexes", index+".json"))
	if err != nil {
		return 0, nil, err
	}
	var idx struct {
		Objects map[string]struct {
			Hash string `json:"hash"`
		} `json:"objects"`
	}
	if err := json.Unmarshal(raw, &idx); err != nil {
		return 0, nil, err
	}
	copied, missing := 0, []string{}
	for _, s := range names {
		obj, ok := idx.Objects["minecraft/sounds/"+s+".ogg"]
		if !ok || len(obj.Hash) < 2 || !isHex(obj.Hash) {
			missing = append(missing, s)
			continue
		}
		data, err := os.ReadFile(filepath.Join(mcDir, "assets", "objects", obj.Hash[:2], obj.Hash))
		if err != nil || writeFile(filepath.Join(outDir, filepath.FromSlash(s)+".ogg"), data) != nil {
			missing = append(missing, s)
			continue
		}
		copied++
	}
	return copied, missing, nil
}

func isHex(s string) bool {
	_, err := hex.DecodeString(s)
	return err == nil
}

func fileExists(p string) bool {
	st, err := os.Stat(p)
	return err == nil && !st.IsDir()
}

// Write via a temp file so a half-written file is never left behind.
func writeFile(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// ---------------------------------------------------------------- log

type logger struct{ f *os.File }

func newLog(path string) *logger {
	_ = os.MkdirAll(filepath.Dir(path), 0o755)
	f, _ := os.Create(path)
	return &logger{f}
}

func (l *logger) printf(format string, a ...any) {
	line := fmt.Sprintf(format, a...)
	fmt.Println(line)
	if l.f != nil {
		fmt.Fprintln(l.f, line)
	}
}

func (l *logger) close() {
	if l.f != nil {
		l.f.Close()
	}
}
