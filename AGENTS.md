# Stillwater

A personal color theme. `palette.json` holds the colors, each app folder is an adapter, and `install.sh` / `install.ps1` install them by OS and app. [CONTRIBUTING.md](CONTRIBUTING.md) has the rules and checks. This file covers how the owner asks for work and what has gone wrong before.

## How work is asked for

- Requests are short: an app, a symptom, sometimes a guess ("discord is so slow, update the theme classes maybe?"). Treat the guess as a lead. Find the cause before you change anything. Toggling animations did not fix that lag.
- "Open a PR and merge it" is the normal finish. `main` takes pull requests only, through a GitHub ruleset with no required approvals. Branch, push, open the PR, wait for CI, then merge. Do not commit to local `main` first.
- Two adapters means two PRs.
- "Install it" means run the real installer on this machine, such as `pwsh ./install.ps1 t3` or `bash install.sh t3`. Do not hand-edit the app's live config in place of the adapter.
- When the owner gives a value ("it should be 8px"), use that value, not the nearest one you found elsewhere.

## Done means

1. `npm run build`, `bash tests/test_install.sh`, and `bash install.sh --list` pass, and the PR's CI is green. CI runs on Ubuntu. Git Bash on Windows differs (fork limits, path assertions, no `python3`), so a Windows-only pass is not done.
2. You looked at the themed app yourself. Take the screenshot and check the change and the elements around it. A fix that breaks its neighbor is the common failure: re-adding a Spotify panel broke the full-height album art. The owner should not be the one sending the screenshot.
3. No text is clipped.
4. An adapter that can carry a version takes it from `palette.json`, shows it in `--list`, and has a line in the version check in `.github/workflows/check.yml`.

## Contrast

When one token reads badly, check every ink and surface pair in that adapter, not only the one reported. Dark ink on the dark canvas came back twice in the T3 adapter: first the warning pencil, then the NEW badge and muted labels.

## Speed

Theme CSS for Electron apps (Vencord, Equicord, Spicetify) has to stay cheap. Broad selectors like `[class*=...]` combined with `:has()` made Discord lag. Target specific classes.

## Writing

- README, picker text, and installer output stay short and plain. No "then reload" filler and no help boxes nobody asked for.
- Commit subjects are one sentence naming the visible effect, like "Lighten T3 warning ink so status icons stay visible on the dark canvas." Use the owner's wording when they give one.

## Shell profile

The fetch banner shows once per Windows Terminal tab. It never shows in agent shells or in `-File` or `-Command` launches.
