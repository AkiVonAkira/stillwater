import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { darkRoles, lightRoles } from "./t3/roles.ts";

const ROOT = dirname(fileURLToPath(import.meta.url));
const SKIP_KEYS = new Set(["id", "label", "publisher"]);

type Json = string | number | boolean | null | Json[] | { [key: string]: Json };

type Spec = {
  version?: string;
  palette: { [key: string]: Json };
  hexMap: { [key: string]: string };
};

function remapHex(text: string, hexMap: { [key: string]: string }): string {
  return text.replace(/#([0-9A-Fa-f]{6,8})/g, (match, body: string) => {
    const key = body.slice(0, 6).toLowerCase();
    const rest = body.slice(6);
    if (key in hexMap) {
      return `#${hexMap[key]}${rest}`;
    }
    return match;
  });
}

function cssName(key: string): string {
  return key.replace(/_/g, "-").replace(/(?<!^)(?=[A-Z])/g, "-").toLowerCase();
}

function writeCss(palette: { [key: string]: Json }): string {
  const lines = [":root {"];

  function walk(obj: Json, prefix: string): void {
    if (obj && typeof obj === "object" && !Array.isArray(obj)) {
      for (const [key, value] of Object.entries(obj)) {
        if (SKIP_KEYS.has(key)) {
          continue;
        }
        const name = cssName(key);
        const nextPrefix = prefix ? `${prefix}-${name}` : name;
        walk(value, nextPrefix);
      }
      return;
    }
    if (typeof obj === "string" && obj.startsWith("#")) {
      lines.push(`  --stillwater-${prefix}: ${obj};`);
    }
  }

  walk(palette, "");
  lines.push("}");
  lines.push("");
  return lines.join("\n");
}

// T3 themes accept at most 20,000 characters of CSS and cannot load files.
const T3_CSS_LIMIT = 20_000;

function t3CssProblems(css: string): string[] {
  const problems: string[] = [];
  if (css.length > T3_CSS_LIMIT) problems.push(`css is ${css.length} characters, over ${T3_CSS_LIMIT}`);
  if (/@import/i.test(css)) problems.push("css uses @import");
  if (/image-set\(/i.test(css)) problems.push("css uses image-set()");
  for (const m of css.matchAll(/url\(\s*['"]?([^'")\s]*)/gi)) {
    if (!/^(data:|#)/i.test(m[1])) problems.push(`css loads ${m[1]}`);
  }
  return problems;
}

function writeT3(palette: { [key: string]: Json }): string {
  const source = readFileSync(join(ROOT, "t3", "observatory.css"), "utf8")
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/\n{2,}/g, "\n")
    .trim();
  const css = `${writeCss(palette).trim()}
${source}
`;
  const problems = t3CssProblems(css);
  if (problems.length > 0) {
    throw new Error(`t3/observatory.css: ${problems.join("; ")}`);
  }
  const lower = (roles: Record<string, string>) =>
    Object.fromEntries(Object.entries(roles).map(([role, hex]) => [role, hex.toLowerCase()]));
  const colors = lower(darkRoles(palette as Parameters<typeof darkRoles>[0]));
  const theme = {
    version: 1,
    id: palette.id,
    name: palette.label,
    appearance: "dark",
    canvas: colors.canvas,
    accent: colors.accent,
    colors,
    variants: { light: lower(lightRoles) },
    css,
  };
  return `${JSON.stringify(theme, null, 2)}
`;
}

// --check fails when a committed generated file differs from what the build writes.
function emit(path: string, text: string, check: boolean): boolean {
  if (check) {
    const same = existsSync(path) && readFileSync(path, "utf8") === text;
    if (!same) console.error(`${path} is stale. Run npm run build.`);
    return same;
  }
  writeFileSync(path, text, "utf8");
  console.log(`wrote ${path}`);
  return true;
}

function main(): void {
  const spec = JSON.parse(readFileSync(join(ROOT, "palette.json"), "utf8")) as Spec;
  const check = process.argv.includes("--check");
  const fresh = [
    emit(join(ROOT, "stillwater.css"), writeCss(spec.palette), check),
    emit(join(ROOT, "t3", "stillwater.json"), writeT3(spec.palette), check),
  ];
  if (check) {
    process.exit(fresh.every(Boolean) ? 0 : 1);
  }

  const feppz = process.argv[2];
  if (!feppz) {
    console.log("vscode theme left as-is (pass a feppz theme path to rebuild it)");
    return;
  }
  const src = feppz;
  if (!existsSync(src)) {
    console.error(`feppz source not found: ${src}`);
    process.exit(1);
  }
  let themed = remapHex(readFileSync(src, "utf8"), spec.hexMap);
  if (!themed.includes('"name": "Stillwater"')) {
    themed = themed.replace('"type": "dark"', '"name": "Stillwater",\n\t"type": "dark"');
  }
  const out = join(ROOT, "vscode", "themes", "stillwater-color-theme.json");
  writeFileSync(out, themed, "utf8");
  console.log(`wrote ${out}`);
}

main();
