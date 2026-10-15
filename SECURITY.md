# Security review — 2026-10-15

This is a source review and regression-test record, not an independent security
audit or certification. The plugin runs unsandboxed in the shared Omarchy shell.

## Scope

Reviewed all production QML, the Bash engine, helper scripts, systemd templates,
manifest, and their data boundaries: clipboard, HTTPS responses, config/state,
theme/background names, rendered text, subprocess arguments, and unit ownership.

## Findings addressed in 1.2.3

- **Focused clipboard reads:** v1.2.2 did not fix Qt 6.12's automatic clipboard
  text fetches during focused editing. `Entry.qml` now stays read-only permanently.
  Its bounded keyboard edits never toggle writability. Native paste is disabled;
  explicit paste gestures signal `Location.qml` to invoke the isolated helper.
- **Clipboard transport:** `omarchy-auto-theme-io` caps raw input at 512 bytes,
  rejects control characters and text longer than 128 characters, and returns a
  JSON string only after a complete successful read. Clipboard reads have a
  two-second timeout, a one-second kill grace, and 128 MiB address-space limit.
  Typing, closing, hiding, or reopening the editor invalidates pending paste.
- **Unbounded remote data:** both HTTPS providers now use the same helper with
  a 32 KiB raw response cap, fixed HTTPS endpoints, curl configuration disabled,
  a four-second curl timeout, and a five-second outer timeout with one-second
  kill grace. Failed or partial downloads are not exposed as successful data.
  Geocoding checks array shape, limits results to five, validates coordinates,
  and bounds names/regions/countries to 128 characters.
- **Text rendering:** plugin-owned tooltips explicitly use `Text.PlainText`,
  rather than depending on the installed shell's tooltip implementation. Other
  dynamic text sinks also use plain text; text-input content is never rich text.
- **Unit ownership:** arbitrary symlinks at the plugin's unit filenames are no
  longer considered owned. Enable refuses conflicts; uninstall preserves foreign
  units and their enablement links.
- **Local resource bounds:** config reads are limited to 64 KiB and values to
  256 characters. Numeric checks precede arithmetic. Theme/background inventories
  are capped at 128 entries and scalar state reads are bounded.

## Verification

- `tests/run`: isolated backend/config/network/unit-ownership tests.
- `tests/ui-run`: offscreen palette, literal tooltip, schema, editor-lifetime,
  stale-search and stale-paste checks. All network/clipboard providers are mocked.
- `tests/io-run`: oversized and malformed text, failed/partial downloads,
  raw-byte limits, memory limits, hung and slow-drip providers.
- `tests/clipboard-run`: reproduces the unsafe Qt 6.12 baseline, then loads the
  actual `Entry.qml` and verifies zero clipboard text retrievals while focused,
  typing, selecting, undoing, requesting paste, and losing focus.
- Local plugin validation, Bash syntax checks, and whitespace validation.

Tests use offscreen/in-process clipboards or mock providers, not the user's live
clipboard. No downloaded code is executed and no package is installed at runtime.

## Residual boundaries

- This does not patch Qt's clipboard transport globally or protect other widgets
  in the shell. The helper is resource-limited, not a general-purpose sandbox.
- The custom inline input supports ordinary Unicode key events, selection,
  copy/cut, undo/redo, deletion, and explicit paste, but not IME composition.
- IP-based location is approximate; providers and installed themes remain trust
  boundaries. Omarchy's theme commands can execute theme/application hooks.
- Same-user tampering with the plugin, executables, environment, or private files
  is outside this threat model. User-level timers intentionally persist while
  automation is enabled; use the documented uninstall command to remove them.
- Passing tests and marketplace validation do not prove the absence of bugs.
