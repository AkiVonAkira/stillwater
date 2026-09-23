# Stillwater

Kayzel's colors. Warm feppz surfaces, muted cyan accent.

Forked from a personal feppz! pack (foxnne, itself an eppz! / Teppz edit). Publisher is kayzel. The green UI accent is gone. Cyan sits where the cursor, badges, and focus used to be green. Syntax lime stays.

The repo is the theme. Apps are adapters. Install is by OS and app, not by machine.

This repository is private until the installer can ask which apps to theme. Direct pushes to `main` are not used. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Colors

`palette.json` field `palette` is the set to use. `stillwater.css` is the same set as custom properties (`--stillwater-canvas`, `--stillwater-accent`, `--stillwater-syntax-function`, and the rest). Anything that can read JSON or CSS can use those files. Do not invent a second palette.

`npm run build` rewrites `stillwater.css` from `palette.json`. Pass a feppz theme path only when rebuilding the VS Code token file (`npm run build -- path/to/feppz.json`).

`hexMap` in `palette.json` is the one-time green-to-cyan remap for that VS Code file. Other apps should ignore it.

## Adapters

Each adapter is that app's native theme, plugin, or extension. The root installer runs every folder it finds. Missing apps, and apps with no alternate config path, are skipped. Nothing is listed on a marketplace yet.

| Folder | App |
| --- | --- |
| `vscode/` | Cursor, VS Code, Insiders, VSCodium, Code - OSS, Windsurf |
| `t3/` | T3 Code |
| `ryoku/` | Ryoku (Linux) |

`bash install.sh --list` reports `linux/arch`, `macos`, or `windows`, then each app.

## Install

```bash
bash install.sh
bash install.sh --list
bash install.sh --dry-run
bash install.sh --interactive
bash install.sh cursor t3
```

```powershell
pwsh .\install.ps1
pwsh .\install.ps1 -List
pwsh .\install.ps1 -DryRun
pwsh .\install.ps1 -Interactive
pwsh .\install.ps1 cursor t3
```

`--interactive` is the start of a chooser for a public installer. It only installs apps that are actually present.

Reload the editor after install. Set the color theme to Stillwater if it does not switch on its own.
