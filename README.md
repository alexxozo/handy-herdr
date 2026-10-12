# handy-herdr

Route [Handy](https://github.com/cjpais/Handy) dictation into a chosen [Herdr](https://herdr.dev) agent pane — or paste normally into whatever is focused.

Handy always pastes into the focused field. Inside Herdr that often means the wrong pane (nvim, a shell, another agent). This tiny helper makes Handy’s **External Script** paste method talk to Herdr’s API instead.

## What you get

| Command | Role |
|---------|------|
| `handy-to-herdr` | Handy external-paste script |
| `handy-target` | Pick mode: Herdr auto / pin a pane / native paste |

```text
FN (Handy) → handy-to-herdr → herdr agent prompt <pane>
                 ↘ native Cmd+V when mode=native or Herdr is down
```

## Requirements

- macOS (Handy + `pbcopy` / System Events for native fallback)
- [Handy](https://handy.computer)
- [Herdr](https://herdr.dev) on `PATH` (or `~/.local/bin/herdr`)
- [`fzf`](https://github.com/junegunn/fzf) for `handy-target`
- Accessibility permission for Handy (and for native paste via System Events)

## Install

```bash
git clone https://github.com/alexxozo/handy-herdr.git
cd handy-herdr
./install.sh
```

Then:

1. Quit and reopen **Handy** (so it reloads settings).
2. Confirm **Settings → Advanced**:
   - Paste method: **External Script**
   - Script path: `~/.local/bin/handy-to-herdr`
3. Run `handy-target` and choose a mode.
4. Press **FN**, speak, release.

## Modes (`handy-target`)

| Mode | Behavior |
|------|----------|
| **herdr-auto** | Prefer a Cursor agent that is `working`, else any Cursor agent |
| **herdr-pin** | Always send to a pane you pick |
| **native** | Normal Handy: paste into the focused app/field |

State files (not committed):

- `~/.config/herdr/handy-mode` — `herdr` or `native`
- `~/.config/herdr/handy-target` — pinned pane id (e.g. `w3:p7`)
- `~/.cache/handy-to-herdr.log` — debug log

Override with env:

```bash
export HANDY_HERDR_TARGET=w3:p7     # force pane
export HANDY_HERDR_KIND=cursor      # preferred agent kind for auto
export HANDY_HERDR_MODE=native      # force mode for this shell
```

## Tests

No live Handy/Herdr required — `herdr` / `pbcopy` / `osascript` are mocked:

```bash
./tests/run.sh
```

## Uninstall

```bash
# Handy → Advanced → Paste method back to Clipboard / Ctrl+V
rm -f ~/.local/bin/handy-to-herdr ~/.local/bin/handy-target
```

## Related

- [localvoxtral ↔ Herdr](https://t0msilver.github.io/localvoxtral/integrations/herdr/) — fuller dictation join into a Herdr pane  
- [herdy](https://github.com/dghelm/herdy) — hardware PTT into Herdr  

This project is intentionally small: Handy-native external paste + a target picker.

## License

MIT
