// FaradayOS Builder: a small window that builds FaradayOS ISOs.
//
// It holds no build logic of its own. It downloads the FaradayOS source of its own version from GitHub,
// reads fedora/editions.list (one button per edition), asks for the admin password (or fingerprint) once
// through pkexec, and runs fedora/build-iso.sh <edition> through fedora/builder-helper.sh as root.
// ISOs land in one folder (default ~/FaradayOS-ISOs) as FaradayOSv<version>-<edition>.iso.
//
// Settings (optional environment variables):
//
//	FARADAY_BUILDER_SRC=/path/to/faradayos   use this checkout instead of downloading the source
package main

import (
	"archive/tar"
	"bufio"
	"compress/gzip"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/storage"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

//go:embed icon.png
var iconPNG []byte

// Set at release time: go build -ldflags "-X main.version=0.91e"
var version = "dev"

const (
	repo       = "FaradayMicrosystems/faradayos"
	needGB     = 45 // free space per edition build
	maxLogLine = 600
)

type edition struct{ id, name, desc string }

type builder struct {
	a   fyne.App
	w   fyne.Window
	cfg config

	src        string // FaradayOS source folder
	srcVersion string
	editions   []edition

	mu       sync.Mutex
	helperIn io.WriteCloser
	helper   *exec.Cmd
	signedIn bool
	busy     string // edition being built, or a helper task
	pending  string // command to send once signed in
	started  time.Time

	logLines []string
	logDirty bool

	// widgets
	logLabel    *widget.Label
	logScroll   *container.Scroll
	logAcc      *widget.Accordion
	checksBox   *fyne.Container
	signStatus  *widget.Label
	signBtn     *widget.Button
	fingerBtn   *widget.Button
	podmanBtn   *widget.Button
	outEntry    *widget.Entry
	editionBox  *fyne.Container
	editionBtns []*widget.Button
	progress    *widget.ProgressBarInfinite
	statusLabel *widget.Label
	stopBtn     *widget.Button
	updateBox   *fyne.Container
	checksOK    bool
	problems    []string
}

type config struct {
	OutDir string `json:"out_dir"`
}

func dataDir() string {
	if d := os.Getenv("XDG_DATA_HOME"); d != "" {
		return filepath.Join(d, "faradayos-builder")
	}
	h, _ := os.UserHomeDir()
	return filepath.Join(h, ".local", "share", "faradayos-builder")
}

func (b *builder) loadConfig() {
	h, _ := os.UserHomeDir()
	b.cfg.OutDir = filepath.Join(h, "FaradayOS-ISOs")
	if data, err := os.ReadFile(filepath.Join(dataDir(), "config.json")); err == nil {
		var c config
		if json.Unmarshal(data, &c) == nil && filepath.IsAbs(c.OutDir) {
			b.cfg = c
		}
	}
}

func (b *builder) saveConfig() {
	_ = os.MkdirAll(dataDir(), 0o755)
	data, _ := json.MarshalIndent(b.cfg, "", "  ")
	_ = os.WriteFile(filepath.Join(dataDir(), "config.json"), data, 0o644)
}

func main() {
	if len(os.Args) > 1 && (os.Args[1] == "--version" || os.Args[1] == "-v") {
		fmt.Println("FaradayOS Builder", version)
		return
	}
	b := &builder{a: app.NewWithID("com.faradaymicrosystems.builder")}
	icon := fyne.NewStaticResource("faradayos.png", iconPNG)
	b.a.SetIcon(icon)
	b.w = b.a.NewWindow("FaradayOS Builder")
	b.loadConfig()
	b.buildUI(icon)
	b.w.Resize(fyne.NewSize(880, 900))
	b.w.SetCloseIntercept(b.onClose)

	go b.logPump()
	go b.startup()
	if len(os.Args) > 1 && os.Args[1] == "--smoke-test" {
		// CI: start, show the window briefly, then quit
		go func() { time.Sleep(3 * time.Second); fyne.Do(b.a.Quit) }()
	}
	b.w.ShowAndRun()
	b.stopHelper()
}

// ---------- UI ----------

func (b *builder) buildUI(icon fyne.Resource) {
	logo := canvas.NewImageFromResource(icon)
	logo.SetMinSize(fyne.NewSize(56, 56))
	logo.FillMode = canvas.ImageFillContain
	title := widget.NewLabelWithStyle("FaradayOS Builder", fyne.TextAlignLeading, fyne.TextStyle{Bold: true})
	sub := widget.NewLabel("Pick an edition, press its button, and the ISO is built on this PC. Version " + version + ".")
	sub.Wrapping = fyne.TextWrapWord
	b.updateBox = container.NewVBox()
	header := container.NewBorder(nil, nil, logo, nil, container.NewVBox(title, sub, b.updateBox))

	// 1. Checks
	b.checksBox = container.NewVBox(widget.NewLabel("Getting the FaradayOS source..."))
	b.podmanBtn = widget.NewButtonWithIcon("Install podman", theme.DownloadIcon(), func() { b.runHelperTask("install-podman", "Installing podman") })
	b.podmanBtn.Hide()
	recheck := widget.NewButtonWithIcon("Check again", theme.ViewRefreshIcon(), func() { go b.runChecks() })
	checksCard := section("1. Before you build", b.checksBox, container.NewHBox(recheck, b.podmanBtn))

	// 2. Sign in
	b.signStatus = widget.NewLabel("Not signed in yet. The build needs admin rights; you sign in once per session.")
	b.signStatus.Wrapping = fyne.TextWrapWord
	b.signBtn = widget.NewButtonWithIcon("Sign in", theme.LoginIcon(), func() { go b.startHelper() })
	b.fingerBtn = widget.NewButtonWithIcon("Use fingerprint to sign in", theme.VisibilityIcon(), b.askFingerprint)
	b.fingerBtn.Hide()
	signCard := section("2. Sign in", b.signStatus, container.NewHBox(b.signBtn, b.fingerBtn))

	// 3. Build
	b.outEntry = widget.NewEntry()
	b.outEntry.SetText(b.cfg.OutDir)
	b.outEntry.Disable()
	change := widget.NewButtonWithIcon("Change", theme.FolderOpenIcon(), b.pickFolder)
	open := widget.NewButtonWithIcon("Open", theme.FolderIcon(), func() { b.openPath(b.cfg.OutDir) })
	outRow := container.NewBorder(nil, nil, widget.NewLabel("ISOs go to"), container.NewHBox(change, open), b.outEntry)
	b.editionBox = container.NewVBox()
	b.progress = widget.NewProgressBarInfinite()
	b.progress.Stop()
	b.progress.Hide()
	b.statusLabel = widget.NewLabel("")
	b.stopBtn = widget.NewButtonWithIcon("Stop build", theme.MediaStopIcon(), b.askStop)
	b.stopBtn.Hide()
	buildCard := section("3. Build", outRow, b.editionBox, b.progress,
		container.NewBorder(nil, nil, nil, b.stopBtn, b.statusLabel))

	// Log
	b.logLabel = widget.NewLabelWithStyle("", fyne.TextAlignLeading, fyne.TextStyle{Monospace: true})
	b.logLabel.Wrapping = fyne.TextWrapBreak
	b.logScroll = container.NewVScroll(b.logLabel)
	b.logScroll.SetMinSize(fyne.NewSize(0, 220))
	logs := widget.NewAccordion(widget.NewAccordionItem("Log (what the build is doing)", b.logScroll))
	b.logAcc = logs

	b.w.SetContent(container.NewVScroll(container.NewPadded(container.NewVBox(header, checksCard, signCard, buildCard, logs))))
}

func section(title string, parts ...fyne.CanvasObject) fyne.CanvasObject {
	t := widget.NewLabelWithStyle(title, fyne.TextAlignLeading, fyne.TextStyle{Bold: true})
	return container.NewVBox(widget.NewSeparator(), t, container.NewVBox(parts...))
}

func (b *builder) setEditions() {
	b.editionBox.Objects = nil
	b.editionBtns = nil
	for _, e := range b.editions {
		e := e
		btn := widget.NewButtonWithIcon("Build "+e.name, theme.MediaPlayIcon(), func() { b.startBuild(e) })
		btn.Importance = widget.HighImportance
		desc := widget.NewLabel(e.desc)
		desc.Wrapping = fyne.TextWrapWord
		b.editionBtns = append(b.editionBtns, btn)
		b.editionBox.Add(container.NewBorder(nil, nil, container.NewGridWrap(fyne.NewSize(230, 40), btn), nil, desc))
	}
	b.editionBox.Refresh()
	b.refreshButtons()
}

func (b *builder) refreshButtons() {
	b.mu.Lock()
	busy := b.busy != ""
	signed := b.signedIn
	b.mu.Unlock()
	for _, btn := range b.editionBtns {
		if busy || b.src == "" {
			btn.Disable()
		} else {
			btn.Enable()
		}
	}
	if signed {
		b.signBtn.Hide()
	} else {
		b.signBtn.Show()
	}
	if busy {
		b.progress.Show()
		b.progress.Start()
	} else {
		b.progress.Stop()
		b.progress.Hide()
		b.stopBtn.Hide()
	}
}

func (b *builder) pickFolder() {
	d := dialog.NewFolderOpen(func(u fyne.ListableURI, err error) {
		if err != nil || u == nil {
			return
		}
		b.cfg.OutDir = u.Path()
		b.outEntry.SetText(b.cfg.OutDir)
		b.saveConfig()
		go b.runChecks()
	}, b.w)
	_ = os.MkdirAll(b.cfg.OutDir, 0o755)
	if l, err := storage.ListerForURI(storage.NewFileURI(b.cfg.OutDir)); err == nil {
		d.SetLocation(l)
	}
	d.Show()
}

func (b *builder) openPath(p string) {
	_ = os.MkdirAll(p, 0o755)
	_ = exec.Command("xdg-open", p).Start()
}

func (b *builder) onClose() {
	b.mu.Lock()
	busy := b.busy
	b.mu.Unlock()
	if busy == "" {
		b.a.Quit()
		return
	}
	dialog.ShowConfirm("A build is running", "Closing the Builder stops the build. Close anyway?", func(ok bool) {
		if ok {
			b.stopHelper()
			b.a.Quit()
		}
	}, b.w)
}

// ---------- log ----------

var ansi = regexp.MustCompile(`\x1b\[[0-9;?]*[A-Za-z]`)

func (b *builder) logf(format string, a ...any) { b.addLog(fmt.Sprintf(format, a...)) }

func (b *builder) addLog(line string) {
	if i := strings.LastIndex(line, "\r"); i >= 0 {
		line = line[i+1:]
	}
	line = ansi.ReplaceAllString(line, "")
	fmt.Println(line) // also to the terminal, when started from one
	b.mu.Lock()
	b.logLines = append(b.logLines, line)
	if len(b.logLines) > maxLogLine {
		b.logLines = b.logLines[len(b.logLines)-maxLogLine:]
	}
	b.logDirty = true
	b.mu.Unlock()
}

func (b *builder) logPump() {
	for range time.Tick(400 * time.Millisecond) {
		b.mu.Lock()
		dirty := b.logDirty
		text := strings.Join(b.logLines, "\n")
		b.logDirty = false
		busy, started := b.busy, b.started
		b.mu.Unlock()
		fyne.Do(func() {
			if dirty {
				b.logLabel.SetText(text)
				b.logScroll.ScrollToBottom()
			}
			if busy != "" {
				b.statusLabel.SetText(fmt.Sprintf("%s: running for %s. You can leave this open and walk away.", busy, time.Since(started).Round(time.Second)))
			}
		})
	}
}

// ---------- startup: source, editions, checks, update ----------

func (b *builder) startup() {
	if err := b.prepareSource(); err != nil {
		b.logf("Could not get the FaradayOS source: %v", err)
		fyne.Do(func() {
			b.checksBox.Objects = []fyne.CanvasObject{checkRow(false, "FaradayOS source: "+err.Error()+" (check the internet connection, then press Check again)")}
			b.checksBox.Refresh()
		})
		return
	}
	eds, err := readEditions(filepath.Join(b.src, "fedora", "editions.list"))
	if err != nil {
		b.logf("Could not read the editions list: %v", err)
	}
	b.editions = eds
	fyne.Do(b.setEditions)
	b.runChecks()
	b.checkUpdate()
}

func (b *builder) prepareSource() error {
	if s := os.Getenv("FARADAY_BUILDER_SRC"); s != "" {
		b.src, _ = filepath.Abs(s)
		b.logf("Using the FaradayOS source in %s (FARADAY_BUILDER_SRC)", b.src)
	} else {
		ref, url := "main", "https://github.com/"+repo+"/archive/refs/heads/main.tar.gz"
		if version != "dev" {
			ref, url = "v"+version, "https://github.com/"+repo+"/archive/refs/tags/v"+version+".tar.gz"
		}
		dest := filepath.Join(dataDir(), "src", ref)
		// A release's source never changes, so it is downloaded once; main is downloaded fresh each start
		if _, err := os.Stat(filepath.Join(dest, "fedora", "build-iso.sh")); err != nil || ref == "main" {
			b.logf("Downloading the FaradayOS %s source from GitHub...", ref)
			if err := download(url, dest); err != nil {
				return err
			}
		}
		b.src = dest
	}
	if _, err := os.Stat(filepath.Join(b.src, "fedora", "build-iso.sh")); err != nil {
		return errors.New("no fedora/build-iso.sh in " + b.src)
	}
	v, _ := os.ReadFile(filepath.Join(b.src, "fedora", "VERSION"))
	b.srcVersion = strings.TrimSpace(string(v))
	b.logf("FaradayOS source v%s ready: %s", b.srcVersion, b.src)
	return nil
}

// download fetches a GitHub source tarball and unpacks it into dest (top folder stripped).
func download(url, dest string) error {
	client := &http.Client{Timeout: 10 * time.Minute}
	resp, err := client.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return fmt.Errorf("%s: %s", url, resp.Status)
	}
	gz, err := gzip.NewReader(resp.Body)
	if err != nil {
		return err
	}
	tmp := dest + ".partial"
	_ = os.RemoveAll(tmp)
	tr := tar.NewReader(gz)
	for {
		h, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		parts := strings.SplitN(h.Name, "/", 2)
		if len(parts) < 2 || parts[1] == "" {
			continue
		}
		p := filepath.Join(tmp, filepath.FromSlash(parts[1]))
		if !strings.HasPrefix(p, tmp+string(os.PathSeparator)) {
			return fmt.Errorf("bad path in archive: %s", h.Name)
		}
		switch h.Typeflag {
		case tar.TypeDir:
			if err := os.MkdirAll(p, 0o755); err != nil {
				return err
			}
		case tar.TypeReg:
			if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
				return err
			}
			f, err := os.OpenFile(p, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, os.FileMode(h.Mode&0o755)|0o644)
			if err != nil {
				return err
			}
			if _, err := io.Copy(f, tr); err != nil {
				f.Close()
				return err
			}
			f.Close()
		case tar.TypeSymlink:
			_ = os.MkdirAll(filepath.Dir(p), 0o755)
			_ = os.Symlink(h.Linkname, p)
		}
	}
	_ = os.RemoveAll(dest)
	return os.Rename(tmp, dest)
}

