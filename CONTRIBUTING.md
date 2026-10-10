# Contributing

Small fixes push straight to `main`. A new adapter, a new feature, or a large change lands through a pull request. Do not open empty or placeholder PRs.

## Rules

- One PR, one real change. Each adapter is its own PR. Drive-by noise is not.
- `palette.json` is the color and version source. Adapters map it. Do not invent a second palette.
- The installer is OS/app based (`linux/arch`, `macos`, `windows`). Never key off a machine name.
- If an app is not installed and none of its alternate paths exist, skip it and continue.
- `install.sh` / `install.ps1` are interactive by default. No Node, no build. Agents use `--all` / `-All`. Do not add a Python installer.
- Each adapter is that app's native theme, plugin, or extension. Sideload it locally. Do not list it on a marketplace yet.

## Checks

```bash
npm run build
bash tests/test_install.sh
bash install.sh --list
```

`stillwater.css` must match `palette.json` after `npm run build`.
