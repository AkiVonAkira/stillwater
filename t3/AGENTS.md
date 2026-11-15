# T3 Code adapter

`t3/stillwater.json` is generated. Do not edit it by hand.

## Sources

- `palette.json` owns the colors. `npm run build` writes them into the theme as `--stillwater-*` CSS variables and as the dark color roles.
- `t3/roles.ts` maps each T3 color role to a palette key. Tints that are not in the palette and the light variant stay explicit there.
- `t3/observatory.css` is the Observatory glass: header gradient, glass cards, radii, and the selected sidebar row shadow. Its tokens follow `P:/Projects/observatory/packages/ui/src/tokens.css`.
- Fonts, font sizes, chat width, and sidebar layout are T3 client settings, not theme. The theme never sets them.

## Edit, build, apply

1. Call the `t3_theme_read` MCP tool for the current color roles, CSS limits, and stable selectors. Use only those selectors, or a `data-*` attribute you confirmed with `npm run t3:capture -- --probe <file.js>`.
2. Edit `t3/observatory.css` or `t3/roles.ts`.
3. `npm run build` writes the theme and fails when the CSS breaks a T3 rule: more than 20,000 characters, `@import`, `image-set()`, or a `url()` that is not `data:` or `#id`. `npm run build:check` fails when a committed generated file is stale.
4. `npm run t3:capture` screenshots the installed T3 client, before and after. See below.
5. `npm run t3:apply` builds and runs the real installer (`install.ps1 t3` or `install.sh t3`), which publishes and selects the `stillwater` theme. The plain installer needs no Node. It copies the committed JSON.

Rollback: the earlier hand-made theme is still published as `stillwater-observatory`. Select it in T3's appearance settings, or run `t3 theme set --id stillwater-observatory ~/.t3/userdata/themes/stillwater-observatory.json`.

## Capture

`npm run t3:capture` loads the frontend assets from the local T3 server at `http://127.0.0.1:3773` into a headless Chromium. Every API call and the RPC WebSocket are answered from `t3/capture-fixture.ts`, so the real app renders synthetic projects, threads, and messages with the owner's client settings. The browser never opens a socket to the server, sends no credentials, and reads no T3 data. The only server request is the public `/.well-known/t3/environment`, for the protocol version and capabilities.

- `--before <theme.json>` defaults to the published `stillwater-observatory`. `--after` defaults to `t3/stillwater.json`.
- Output goes to `<tmp>/stillwater-t3-capture/`, one timestamp per run: desktop thread, gutter, selected row, drag-over, composer focus, model menu, phone thread and sidebar, and a desktop recording. The JSON report on stdout has the measured shadows and every RPC and blocked request.
- A new T3 nightly can change the protocol. When the thread does not render, the tool saves the page and names the file. Check the RPC list in the report against `packages/contracts` in the T3 source.