func readEditions(path string) ([]edition, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var eds []edition
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		p := strings.SplitN(line, "|", 3)
		if len(p) < 3 {
			continue
		}
		eds = append(eds, edition{strings.TrimSpace(p[0]), strings.TrimSpace(p[1]), strings.TrimSpace(p[2])})
	}
	return eds, sc.Err()
}

func checkRow(ok bool, text string) fyne.CanvasObject {
	ic := theme.ConfirmIcon()
	if !ok {
		ic = theme.ErrorIcon()
	}
	l := widget.NewLabel(text)
	l.Wrapping = fyne.TextWrapWord
	return container.NewBorder(nil, nil, widget.NewIcon(ic), nil, l)
}

type osInfo struct{ id, like, name string }

func readOS() osInfo {
	var o osInfo
	data, _ := os.ReadFile("/etc/os-release")
	for _, l := range strings.Split(string(data), "\n") {
		k, v, ok := strings.Cut(l, "=")
		if !ok {
			continue
		}
		v = strings.Trim(v, `"'`)
		switch k {
		case "ID":
			o.id = v
		case "ID_LIKE":
			o.like = v
		case "PRETTY_NAME":
			o.name = v
		}
	}
	return o
}

func podmanCommand() string {
	o := readOS()
	all := " " + o.id + " " + o.like + " "
	switch {
	case strings.Contains(all, " arch "):
		return "sudo pacman -S podman"
	case strings.Contains(all, " fedora ") || strings.Contains(all, " rhel "):
		return "sudo dnf install podman"
	case strings.Contains(all, " debian ") || strings.Contains(all, " ubuntu "):
		return "sudo apt install podman"
	case strings.Contains(all, " suse ") || strings.Contains(all, " opensuse "):
		return "sudo zypper install podman"
	}
	return "install podman with your package manager"
}

