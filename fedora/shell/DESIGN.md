# FaradayOS Terminal Shell: design doc (draft v1)

*Written 1 Nov 2026. This is a plan only. Nothing in the repo or the ISO has been changed.*
*Open choices are marked **[OPEN]**. They wait on Aurora's answers about era, effects and references.*

## 1. The idea in one line
**A professional, industrial, utilitarian shell in the style of an old text-mode terminal, with real windows.** Think of a control-room or mainframe terminal: box-drawn frames, labelled sections, a status line in place of a taskbar and a command prompt in place of a start menu. Every element is there because it does a job; nothing is decoration.

**It runs in two form factors from one theme:** a desktop workstation (mouse and keyboard, many windows) and industrial equipment (touch panels/HMIs, small or low-resolution screens, often one app). See section 4.

## 2. Ground rules
| Rule | Why |
|---|---|
| Keep KWin (KDE's window manager) underneath | KWin already handles NVIDIA, AMD, multi-monitor, VRR, HDR, VR and games. Writing our own compositor would cost years and break all of that. |
| Replace only what you can see | Panel, launcher, notifications, window frames, login, lock screen and splash become FaradayOS. The plumbing stays KDE, so updates keep working. |
| Prefer themes and QML over compiled C++ | QML/SVG themes survive Plasma updates. Compiled KWin plugins break on every KWin release and must be rebuilt (see section 6). |
| Effects never touch fullscreen games or VR | CRT effects switch off for fullscreen windows, so frame rate and latency stay untouched. |
| Apps stay readable | App contents keep a normal font and widget style, tinted with the phosphor colours. Only the shell goes fully monospaced. A whole OS in 8x16 text is hard to work in all day. |
| Keep the ISO lean | Everything here is QML, SVG and small fonts: about 2 to 4 MB in total. Extras such as cool-retro-term ship as a one-click add-on. |
| Function first | Utilitarian means no gimmicks: effects are off by default, colour is used for meaning (state, alarms), and every element is labelled. |
| Colour means state | Follows the idea of the ISA-101 "high-performance HMI" standard used in industry: a calm, neutral base, with bright colour kept for focus, warnings and alarms, so problems stand out at a glance. |
| Boot animation unchanged | Plymouth keeps your animation (PR #9). |
| Your art, used as you made it | You draw the frames, buttons and cursor. I package and wire them up. |

## 3. Visual language

### 3.1 Era **[OPEN]**
| Option | Look | Fit |
|---|---|---|
| **A. Amber phosphor** (recommended) | Orange-gold text on near-black, like an IBM 3270 or DEC VT220 amber. | Amber is almost your brand orange (`#FF7A1A`), so the logo and art fit without changes. |
| B. Green phosphor | Green on black, like an Apple II or VT100 green. | Classic "hacker" look; works as a second theme. |
| C. DOS text-mode | Blue and grey panels, white text and cyan highlights, like Norton Commander or Turbo Pascal. | Most "windowed", but loud and far from your current art. |
| D. 80s Unix workstation | Mostly monochrome with hairline frames and bitmap fonts, like early X11. | Calm, but less "terminal". |

My recommendation is **A as default and B as an optional theme**, both one click in System Settings. Reasons: amber matches your branding, amber displays are common on real industrial equipment, and amber on black is easy on the eyes over long shifts. A second phosphor costs almost nothing once the first exists.

### 3.2 Palette (draft, amber)
| Token | Amber | Green | Use |
|---|---|---|---|
| Background | `#0A0700` | `#000F04` | Screen, panels, window backgrounds |
| Surface | `#140E02` | `#001A08` | Popups, inactive frames |
| Phosphor | `#FFB000` | `#33FF66` | Main text, frames, icons |
| Neutral | `#1C1A16` | `#141A16` | Frame lines and dividers in calm state |
| Phosphor dim | `#A66F00` | `#1F9C3E` | Secondary text, inactive windows |
| Highlight | `#FF7A1A` | `#B6FFC8` | Selection, focus, active task (inverse video) |
| Warning | `#FFD23D` | `#FFD23D` | Warnings (with a `[!]` tag, never colour alone) |
| Alarm | `#FF4A3D` | `#FF4A3D` | Errors, alarms (with a `[!!]` tag, never colour alone) |

Selection uses **inverse video** (background colour on phosphor), like a real terminal.

### 3.3 Type
| Where | Font | Size on ISO | Why |
|---|---|---|---|
| Shell (panel, launcher, frames, login) | **Terminus** (Fedora package `terminus-fonts`) | ~1 MB | A real bitmap-style terminal font, licensed for redistribution, already in Fedora. |
| Alternative for the shell | IBM Plex Mono | ~2 MB | Smoother and more modern if Terminus feels too raw. **[OPEN]** |
| App contents | Noto Sans (as now) | 0 MB | Readability. |

### 3.4 Shapes and chrome
- **Square everything.** No radius, no blur, no glass. Panels are solid.
- **Frames:** single or double box-drawing lines (`┌─┐ ╔═╗`), drawn as SVG so they scale cleanly at any DPI.
- **Window title:** `╔═[ Konsole ]══════════════[_][■][X]╗`. The active window uses a double line; inactive windows use a single, dimmed line.
- **Cursor:** a blinking block `█` in text fields of the shell.
- **Icons:** monochrome phosphor glyphs in the shell. App icons keep Papirus at first, recoloured later if you want. **[OPEN]**

### 3.5 CRT effects **[OPEN]**
| Effect | Where | Cost |
|---|---|---|
| Subtle scanlines and soft glow on shell parts only | Panel, launcher, login, lock | Very low; done in QML, safe across updates. |
| Full-screen CRT (scanlines, glow, vignette, slight curve) | The whole desktop | Low to medium GPU cost; needs a compiled KWin effect (section 7). Off for fullscreen windows; one toggle in the panel. |
| **None, flat text-mode (recommended default)** | — | Zero |

My recommendation, given the professional and utilitarian brief, is **flat by default**, with subtle shell-only scanlines as an option and the full-screen CRT as a later opt-in "fun" setting. Reasons: effects reduce legibility on industrial panels and in bright rooms, and the flat look reads as a serious tool rather than a novelty.

## 4. Two form factors: Workstation and Panel
One theme, two layouts. Both use the same colours, fonts and window frames, so the system looks the same on a desk and on a machine.

| | **Workstation** | **Panel** (industrial equipment / HMI) |
|---|---|---|
| Input | Mouse and keyboard | Touch first, gloves possible; keyboard optional |
| Screens | 1080p and up, multi-monitor | Down to 800×480 and 1024×600 |
| Status line | One thin text row (24 px) | Taller row (48 px) with big tap targets |
| Touch targets | Normal | At least 48×48 px (about 10 mm), more spacing |
| Shell text | Terminus 14–16 px | Terminus 20–28 px, readable from about 1 m |
| Launcher | Typed prompt `FARADAY:\> _` | Same prompt plus a grid of large labelled tiles |
| Windows | Overlapping, movable | Maximised by default; switch with tabs on the status line |
| On-screen keyboard | Off | On when a text field is tapped (Plasma's virtual keyboard) |
| Kiosk mode | Off | Optional: one app fullscreen, auto-restarts, shell locked, admin exit with PIN |
| Alarms | Notification popup | Banner across the top, stays until acknowledged |

**How the mode is chosen:** the installer or first boot offers Workstation or Panel, defaulting to Panel when it finds a touchscreen with a small display. It can be switched later in one click (two global theme layouts).
**Tech:** both are Plasma layouts from the same look-and-feel package (`layout.js`). Kiosk mode uses KDE's built-in Kiosk lockdown plus a KWin rule and a systemd user service for auto-restart. The on-screen keyboard is Plasma's own (size checked before adding; it goes in as an add-on if large).

## 5. Components
| # | Component | Design | Tech approach | Art from you |
|---|---|---|---|---|
| 1 | **Global theme** "FaradayOS Terminal" | Ties everything below into one click | Plasma look-and-feel package (QML + `layout.js` for the default panel layout) | None |
| 2 | **Colour schemes** Amber, Green | Palette in 3.2 | KDE `.colors` files, plus a GTK colour override for GTK apps | None |
| 3 | **Window frames** | Box-drawn title bar, `[_][■][X]` buttons, double line when active | **Aurorae** SVG decoration. No compiling, so it survives KWin updates, and you can edit it in Inkscape. | Frame and button SVGs |
| 4 | **Status line** (replaces the taskbar) | One text row, top or bottom: `[F] 1:firefox* 2:konsole 3:steam │ NET ▲ │ VOL 60 │ 19:54` | Custom QML plasmoid using KDE's task manager model (same data as the stock taskbar) | Optional glyphs |
| 5 | **Launcher** (replaces the start menu) | A prompt: `FARADAY:\> _`. Type to search apps, files and commands; arrow keys move through results; `help` lists categories. | Custom QML plasmoid on top of KRunner (KDE's search engine), so search quality stays as good as now | None |
| 6 | **Notifications** | Boxed message with a `[!]` or `[i]` tag and a timestamp, slides in a line at a time | Phase 1: restyled through the Plasma style (SVG + colours). Later: custom notification popups in QML. | None |
| 7 | **Plasma style** (popups, tooltips, tray menus) | Solid, square, 1 px phosphor border, inverse-video hover | Plasma desktop theme (SVG) | None, or SVG pieces if you want |
| 8 | **Login screen** | Terminal boot text: `FaradayOS v0.77 ALPHA / tty1 / login: _ / password: _` | QML theme for the login manager the ISO uses (the overlay already has `plasmalogin.conf.d` and an SDDM theme) | Optional background |
| 9 | **Lock screen** | `SESSION LOCKED`, big clock, password prompt | Look-and-feel lock screen QML | None |
| 10 | **Splash** (after login) | Fake POST/BIOS check lines scrolling, then `READY.` | Look-and-feel KSplash QML | Optional logo |
| 11 | **Konsole** | Amber/Green profiles that match the shell | Konsole profile + colour scheme | None |
| 12 | **Retro terminal app** (optional) | cool-retro-term for a full CRT terminal | One-click add-on, not on the ISO | None |
| 13 | **Sounds** (optional) | Soft key clicks and a terminal bell | KDE sound theme | Sounds, if you want |
| 14 | **Cursor** (later) | Block or crosshair pointer | Xcursor/SVG cursor theme | ~20 shapes |

| 15 | **Mode switch** Workstation/Panel | See section 4 | Two layouts in the global theme + first-boot chooser | None |
| 16 | **Kiosk mode** | One app, locked shell, PIN exit | KDE Kiosk + KWin rule + systemd user service | None |

### Where the existing glossy style guide fits **[OPEN]**
Your 31 Oct style guide (glass, blur, hypermodern) and this terminal look pull in opposite directions. Two ways forward:
1. **Both, as separate global themes** (recommended): "FaradayOS Terminal" and "FaradayOS Glass". Reason: nothing is wasted, and you pick the default later.
2. **Terminal only**: the glossy plan is dropped.

## 6. Gaming, NVIDIA, VR safety
- KWin, Mesa, NVIDIA drivers, Steam and VR runtimes are untouched.
- Fullscreen games use direct scanout as now; shell effects are not drawn over them.
- The full-screen CRT effect (if built) excludes fullscreen windows and VR, and has a one-click off switch.
- Every phase gets the same ISO build and VM installer test as every other release.

## 6b. Where the work lives: branch `shell/terminal`
- Branch `shell/terminal` is taken from `main`. All shell work goes there; `main` stays the stock release.
- Shell files live in their own folder, `fedora/shell/`, so merges from `main` rarely conflict.
- The only core changes on the branch: one line in `apply-branding.sh` that copies `fedora/shell/overlay/` into the image (a no-op when the folder is empty), and `shell/**` added to the ISO build trigger.
- Core fixes and add-ons flow in by merging `main` into `shell/terminal`, which I do whenever `main` changes and before each shell PR.
- Every push to the branch builds a test ISO with the installer VM test. It never publishes a GitHub Release, because the release workflow only runs for `main`.

## 7. Tech risks
| Risk | Effect | Handling |
|---|---|---|
| Compiled KWin effect (full-screen CRT) breaks when Fedora updates KWin | Effect stops loading until rebuilt; the desktop still works | Keep it last and optional. Build it as an RPM in CI against Fedora's `kwin-devel`, with a check that fails the build on a KWin version change. |
| Custom panel and launcher plasmoids need upkeep across Plasma 6.x | Small QML fixes now and then | Use only public Plasma APIs; test in each ISO build. |
| Monospace shell feels cramped on small screens | Hard to read | Scaling setting in the theme; Terminus has sizes from 12 to 32 px. |
| Notification popups are partly fixed in KDE's code | Phase 1 can only restyle them | Full custom popups are a later phase. |

## 8. Roadmap
Each phase is one PR and one test ISO build, so you can review them one at a time.

| Phase | What | Needs your art? | ETA (my part) | ISO size |
|---|---|---|---|---|
| **0** | **Prototype: phosphor window frame** (section 9) | Placeholder first, your SVGs replace it | ~2 h | <1 MB |
| 1 | Global theme skeleton, Amber + Green colour schemes, Terminus font, Konsole profiles | No | ~1.5 h | ~1 MB |
| 2 | Plasma style (popups, tooltips, tray) | No | ~2 h | <1 MB |
| 3 | Status-line panel plasmoid | Optional glyphs | ~3 h | <0.5 MB |
| 4 | Prompt launcher plasmoid | No | ~3 h | <0.5 MB |
| 5 | Login, lock screen, splash | Optional | ~3 h | <1 MB |
| 5b | **Panel mode**: touch layout, tile launcher, alarm banner, on-screen keyboard | No | ~3 h | <1 MB (keyboard checked first) |
| 5c | **Kiosk mode** for single-app equipment | No | ~2 h | ~0 MB |
| 6 | Shell-only scanline/glow effects (optional) | No | ~1.5 h | ~0 MB |
| 7 | Custom notification popups | No | ~2 h | <0.5 MB |
| 8 | Full-screen CRT KWin effect (opt-in) | No | ~4 h + upkeep | <1 MB |
| 9 | Cursor, sounds, monochrome icons | Yes | after art | 1–3 MB |

## 9. First prototype: the phosphor window frame
**What:** an Aurorae window decoration with a box-drawn amber title bar and `[_][■][X]` buttons, plus the Amber colour scheme so app windows match.
**Why this first:**
- Windows are on screen all the time, so it shows the new look straight away.
- It's SVG, so you can redraw every piece in Inkscape and drop it in, with no code.
- No compiling and no risk from KWin updates.
- It's selectable in System Settings beside the current look, so nothing existing changes.

**Done when:** a test ISO boots, the frame can be chosen in System Settings → Window Decorations, and you've approved the look in screenshots from the CI VM.

## 10. Art checklist for you
| Asset | Format | Details |
|---|---|---|
| Reference images or sketches | Any | Whatever shows the feel you want |
| Window frame pieces | SVG | Title bar left, middle and right; borders; active and inactive. I'll send an exact Aurorae piece list and a template SVG with the prototype. |
| Buttons `[_] [■] [X]` (+ restore) | SVG | 20×20 px base. Normal, hover, pressed, inactive. |
| Login background (optional) | PNG 2560×1440 | Otherwise plain background with scanlines |
| Cursor (later) | SVG | About 20 shapes |

## 11. Decisions needed from you
1. **Era:** amber (recommended), green, DOS or Unix? Or amber default plus green option?
2. **CRT effects:** flat by default (recommended), subtle shell-only scanlines, or full-screen opt-in later?
3. **Panel mode reading:** is "industrial equipment" touch panels/HMIs, small screens and single-app kiosks, as in section 4? Anything else, such as rugged keyboards or no-screen devices?
4. **Shell font:** Terminus (recommended, pixel look) or IBM Plex Mono (smoother)?
5. **Glossy style guide:** keep both looks as themes (recommended), or terminal only?
6. **Status line position (Workstation):** your current left floating panel, or a status line at the top or bottom?
7. **Go-ahead** for the phase 0 prototype.
