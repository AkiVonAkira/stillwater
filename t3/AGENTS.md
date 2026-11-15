# T3 Code adapter

`t3/stillwater.json` is generated. Do not edit it by hand.

## Sources

- `palette.json` owns the colors. `npm run build` writes them into the theme as `--stillwater-*` CSS variables and as the dark color roles.
- `t3/roles.ts` maps each T3 color role to a palette key. Tints that are not in the palette and the light variant stay explicit there.
- `t3/observatory.css` owns the header and scrollbar gradient, glass cards, nested composer radii, question-card framing, and selected sidebar row shadow. Its tokens follow `packages/ui/src/tokens.css` in the Observatory checkout.
- Fonts, font sizes, chat width, and sidebar layout are T3 client settings, not theme. The theme never sets them.

## Edit, build, apply

1. Call the `t3_theme_read` MCP tool for the current color roles, CSS limits, and stable selectors. Use only those selectors, or a `data-*` attribute you confirmed with `npm run t3:capture -- --probe <file.js>`.
2. Edit `t3/observatory.css` or `t3/roles.ts`.
3. `npm run build` writes the theme and fails when the CSS breaks a T3 rule: more than 20,000 characters, `@import`, `image-set()`, or a `url()` that is not `data:` or `#id`. `npm run build:check` fails when a committed generated file is stale.
4. `npm run t3:capture` screenshots the installed T3 client, before and after. See below.
5. `npm run t3:apply` builds and runs the real installer (`install.ps1 t3` or `install.sh t3`), which publishes and selects the `stillwater` theme. The plain installer needs no Node. It copies the committed JSON.

Rollback: select a built-in theme in T3's appearance settings, or check out an earlier commit and run `npm run t3:apply`.

## Capture

`npm run t3:capture` loads the frontend assets from the local T3 server at `http://127.0.0.1:3773` into headless Chromium. Every API call and the RPC WebSocket are answered from `t3/capture-fixture.ts`, so the real app renders synthetic projects, threads, and messages with explicit fixture preferences. The browser never opens a WebSocket to the server, sends no credentials, and reads no private T3 data. The only non-asset server request is the public `/.well-known/t3/environment`, for the protocol version and capabilities.

- `--before <theme.json>` defaults to the published `stillwater` theme, the one live now. `--after` defaults to `t3/stillwater.json`.
- Output goes to `<tmp>/stillwater-t3-capture/`, one timestamp per run. It captures the thread, scrollbar gutter at middle and end, selected row, drag-over, thread-mention tooltip, composer focus, question card, model menu, and Settings dialog at 2000 by 1258 and 1440 by 900. It also captures the thread and sidebar at 390 by 844 and records the wide desktop. The JSON report file has the measured shadows, gutter pixels, RPCs, and blocked requests. Missing required controls or mismatched shadows, active fill, focus feedback, question framing, or gutter continuity fail the command.
- In PowerShell, use `npm.cmd run t3:capture -- --out <dir>` when passing flags. The npm PowerShell shim drops the named flags in this environment.
- A new T3 nightly can change the protocol. When the thread does not render, the tool saves the page and names the file. Check the RPC list in the report against `packages/contracts` in the T3 source.