func freeGB(path string) (float64, string) {
	for p := path; ; p = filepath.Dir(p) {
		var st syscall.Statfs_t
		if err := syscall.Statfs(p, &st); err == nil {
			return float64(st.Bavail) * float64(st.Bsize) / 1e9, p
		}
		if p == "/" {
			return 0, p
		}
	}
}

func (b *builder) runChecks() {
	var rows []fyne.CanvasObject
	var problems []string
	add := func(ok bool, text string) {
		rows = append(rows, checkRow(ok, text))
		if !ok {
			problems = append(problems, text)
		}
	}
	add(runtime.GOOS == "linux" && runtime.GOARCH == "amd64", "64-bit PC (x86_64) running Linux: "+readOS().name)
	add(b.src != "", "FaradayOS source v"+b.srcVersion+" downloaded")
	engine := ""
	for _, e := range []string{"podman", "docker"} {
		if _, err := exec.LookPath(e); err == nil {
			engine = e
			break
		}
	}
	if engine != "" {
		add(true, "Container tool: "+engine)
	} else {
		add(false, "podman is not installed. Press Install podman, or run: "+podmanCommand())
	}
	_, pkErr := exec.LookPath("pkexec")
	add(pkErr == nil, "Sign-in tool (pkexec, part of polkit)")
	gb, at := freeGB(b.cfg.OutDir)
	add(gb >= needGB, fmt.Sprintf("Free space: %.0f GB on %s (each build needs about %d GB)", gb, at, needGB))
	rows = append(rows, widget.NewLabel("Each build takes about 1 hour on a typical PC and downloads about 3 GB."))
	b.mu.Lock()
	b.checksOK = len(problems) == 0
	b.problems = problems
	b.mu.Unlock()
	finger := fingerprintAvailable()
	fyne.Do(func() {
		b.checksBox.Objects = rows
		b.checksBox.Refresh()
		if engine == "" {
			b.podmanBtn.Show()
		} else {
			b.podmanBtn.Hide()
		}
		if finger {
			b.fingerBtn.Show()
		} else {
			b.fingerBtn.Hide()
		}
	})
}

