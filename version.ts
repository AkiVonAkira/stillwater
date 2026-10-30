// Sets the theme version in palette.json and every adapter file that stamps it,
// or checks that they all match.
//   npm run bump -- minor        patch, minor, major, or an exact x.y.z
//   npm run version:check
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = dirname(fileURLToPath(import.meta.url));
const SEMVER = String.raw`\d+\.\d+\.\d+`;

const JSON_VERSION = new RegExp(String.raw`^(\s*"version"\s*:\s*")(${SEMVER})(")`, "m");
const AT_VERSION = new RegExp(String.raw`(@version\s+)(${SEMVER})()`);
const HASH_VERSION = new RegExp(String.raw`^(#\s*version\s+)(${SEMVER})()`, "m");

const STAMPS: [string, RegExp][] = [
  ["palette.json", JSON_VERSION],
  ["vscode/package.json", JSON_VERSION],
  ["obsidian/manifest.json", JSON_VERSION],
  ["prism/theme.json", JSON_VERSION],
  ["windows-terminal/stillwater.json", JSON_VERSION],
  ["zed/extension.toml", new RegExp(String.raw`^(version\s*=\s*")(${SEMVER})(")`, "m")],
  ["vencord/base/Stillwater.theme.css", AT_VERSION],
  ["vencord/midnight/Stillwater.theme.css", AT_VERSION],
  ["vencord/system24/Stillwater.theme.css", AT_VERSION],
  ["vencord/oldcord/Stillwater.theme.css", AT_VERSION],
  ["vencord/surcord/Stillwater.theme.css", AT_VERSION],
  ["obsidian/theme.css", AT_VERSION],
  ["yasb/root.css", AT_VERSION],
  ["fastfetch/config.jsonc", AT_VERSION],
  ["ryoku/stillwater.fish", AT_VERSION],
  ["prism/themeStyle.css", new RegExp(String.raw`^(\s*\*\s*version\s+)(${SEMVER})()`, "m")],
  ["spicetify/color.ini", new RegExp(String.raw`^(;\s*version\s+)(${SEMVER})()`, "m")],
  ["btop/stillwater.theme", HASH_VERSION],
  ["ghostty/Stillwater", HASH_VERSION],
  ["harbor/Stillwater.harborstyle", HASH_VERSION],
  ["kitty/Stillwater.conf", HASH_VERSION],
  ["starship/starship.toml", HASH_VERSION],
];

function read(file: string): string {
  return readFileSync(join(ROOT, file), "utf8");
}

function stamp(file: string, re: RegExp): string {
  const m = read(file).match(re);
  if (!m) throw new Error(`${file}: no version stamp`);
  return m[2];
}

function next(current: string, arg: string): string {
  if (new RegExp(`^${SEMVER}$`).test(arg)) return arg;
  const [major, minor, patch] = current.split(".").map(Number);
  if (arg === "major") return `${major + 1}.0.0`;
  if (arg === "minor") return `${major}.${minor + 1}.0`;
  if (arg === "patch") return `${major}.${minor}.${patch + 1}`;
  throw new Error(`Use patch, minor, major, or x.y.z, not "${arg}".`);
}

const arg = process.argv[2] ?? "--check";
const current = stamp("palette.json", JSON_VERSION);

if (arg === "--check") {
  const wrong = STAMPS.filter(([file, re]) => stamp(file, re) !== current).map(([file, re]) => `${file} has ${stamp(file, re)}`);
  if (wrong.length) {
    console.error(`palette.json is ${current}, but:\n  ${wrong.join("\n  ")}\nRun npm run bump -- ${current}`);
    process.exit(1);
  }
  console.log(`${STAMPS.length} files at ${current}`);
} else {
  const version = next(current, arg);
  for (const [file, re] of STAMPS) {
    writeFileSync(join(ROOT, file), read(file).replace(re, (_m, pre: string, _v: string, post: string) => pre + version + post));
  }
  console.log(`${current} to ${version} in ${STAMPS.length} files`);
}
