# Changelog

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