// fingerprintAvailable: a finger is enrolled, but the sign-in dialog does not ask for it yet.
func fingerprintAvailable() bool {
	u, err := user.Current()
	if err != nil {
		return false
	}
	out, err := exec.Command("fprintd-list", u.Username).CombinedOutput()
	if err != nil || !strings.Contains(string(out), "#") {
		return false
	}
	pam, err := os.ReadFile("/etc/pam.d/polkit-1")
	return err != nil || !strings.Contains(string(pam), "pam_fprintd")
}

func versionNumber(v string) float64 {
	f, _ := strconv.ParseFloat(strings.TrimSuffix(strings.TrimPrefix(v, "v"), "e"), 64)
	return f
}

func (b *builder) checkUpdate() {
	if version == "dev" {
		return
	}
	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Get("https://api.github.com/repos/" + repo + "/releases/latest")
	if err != nil {
		return
	}
	defer resp.Body.Close()
	var r struct {
		Tag string `json:"tag_name"`
		URL string `json:"html_url"`
	}
	if json.NewDecoder(resp.Body).Decode(&r) != nil || versionNumber(r.Tag) <= versionNumber(version) {
		return
	}
	b.logf("A newer FaradayOS Builder is available: %s", r.Tag)
	fyne.Do(func() {
		btn := widget.NewButtonWithIcon("Get "+r.Tag+" (newer FaradayOS)", theme.DownloadIcon(), func() { _ = exec.Command("xdg-open", r.URL).Start() })
		btn.Importance = widget.WarningImportance
		b.updateBox.Add(container.NewHBox(btn, layout.NewSpacer()))
	})
}

