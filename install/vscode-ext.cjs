const fs = require("node:fs");
const path = require("node:path");

const [cmd, dest, id, version] = process.argv.slice(2);
if (cmd !== "register" || !dest || !id || !version) {
  process.stderr.write("usage: vscode-ext.cjs register DEST ID VERSION\n");
  process.exit(2);
}

const folder = path.basename(dest);
const root = path.dirname(dest);
const jsonPath = path.join(root, "extensions.json");
const obsoletePath = path.join(root, ".obsolete");

function vscodePath(p) {
  const norm = path.resolve(p).replace(/\\/g, "/");
  const drive = /^([A-Za-z]):\/(.*)$/.exec(norm);
  if (drive) {
    return `/${drive[1].toLowerCase()}:/${drive[2]}`;
  }
  return norm;
}

if (fs.existsSync(obsoletePath)) {
  const obsolete = JSON.parse(fs.readFileSync(obsoletePath, "utf8"));
  let changed = false;
  for (const key of Object.keys(obsolete)) {
    if (key.startsWith("kayzel.stillwater-theme")) {
      delete obsolete[key];
      changed = true;
    }
  }
  if (changed) {
    fs.writeFileSync(obsoletePath, `${JSON.stringify(obsolete)}\n`);
  }
}

const entry = {
  identifier: { id },
  version,
  location: {
    $mid: 1,
    path: vscodePath(dest),
    scheme: "file",
  },
  relativeLocation: folder,
  metadata: {
    installedTimestamp: Date.now(),
    pinned: true,
    source: "vsix",
    isPreReleaseVersion: false,
    hasPreReleaseVersion: false,
  },
};

let list = [];
if (fs.existsSync(jsonPath)) {
  const raw = fs.readFileSync(jsonPath, "utf8").trim() || "[]";
  const parsed = JSON.parse(raw);
  if (Array.isArray(parsed)) {
    list = parsed;
  }
}
list = list.filter((item) => item?.identifier?.id !== id);
list.push(entry);
fs.writeFileSync(jsonPath, `${JSON.stringify(list)}\n`);
