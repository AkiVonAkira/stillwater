// Renames stale Discord class names in the Vencord themes to the current ones.
// Same data as https://syndishanx.github.io/Website/Update_Classes.html, applied
// per whole class token so one name never rewrites part of a longer one.
//
//   npm run update-classes            rewrite vencord/*/Stillwater.theme.css
//   npm run update-classes -- --check exit 1 if any class is stale
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const CHANGES = "https://syndishanx.github.io/Update-Classes/Changes.txt";
const REGEX_CHANGES = "https://syndishanx.github.io/Update-Classes/Regex_Changes.txt";
const check = process.argv.includes("--check");

async function lines(url: string): Promise<string[]> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  return (await res.text()).split("\n").map((l) => l.replace(/\r$/, ""));
}

const changes = await lines(CHANGES);
const regexMarkers = (await lines(REGEX_CHANGES)).filter(Boolean);

// Changes.txt is old/new line pairs in date order. The web tool applies every
// pair in sequence, so a name renamed twice ends at its latest name.
const steps = new Map<string, [number, string][]>();
for (let i = 0; i + 1 < changes.length; i += 2) {
  const [from, to] = [changes[i], changes[i + 1]];
  if (!from || from === to) continue;
  const list = steps.get(from) ?? [];
  list.push([i, to]);
  steps.set(from, list);
}

function pass(name: string): string {
  let at = -1;
  for (;;) {
    const next = steps.get(name)?.find(([i]) => i > at);
    if (!next) return name;
    [at, name] = next;
  }
}

// Some renames are listed before the rename that produces their old name, so
// repeat the pass until the name stops changing. The seen set stops on a cycle.
function latest(name: string): string {
  const seen = new Set<string>();
  while (!seen.has(name)) {
    seen.add(name);
    const next = pass(name);
    if (next === name) return name;
    name = next;
  }
  return name;
}

const root = "vencord";
let stale = 0;
for (const flavor of readdirSync(root, { withFileTypes: true })) {
  if (!flavor.isDirectory()) continue;
  const file = join(root, flavor.name, "Stillwater.theme.css");
  let css: string;
  try {
    css = readFileSync(file, "utf8");
  } catch {
    continue;
  }
  let out = css;
  // Discord's older hash-first form (.abc123def4567890-name), as the web tool does.
  if (regexMarkers.some((m) => out.includes(m))) {
    out = out.replace(/\.([_0-9a-f]{6})[0-9a-f]{10,11}-([A-Za-z0-9_\-]+)/g, ".$2_$1");
  }
  const renamed = new Map<string, string>();
  out = out.replace(/[A-Za-z0-9_-]+/g, (token) => {
    const to = latest(token);
    if (to !== token) renamed.set(token, to);
    return to;
  });
  if (out === css) continue;
  stale += renamed.size || 1;
  for (const [from, to] of renamed) console.log(`${file}: ${from} -> ${to}`);
  if (!check) writeFileSync(file, out);
}

console.log(stale ? `${stale} stale class name(s)${check ? "" : " updated"}.` : "All class names current.");
if (check && stale) process.exit(1);