// ---------- the root helper (pkexec) ----------

func (b *builder) startHelper() {
	b.mu.Lock()
	if b.helper != nil {
		b.mu.Unlock()
		return
	}
	b.mu.Unlock()
	helper := filepath.Join(b.src, "fedora", "builder-helper.sh")
	if _, err := os.Stat(helper); err != nil {
		b.logf("This FaradayOS source has no builder-helper.sh: %v", err)
		return
	}
	cmd := exec.Command("pkexec", "/bin/bash", helper)
	in, err := cmd.StdinPipe()
	if err != nil {
		b.logf("Sign-in failed: %v", err)
		return
	}
	pr, pw := io.Pipe()
	cmd.Stdout, cmd.Stderr = pw, pw
	fyne.Do(func() { b.signStatus.SetText("Waiting for you to sign in (password or fingerprint) in the system dialog...") })
	if err := cmd.Start(); err != nil {
		b.logf("Could not start pkexec: %v", err)
		return
	}
	b.mu.Lock()
	b.helper, b.helperIn = cmd, in
	b.mu.Unlock()
	go func() {
		err := cmd.Wait()
		pw.Close()
		code := 0
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			code = ee.ExitCode()
		}
		b.mu.Lock()
		was := b.signedIn
		b.helper, b.helperIn, b.signedIn, b.busy, b.pending = nil, nil, false, "", ""
		b.mu.Unlock()
		msg := "Signed out. Press Sign in to sign in again."
		if !was && (code == 126 || code == 127) {
			msg = "Sign-in was cancelled or not accepted. Press Sign in to try again."
		}
		fyne.Do(func() { b.signStatus.SetText(msg); b.refreshButtons() })
	}()
	sc := bufio.NewScanner(pr)
	sc.Buffer(make([]byte, 64*1024), 1024*1024)
	for sc.Scan() {
		b.helperLine(sc.Text())
	}
}

