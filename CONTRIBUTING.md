# Contributing

Work lands on `main` through pull requests. Do not push to `main`. Do not open empty or placeholder PRs.

## Rules

- One PR, one real change. Each adapter is its own PR. Drive-by noise is not.
- `palette.json` is the color source. Adapters map it. Do not invent a second palette.
- The installer is OS/app based (`linux/arch`, `macos`, `windows`). Never key off a machine name.
- If an app is not installed and none of its alternate paths exist, skip it and continue.
- Install with `install.sh` / `install.ps1` and the app CLIs (`t3`, `ryoku-shell`, and later `spicetify`). Do not add a Python installer.
- Each adapter is that app's native theme, plugin, or extension. Sideload it locally. Do not list it on a marketplace yet.
- Keep the repo private until `install.sh --interactive` can grow into a public chooser.

## Checks

```bash
npm run build
bash tests/test_install.sh
bash install.sh --list
```

`stillwater.css` must match `palette.json` after `npm run build`.
