// Renders showcase/showcase.png from palette.json: `npm run showcase`.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import { CSS, discord, ghostty, spotify, t3code, vscode, type Palette } from "./apps.ts";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "showcase.png");
const W = 1600;
const H = 1000;

const P = (JSON.parse(readFileSync(join(HERE, "..", "palette.json"), "utf8")) as { palette: Palette }).palette;

function place(html: string, x: number, y: number, w: number, h: number, z: number): string {
  return html.replace('class="win" style="', `class="win" style="left:${x}px;top:${y}px;width:${w}px;height:${h}px;z-index:${z};`);
}

function swatches(): string {
  const seen = new Set<string>();
  const colors: string[] = [];
  const walk = (obj: unknown): void => {
    for (const value of Object.values(obj as object)) {
      if (typeof value === "string" && /^#[0-9a-f]{6}$/i.test(value)) {
        const key = value.toLowerCase();
        if (!seen.has(key)) {
          seen.add(key);
          colors.push(value);
        }
      } else if (value && typeof value === "object") {
        walk(value);
      }
    }
  };
  walk(P);
  return colors
    .map((c) => `<span style="flex:1;height:22px;background:${c};box-shadow:inset 0 0 0 1px ${P.border}"></span>`)
    .join("");
}

const backdrop = [
  `radial-gradient(circle at 18% 12%, ${P.accentDeep}66, transparent 55%)`,
  `radial-gradient(circle at 88% 92%, ${P.warm}33, transparent 50%)`,
  P.canvasOverlay,
].join(", ");

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;background:transparent}
${CSS}
.mark{position:absolute;left:64px;top:44px;display:flex;align-items:center;gap:14px;font-weight:600;font-size:34px;letter-spacing:.01em}
.mark i{width:16px;height:16px;border-radius:50%}
.strip{position:absolute;left:64px;right:64px;bottom:36px;display:flex;gap:4px;padding:5px;border-radius:10px;background:${P.canvas};border:1px solid ${P.textFaint};box-shadow:0 12px 30px -8px rgba(0,0,0,.5)}
.strip span:first-child{border-radius:5px 0 0 5px}.strip span:last-child{border-radius:0 5px 5px 0}
</style></head><body>
<div class="stage" style="width:${W}px;height:${H}px;background:${backdrop};border-radius:24px">
  <div class="mark" style="color:${P.text}"><i style="background:${P.accent}"></i>Stillwater</div>
  ${place(vscode(P), 48, 112, 800, 480, 1)}
  ${place(t3code(P), 880, 96, 672, 430, 2)}
  ${place(discord(P), 84, 470, 620, 400, 3)}
  ${place(spotify(P), 560, 420, 640, 450, 4)}
  ${place(ghostty(P), 1060, 520, 500, 350, 5)}
  <div class="strip">${swatches()}</div>
</div></body></html>`;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
await page.setContent(html);
await page.locator(".stage").screenshot({ path: OUT, omitBackground: true });
await browser.close();
console.log(`wrote ${OUT}`);