func (b *builder) helperLine(line string) {
	switch {
	case line == "@@READY":
		b.mu.Lock()
		b.signedIn = true
		pending := b.pending
		b.pending = ""
		b.mu.Unlock()
		fyne.Do(func() {
			b.signStatus.SetText("Signed in. Builds run with admin rights until you close the Builder.")
			b.refreshButtons()
		})
		if pending != "" {
			b.send(pending)
		}
	case strings.HasPrefix(line, "@@DONE "):
		f := strings.Fields(line)
		rc := 1
		if len(f) >= 3 {
			if n, err := strconv.Atoi(f[len(f)-1]); err == nil {
				rc = n
			}
		}
		b.taskDone(f[1], rc)
	default:
		b.addLog(line)
	}
}

func (b *builder) send(cmd string) {
	b.mu.Lock()
	in := b.helperIn
	b.mu.Unlock()
	if in == nil {
		return
	}
	if _, err := io.WriteString(in, cmd+"\n"); err != nil {
		b.logf("Could not talk to the build helper: %v", err)
	}
}

func (b *builder) stopHelper() {
	b.mu.Lock()
	in := b.helperIn
	b.mu.Unlock()
	if in != nil {
		_ = in.Close() // the helper stops a running build when its input ends
	}
}

// runHelperTask runs a helper command, signing in first when needed.
func (b *builder) runHelperTask(cmd, label string) {
	b.mu.Lock()
	if b.busy != "" {
		b.mu.Unlock()
		return
	}
	b.busy, b.started = label, time.Now()
	signed := b.signedIn
	if !signed {
		b.pending = cmd
	}
	b.mu.Unlock()
	b.refreshButtons()
	b.logAcc.Open(0)
	b.logf("== %s ==", label)
	if signed {
		b.send(cmd)
	} else {
		go b.startHelper()
	}
}

