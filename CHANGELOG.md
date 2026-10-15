# Changelog

## 1.2.3

- Keep city input permanently read-only at the Qt level, including while focused. Bounded keyboard edits never enable Qt's automatic clipboard reads.
- Read clipboard text only on Ctrl+V, Shift+Insert, or middle-click through an isolated helper: 512 raw bytes, 128 characters, a two-second deadline, and a 128 MiB address-space limit.
- Bound IP and city-search downloads to 32 KiB, with HTTPS-only requests, transport deadlines, capped result counts, and validated display strings.
- Own tooltip rendering now explicitly uses plain text on all supported shell versions.
- Preserve unrelated systemd unit symlinks and reject conflicting user-owned units. Bound config, numeric input, state reads, and UI option lists.
- Add actual focused-entry clipboard/keyboard tests, hostile-provider tests, and resource-limit regression checks.
- City typing supports ordinary Unicode key events and bounded explicit paste; IME composition is not supported by the custom input path.

## 1.2.2

- Create the city-search field only during explicit manual editing, and destroy it when saved, cancelled, hidden, or switched to Automatic.
- Keep unfocused input read-only so Qt does not fetch clipboard text for background paste-availability checks.
- Add editor-lifetime, focus, city-selection, and coordinate-save regression checks.

## 1.2.1

- Fix dropdown surfaces and control colours resolving to Qt's `Color` type instead of Omarchy's theme palette.
- Check open-menu palette updates and reopened menus in UI regression tests.

## 1.2.0

- Compact panel with matching mode controls and side-by-side theme/background pickers.
- Saved night light temperature with live preview, from 2500–5500K.
- Friendly warmth names, an optional Kelvin readout, and a quick reset to 4000K.
- Keyboard-operable controls, full-name tooltips, and reduced-motion support.
- Commands pass names as arguments; configuration is parsed as data rather than sourced.
- Automatic location, with city search as a manual override from the sunrise/sunset readout; no fallback city.
- Application theming delegates to Omarchy; no custom Zed or GTK settings edits.
- Scheduler cleanup through `uninstall`, plus recovery for missing dependencies and polar conditions.
- State reconciliation and serialized UI commands prevent stale updates during rapid changes.
- Wider dropdown menus fit long names without widening the panel.

### Updating

Location stays automatic unless you choose Manual in the panel. See the README for
installation, privacy, scheduling, and removal details.
