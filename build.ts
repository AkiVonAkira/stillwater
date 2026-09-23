import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = dirname(fileURLToPath(import.meta.url));
const SKIP_KEYS = new Set(["id", "label", "publisher"]);

type Json = string | number | boolean | null | Json[] | { [key: string]: Json };

type Spec = {
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

function main(): void {
  const spec = JSON.parse(readFileSync(join(ROOT, "palette.json"), "utf8")) as Spec;
  const cssPath = join(ROOT, "stillwater.css");
  writeFileSync(cssPath, writeCss(spec.palette), "utf8");
  console.log(`wrote ${cssPath}`);

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