func (b *builder) startBuild(e edition) {
	b.mu.Lock()
	ok, problems := b.checksOK, b.problems
	b.mu.Unlock()
	if !ok {
		dialog.ShowInformation("Not ready to build", "Fix these first, then press Check again:\n\n- "+strings.Join(problems, "\n- "), b.w)
		return
	}
	_ = os.MkdirAll(b.cfg.OutDir, 0o755)
	b.runHelperTask("build "+e.id+" "+b.cfg.OutDir, "Building the "+e.name+" edition")
	b.stopBtn.Show()
}

func (b *builder) askStop() {
	dialog.ShowConfirm("Stop the build?", "The ISO will not be finished. You can start again later.", func(ok bool) {
		if ok {
			b.send("stop")
		}
	}, b.w)
}

func (b *builder) askFingerprint() {
	dialog.ShowConfirm("Use your fingerprint to sign in?",
		"This adds one line to /etc/pam.d/polkit-1 so the admin sign-in dialog accepts a fingerprint:\n\n"+
			"    auth  sufficient  pam_fprintd.so\n\n"+
			"Your password keeps working. A backup of the old file is kept next to it.\n"+
			"It affects every admin sign-in dialog on this PC, not only the Builder.",
		func(ok bool) {
			if ok {
				b.runHelperTask("fingerprint", "Turning on fingerprint sign-in")
			}
		}, b.w)
}

func (b *builder) taskDone(cmd string, rc int) {
	b.mu.Lock()
	label := b.busy
	took := time.Since(b.started).Round(time.Minute)
	b.busy = ""
	b.mu.Unlock()
	fyne.Do(func() {
		b.refreshButtons()
		b.statusLabel.SetText("")
		switch cmd {
		case "build":
			if rc == 0 {
				b.statusLabel.SetText(fmt.Sprintf("Done in %s. The ISO is in %s", took, b.cfg.OutDir))
				d := dialog.NewConfirm("ISO ready", fmt.Sprintf("%s finished in %s.\n\nThe ISO is in %s.\nOpen the folder?", label, took, b.cfg.OutDir),
					func(ok bool) {
						if ok {
							b.openPath(b.cfg.OutDir)
						}
					}, b.w)
				d.Show()
			} else if rc == 130 {
				b.statusLabel.SetText("Build stopped.")
			} else {
				b.statusLabel.SetText(fmt.Sprintf("Build failed (code %d). See the log above and %s/build-*.log", rc, b.cfg.OutDir))
				dialog.ShowInformation("Build failed", fmt.Sprintf("%s failed (code %d).\n\nThe log is in %s (build-<edition>.log).\nRunning it again often helps when a download server was busy.", label, rc, b.cfg.OutDir), b.w)
			}
		case "install-podman", "fingerprint":
			if rc == 0 {
				b.statusLabel.SetText(label + ": done.")
			} else {
				b.statusLabel.SetText(fmt.Sprintf("%s: failed (code %d), see the log.", label, rc))
			}
			go b.runChecks()
		}
	})
}
