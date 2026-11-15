// Builds t3/stillwater.json, then installs it with the real installer, which runs t3 theme set.
//   npm run t3:apply
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = dirname(dirname(fileURLToPath(import.meta.url)));
const run = (command: string, args: string[]) => {
  const result = spawnSync(command, args, { cwd: ROOT, stdio: "inherit" });
  if (result.status !== 0) process.exit(result.status ?? 1);
};

run(process.execPath, [join(ROOT, "node_modules", "tsx", "dist", "cli.mjs"), "build.ts"]);
if (process.platform === "win32") run("pwsh", ["-NoProfile", "-File", "install.ps1", "t3"]);
else run("bash", ["install.sh", "t3"]);
