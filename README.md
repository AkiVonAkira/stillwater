# Stillwater

Kayzel's colors. Warm feppz surfaces, muted cyan accent.

Forked from a personal feppz! pack (foxnne, itself an eppz! / Teppz edit). Publisher is kayzel. The green UI accent is gone. Cyan sits where the cursor, badges, and focus used to be green. Syntax lime stays.

The repo is the theme. Editors are adapters.

## Colors

`palette.json` field `palette` is the set to use. `stillwater.css` is the same set as custom properties (`--stillwater-canvas`, `--stillwater-accent`, and the rest). Anything that can read JSON or CSS can use those files. Do not invent a second palette.

`python build.py` rewrites `stillwater.css` from `palette.json`. Pass a feppz theme path only when rebuilding the VS Code token file.

`hexMap` in `palette.json` is the one-time green-to-cyan remap for that VS Code file. Other apps should ignore it.

## Adapters

| Folder | App |
| --- | --- |
| `vscode/` | Cursor and VS Code extension |
| `t3/` | T3 Code environment theme |
| `ryoku/` | Ryoku desktop scheme |

## Install

Linux (VivoBook Ryoku + T3, and Cursor if present):

```bash
bash ~/Projects/stillwater/install.sh
```

Windows (AKIRA-PC Cursor, VS Code, T3):

```powershell
pwsh C:\Projects\stillwater\install.ps1
```

`install.sh` applies Ryoku and publishes the T3 environment theme. Cursor and VS Code pick up the extension after a window reload. Set the color theme to Stillwater if it does not switch on its own.
