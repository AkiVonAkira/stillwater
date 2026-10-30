# Stillwater

A personal color theme. `palette.json` holds the colors, each app folder is an adapter, and `install.sh` / `install.ps1` install them by OS and app. [CONTRIBUTING.md](CONTRIBUTING.md) has the rules and checks. This file covers how the owner asks for work and what has gone wrong before.

## How work is asked for

- Requests are short: an app, a symptom, sometimes a guess ("discord is so slow, update the theme classes maybe?"). Treat the guess as a lead. Find the cause before you change anything. Toggling animations did not fix that lag.
- Small fixes, such as a color, a font, a selector, or a doc line, commit and push straight to `main`. A new adapter, a new feature, or a large change goes through a PR: branch, push, open the PR, wait for CI, then merge. `main` has no ruleset.
- Two adapters means two PRs.
- In a stack, retarget the next PR to `main` before you merge the bottom one with `--delete-branch`. Deleting its base branch closes the next PR instead of retargeting it.
- "Install it" means run the real installer on this machine, such as `pwsh ./install.ps1 t3` or `bash install.sh t3`. Do not hand-edit the app's live config in place of the adapter.
- When the owner gives a value ("it should be 8px"), use that value, not the nearest one you found elsewhere.

## Done means

1. `npm run build`, `npm run version:check`, `bash tests/test_install.sh`, and `pwsh tests/test_install.ps1` pass, and the PR's CI is green. CI runs the bash tests on Ubuntu with `LANG=C.UTF-8`. Git Bash on Windows differs (fork limits, path assertions, no `python3`, byte-counted keymap widths), so a Git Bash pass is not done. Docker `node:22` with `-e LANG=C.UTF-8` matches CI.
2. You looked at the themed app yourself. Take the screenshot and check the change and the elements around it. A fix that breaks its neighbor is the common failure: re-adding a Spotify panel broke the full-height album art. The owner should not be the one sending the screenshot.
3. No text is clipped.
4. An adapter that can carry a version takes it from `palette.json`, shows it in `--list`, and has a line in `STAMPS` in `version.ts`.

## Tests

- The installer tests run the real `install.sh` and `install.ps1` against an empty home. Add a case there for a new adapter or an installer bug, written to fail on `main` first.
- Do not add tests that restate picker labels, next-step text, or a hard-coded version. Read the version from `palette.json`.
- Run an install that is not `--dry-run` only with `STILLWATER_HOME` set to a temp folder. Adapters such as Spicetify call the app's own CLI.

## Installer speed

Adapter `status` runs every time the picker opens. Keep it to file checks: no fork per line in bash and no `Get-Command` in a loop in pwsh. YASB status once took 14 s on Git Bash from a `sed` per CSS line; it is one `awk` pass now.

## Contrast

When one token reads badly, check every ink and surface pair in that adapter, not only the one reported. Dark ink on the dark canvas came back twice in the T3 adapter: first the warning pencil, then the NEW badge and muted labels.

## Speed

Theme CSS for Electron apps (Vencord, Equicord, Spicetify) has to stay cheap. Broad selectors like `[class*=...]` combined with `:has()` made Discord lag. Target specific classes.

## Writing

- README, picker text, and installer output stay short and plain. No "then reload" filler and no help boxes nobody asked for.
- Commit subjects are one sentence naming the visible effect, like "Lighten T3 warning ink so status icons stay visible on the dark canvas." Use the owner's wording when they give one.

## Shell profile

The fetch banner shows once per interactive terminal tab, Windows Terminal or Voltius alike. It never shows in agent shells or in `-File` or `-Command` launches. Starship icons stay in the BMP, because ConPTY counts supplementary-plane icons as two cells and shifts the pill's right cap.
