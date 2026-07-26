# Auto Theme

An Omarchy (Quattro) shell plugin that switches between a light and a dark
theme at sunrise and sunset, with a bar widget for choosing Light, Dark, or
Auto and for picking which theme — and which of its backgrounds — each mode
uses.

Applying a mode also retints Zed and the GTK/XDG colour scheme so the whole
desktop moves together.

## Layout

```
local.auto-theme/
├── manifest.json                    plugin declaration
├── Widget.qml                       bar widget + popup panel
├── bin/omarchy-auto-theme           engine: sun times, scheduling, theming
├── templates/zed.json.tpl           Zed theme, rendered from the omarchy palette
└── systemd/
    ├── omarchy-auto-theme.service   applies the theme and schedules the next run
    └── omarchy-auto-theme.timer     hourly safety net
```

Everything resolves relative to this directory. The QML finds the script via
`Qt.resolvedUrl`, the script finds its units via `$SCRIPT_DIR`, and the service
unit uses `%h/.config/omarchy/plugins/local.auto-theme/`.

## Requirements

- `sunwait` for sunrise/sunset times
- `omarchy-theme-set` and `omarchy-theme-color` (ship with Omarchy)
- `jq`

## Configuration

`~/.config/omarchy/auto-theme/config`:

```bash
LIGHT_THEME="Flexoki Light"
DARK_THEME="Matte Black"
LIGHT_BACKGROUND=""   # filename within the theme; empty lets omarchy cycle
DARK_BACKGROUND=""
LOCATION=""           # "LAT LON"; empty auto-detects by IP and caches for 24h
```

The panel dropdowns write to this file.

## Backgrounds

Omarchy has no notion of a theme's default background: `omarchy-theme-set`
takes the image one past whatever the previous theme was showing, which never
matches, so it always lands on the theme's first file. Pinning a background
here makes a theme come up on the same image every time.

A pin is a filename, resolved against the same directories
`omarchy-theme-bg-next` searches — `~/.config/omarchy/backgrounds/<theme>/`
first, then the theme's own `backgrounds/`. Cycling from a pinned image
therefore continues from it rather than jumping back to the first.

When a background is pinned, the theme is applied with
`OMARCHY_THEME_SKIP_BACKGROUND=1` and the image set afterwards, so omarchy's
own choice never flashes on screen first. If the file has since disappeared
from the theme, it falls back to `omarchy-theme-bg-next`. Changing a slot's
theme clears its pin, since the filename belonged to the old theme.

## Zed

Zed is themed from the palette rather than by naming a theme installed in the
editor, so a new omarchy theme needs no counterpart looking up and installing.

`templates/zed.json.tpl` is a Zed theme with `{{ key }}` placeholders. Both
slots are rendered from their theme's `colors.toml` — resolved through
`omarchy-theme-color --all`, the same parser omarchy's own templates use — into
a single `~/.config/zed/themes/omarchy.json` holding `Omarchy Light` and
`Omarchy Dark`. Applying a mode then only has to flip `theme.mode`, and Zed
picks the regenerated colours up without a restart.

Scopes follow omarchy's own `vscode-theme.json.tpl` and `helix.toml.tpl` rather
than a fresh set of guesses, so a file looks the same in Zed as it does in
Helix, neovim or VS Code under the same theme. Tags are yellow, punctuation and
delimiters recede to `dark_foreground`, and comments get a `dim` tone derived
from the palette's `muted` grey.

A palette's hues are chosen for a terminal, where one of them colours a prompt
rather than every tag in a file: Flexoki Light's yellow sits at 2.3:1 on its own
background. Three floors are therefore applied against the background, each by
blending toward the foreground — 4.5:1 for the hues, 3.5:1 for punctuation, 3:1
for comments, so the two recessive tones keep their order. Backgrounds and the
ANSI `colorN` keys are exempt: the first are meant to recede, and the last have
to keep matching the real terminal.

Blending toward the foreground rather than toward the next grey up is deliberate.
Everforest's `dark_foreground` is itself 1.7:1, so a blend toward it never
converges, and White and Vantablack order the two greys the opposite way round
to every other theme.

All 22 stock themes clear these floors. What the floors cannot fix is a palette
with fewer distinct hues than there are roles — Retro 82 resolves `blue`,
`magenta` and `purple` to one teal, and 11 of the 22 alias `bright_blue` to
`blue`, which merges operators into functions. Those collapses are in the
palette, and show up identically in omarchy's own VS Code and Helix themes.

The `theme` block in `~/.config/zed/settings.json` is rewritten in place with
`sed`; it is JSONC and trailing commas would not survive a jq round trip.

VS Code, VSCodium and Cursor are left to `omarchy-theme-set-vscode`, which
already installs the theme a stock theme asks for and otherwise generates one
from `colors.toml`. Setting them here only fought with it.

## CLI

```bash
omarchy-auto-theme status         # location, mode, sun times, timer state
omarchy-auto-theme mode light     # manual override, disables auto
omarchy-auto-theme enable         # follow the sun
omarchy-auto-theme disable [mode] # stop following, optionally settle on a mode
omarchy-auto-theme config light "Catppuccin Latte"
omarchy-auto-theme config dark-bg "1-dark-waters.jpg"   # "" to unpin
omarchy-auto-theme backgrounds dark                     # what that theme offers
omarchy-auto-theme panel-json     # state consumed by the panel
```

## How the panel stays current

The script pushes state after applying a change:

```bash
omarchy-shell -q local.auto-theme refresh
```

`Widget.qml` replaces `Panel`'s built-in IPC handler (`manageIpc: false`) to
expose `refresh` alongside `open`/`close`/`toggle` — the base only provides the
latter, so without this the push is silently dropped and the panel falls back to
its 60s poll. Clicks also paint optimistically, so the control never lags.

## Extracting to its own repository

This directory is the whole product; copy it to a new repo root and it installs
with `omarchy plugin add <git-url>`. Before publishing:

- rename the id off the `local.` prefix (`manifest.json` `id`, plus `moduleName`
  and `ipcTarget` in `Widget.qml`, the `refresh_widget` target in the script,
  and the path in the service unit)
- add a LICENSE
- declare the `sunwait` dependency
